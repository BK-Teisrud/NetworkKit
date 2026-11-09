#if !os(watchOS)
import Foundation
import Synchronization

/// One owned session/task. Native callbacks never directly mutate connection actor state.
internal final class WebSocketSessionTransport: NSObject, URLSessionWebSocketDelegate, WebSocketTransport {
    private struct State: Sendable {
        var started = false
        var cancelled = false
        var localClose = false
        var opened = false
        var terminalPublished = false
        var session: URLSession?
        var task: URLSessionWebSocketTask?
        var peer: WebSocketCloseInfo?
        var peerFailure: WebSocketError?
    }
    private let state = Mutex(State())
    private let request: WebSocketOpenRequest
    private let events: @Sendable (WebSocketTransportEvent) async -> Void

    init(request: WebSocketOpenRequest, events: @escaping @Sendable (WebSocketTransportEvent) async -> Void) {
        self.request = request; self.events = events
    }
    var peerCloseInfo: WebSocketCloseInfo? { state.withLock { $0.peer } }

    func start() {
        let start = state.withLock { s in
            guard !s.started, !s.cancelled else { return false }
            s.started = true; return true
        }
        guard start else { return }
        let config = Self.sessionConfiguration()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        let task = session.webSocketTask(with: Self.urlRequest(request))
        task.maximumMessageSize = request.maximumMessageBytes
        let cancelled = state.withLock { s in
            s.session = session; s.task = task; return s.cancelled
        }
        if cancelled { task.cancel(); session.invalidateAndCancel() }
        else { task.resume() }
    }
    /// These constructors are inspected by deterministic tests without resuming a task.
    static func sessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return config
    }
    static func urlRequest(_ prepared: WebSocketOpenRequest) -> URLRequest {
        var request = URLRequest(url: prepared.endpoint)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.allHTTPHeaderFields = prepared.headers.fields
        if !prepared.subprotocols.isEmpty {
            request.setValue(prepared.subprotocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }
        return request
    }

    private func complete<Value: Sendable>(_ result: Result<Value, WebSocketError>,
            to callback: @escaping @Sendable (Result<Value, WebSocketError>) async -> Void) {
        Task { await callback(result) }
    }
    private func emit(_ event: WebSocketTransportEvent) {
        Task { [events] in await events(event) }
    }
    func send(_ message: WebSocketMessage, completion: @escaping @Sendable (Result<Void, WebSocketError>) async -> Void) {
        guard let task = state.withLock({ $0.task }) else { complete(.failure(.closed), to: completion); return }
        let native: URLSessionWebSocketTask.Message
        switch message { case .text(let value): native = .string(value); case .binary(let value): native = .data(value) }
        task.send(native) { [weak self] error in
            guard let self else { return }
            guard let error else { self.complete(.success(()), to: completion); return }
            if let failure = self.state.withLock({ $0.peerFailure }) { self.complete(.failure(failure), to: completion); return }
            if let end = self.knownEnd(task) {
                switch end {
                case .peerClose(let info): self.publish(.peerClose(info))
                default: self.publish(.orderlyEnd)
                }
            } else { self.complete(.failure(Self.failure(error, opened: true)), to: completion) }
        }
    }
    func receive(completion: @escaping @Sendable (Result<WebSocketIncoming, WebSocketError>) async -> Void) {
        guard let task = state.withLock({ $0.task }) else { complete(.failure(.closed), to: completion); return }
        task.receive { [weak self] result in
            guard let self else { return }
            let mapped: Result<WebSocketIncoming, WebSocketError>
            switch result {
            case .success(.string(let text)): mapped = .success(.message(.text(text)))
            case .success(.data(let data)): mapped = .success(.message(.binary(data)))
            case .failure(let error):
                if Self.failure(error, opened: true) == .messageTooLarge { mapped = .failure(.messageTooLarge) }
                else if let failure = self.state.withLock({ $0.peerFailure }) { mapped = .failure(failure) }
                else if let end = self.knownEnd(task) { mapped = .success(end) }
                else { mapped = .failure(Self.failure(error, opened: true)) }
            @unknown default: mapped = .failure(.protocolViolation)
            }
            self.complete(mapped, to: completion)
        }
    }
    func close(code: WebSocketCloseCode, reason: String?) {
        let snapshot = state.withLock { s in s.localClose = true; return (s.task, s.session) }
        guard let nativeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(code.rawValue)) else {
            publish(.failed(.protocolViolation)); cancel(); return
        }
        snapshot.0?.cancel(with: nativeCode, reason: reason.map { Data($0.utf8) })
        snapshot.1?.finishTasksAndInvalidate()
    }
    func cancel() {
        let snapshot = state.withLock { s in s.cancelled = true; return (s.task, s.session) }
        snapshot.0?.cancel(); snapshot.1?.invalidateAndCancel()
    }

    private func publish(_ event: WebSocketTransportEvent) {
        let first = state.withLock { s in
            guard !s.terminalPublished else { return false }
            s.terminalPublished = true; return true
        }
        if first { emit(event) }
    }
    private func knownEnd(_ task: URLSessionWebSocketTask) -> WebSocketIncoming? {
        if let peer = state.withLock({ $0.peer }) { return .peerClose(peer) }
        // Do not turn this adapter's own cancel/close into an observed peer frame.
        guard !state.withLock({ $0.localClose || $0.cancelled }) else { return nil }
        guard let peer = Self.taskCloseSnapshot(code: task.closeCode.rawValue, reason: task.closeReason) else {
            return task.closeCode == .noStatusReceived ? .orderlyEnd : nil
        }
        let first = state.withLock { s -> WebSocketCloseInfo in
            if let retained = s.peer { return retained }
            s.peer = peer; return peer
        }
        return .peerClose(first)
    }
    /// Native task metadata may precede the delegate callback. Synthetic absent-status
    /// sentinels are deliberately excluded from the snapshot fallback.
    static func taskCloseSnapshot(code: Int, reason: Data?) -> WebSocketCloseInfo? {
        guard code != URLSessionWebSocketTask.CloseCode.invalid.rawValue, code != 1005,
              let peer = try? WebSocketValidation.peerClose(code: code, reason: reason) else { return nil }
        return peer
    }
    static func failure(_ error: any Error, opened: Bool) -> WebSocketError {
        let native = error as NSError
        if native.domain == NSPOSIXErrorDomain, native.code == Int(POSIXErrorCode.EMSGSIZE.rawValue) {
            return .messageTooLarge
        }
        if native.domain == NSURLErrorDomain {
            if native.code == URLError.dataLengthExceedsMaximum.rawValue { return .messageTooLarge }
            if !opened && native.code == URLError.badServerResponse.rawValue { return .handshakeRejected }
        }
        return .transport(.init(domain: native.domain, code: native.code))
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let allowed = state.withLock { s in
            guard !s.cancelled, !s.terminalPublished else { return false }
            s.opened = true; return true
        }
        if allowed { emit(.opened(selectedProtocol: `protocol`)) }
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        do {
            let peer = try WebSocketValidation.peerClose(code: closeCode.rawValue, reason: reason)
            let first = state.withLock { s in
                guard s.peer == nil, s.peerFailure == nil else { return false }
                s.peer = peer; return true
            }
            if first { publish(.peerClose(peer)) }
        } catch {
            let first = state.withLock { s in
                guard s.peer == nil, s.peerFailure == nil else { return false }
                s.peerFailure = .protocolViolation; return true
            }
            if first { publish(.failed(.protocolViolation)) }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let opened = state.withLock { $0.opened }
        if let error, Self.failure(error, opened: opened) == .messageTooLarge {
            publish(.failed(.messageTooLarge))
        } else if let task = task as? URLSessionWebSocketTask, let end = knownEnd(task) {
            switch end { case .peerClose(let info): publish(.peerClose(info)); default: publish(.orderlyEnd) }
        } else if let error { publish(.failed(Self.failure(error, opened: opened))) }
        else { publish(.failed(.transport(.init(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue)))) }
        session.finishTasksAndInvalidate()
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        let snapshot = state.withLock { s in
            s.session = nil; s.task = nil
            return (s.localClose, s.terminalPublished)
        }
        // A local close already committed its cause. Do not race remote close/error with a generic stopped event.
        if snapshot.0 { emit(.stopped) }
        else if !snapshot.1 {
            publish(.failed(.transport(.init(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue))))
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
        publish(.failed(.handshakeRejected))
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        challengeDisposition(challenge, completionHandler: completionHandler)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        challengeDisposition(challenge, completionHandler: completionHandler)
    }
    private func challengeDisposition(_ challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            publish(.failed(.handshakeRejected))
        }
    }
}
#endif
