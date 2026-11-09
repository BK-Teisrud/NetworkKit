import Foundation
import Network
import CryptoKit
import Security
import os

struct HTTPObservation: Sendable {
    let status: Int
    let bytes: Data
    let leaf: Data?
    let trustAccepted: Bool
    let challenges: Int
    let taskStarts: Int
    let tlsVersion: String
}
// URLSession protocols inherit NSObject mutability. All mutable observation state is locked;
// immutable URLCredential is Foundation Sendable, not a raw-identity unchecked wrapper.
final class HTTPProbe: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, Sendable {
    struct State: Sendable {
        var status = 0; var body = Data(); var leaf: Data?; var trusted = false
        var challenges = 0; var starts = 0; var protocolName = "unknown"; var policyOutcome = "none"; var completedTrustCallbacks = 0
    }
    let state = OSAllocatedUnfairLock(initialState: State())
    let result = Once<HTTPObservation>()
    let anchor: Data?
    let requiredPins: Set<Data>?
    let credential: URLCredential?
    let delayTrust: Bool
    let bodyLimit: Int
    init(anchor: Data? = nil, pins: Set<Data>? = nil, credential: URLCredential? = nil,
         delayTrust: Bool = false, bodyLimit: Int = 65536) {
        self.anchor = anchor; self.requiredPins = pins; self.credential = credential
        self.delayTrust = delayTrust; self.bodyLimit = bodyLimit
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        state.withLock { $0.challenges += 1 }
        if space.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            guard challenge.previousFailureCount == 0, let credential else {
                state.withLock { $0.policyOutcome = self.credential == nil ? "identity-absent" : "identity-repeat" }
                completionHandler(.cancelAuthenticationChallenge, nil); return
            }
            completionHandler(.useCredential, credential); return
        }
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = space.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        if delayTrust { Thread.sleep(forTimeInterval: 0.25) }
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first {
            state.withLock { $0.leaf = SecCertificateCopyData(leaf) as Data }
        }
        if let anchor, let cert = SecCertificateCreateWithData(nil, anchor as CFData) {
            SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, true)
            SecTrustSetNetworkFetchAllowed(trust, false)
        }
        let valid = SecTrustEvaluateWithError(trust, nil)
        let leaf = state.withLock { $0.leaf }
        let matches = requiredPins.map { pins in leaf.map { pins.contains(Data(SHA256.hash(data: $0))) } ?? false } ?? true
        state.withLock { $0.trusted = valid; $0.policyOutcome = !valid ? "trust-rejected" : !matches ? "pin-rejected" : "accepted"; $0.completedTrustCallbacks += 1 }
        completionHandler(valid && matches ? .useCredential : .cancelAuthenticationChallenge,
                          valid && matches ? URLCredential(trust: trust) : nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        state.withLock { $0.status = (response as? HTTPURLResponse)?.statusCode ?? 0 }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let exceeded = state.withLock { s in
            guard s.body.count + data.count <= bodyLimit else { return true }
            s.body.append(data); return false
        }
        if exceeded { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        state.withLock { $0.protocolName = metrics.transactionMetrics.last?.negotiatedTLSProtocolVersion.map { String(describing: $0) } ?? "none" }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error { result.resolve(.failure(error)); return }
        let value = state.withLock { HTTPObservation(status: $0.status, bytes: $0.body, leaf: $0.leaf,
            trustAccepted: $0.trusted, challenges: $0.challenges, taskStarts: $0.starts, tlsVersion: $0.protocolName) }
        result.resolve(.success(value))
    }
    func request(_ request: URLRequest, minimumTLS: tls_protocol_version_t? = nil, cancelAfter: Double? = nil) async throws -> HTTPObservation {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        config.httpShouldSetCookies = false; config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        if let minimumTLS { config.tlsMinimumSupportedProtocolVersion = minimumTLS }
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: request)
        state.withLock { $0.starts += 1 }; task.resume()
        let cancellation = cancelAfter.map { seconds in Task { try await Task.sleep(for: .seconds(seconds)); task.cancel() } }
        defer { cancellation?.cancel() }
        return try await withTaskCancellationHandler { try await result.value() } onCancel: { task.cancel() }
    }
}

final class StreamProbe: Sendable {
    let connection: NWConnection
    let ready = Once<Bool>()
    let receives = OSAllocatedUnfairLock(initialState: false)
    let receiveAdmission = Once<Bool>()
    let pending = OSAllocatedUnfairLock(initialState: [Once<Data>]())
    init(port: UInt16, udp: Bool = false) {
        connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: udp ? .udp : .tcp)
    }
    func start() async throws {
        connection.stateUpdateHandler = { [ready] state in
            if case .ready = state { ready.resolve(.success(true)) }
            if case .failed(let error) = state { ready.resolve(.failure(error)) }
            if case .cancelled = state { ready.resolve(.failure(ProbeFailure.cancelled)) }
        }
        connection.start(queue: DispatchQueue(label: "f6.offline.native"))
        _ = try await bounded(3, cancel: { [connection, ready] in connection.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() }
    }
    func send(_ bytes: Data, maximum: Int = 65536) async throws {
        try require(bytes.count <= maximum, "send-limit")
        let done = Once<Bool>()
        connection.send(content: bytes, completion: .contentProcessed { error in
            if let error { done.resolve(.failure(error)) } else { done.resolve(.success(true)) }
        })
        _ = try await bounded(3, cancel: { [connection] in connection.cancel(); done.resolve(.failure(ProbeFailure.timeout)) }) { try await done.value() }
    }
    func receive(udp: Bool = false, seconds: Double = 3, maximum: Int = 65536) async throws -> Data {
        let admitted = receives.withLock { busy in if busy { return false }; busy = true; return true }
        guard admitted else { throw ProbeFailure.duplicate }
        defer { receives.withLock { $0 = false } }
        let done = Once<Data>(); pending.withLock { $0.append(done) }
        defer { pending.withLock { $0.removeAll { $0 === done } } }
        let callback: @Sendable (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void = { bytes, _, _, error in
            if let error { done.resolve(.failure(error)) } else if (bytes?.count ?? 0) > maximum { done.resolve(.failure(ProbeFailure.failed("receive-limit"))) } else { done.resolve(.success(bytes ?? Data())) }
        }
        if udp { connection.receiveMessage(completion: callback) }
        else { connection.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: callback) }
        receiveAdmission.resolve(.success(true))
        return try await withTaskCancellationHandler {
            try await bounded(seconds, cancel: { [connection] in connection.cancel(); done.resolve(.failure(ProbeFailure.timeout)) }) { try await done.value() }
        } onCancel: { [connection] in connection.cancel(); done.resolve(.failure(CancellationError())) }
    }
    func close() {
        connection.cancel()
        pending.withLock { $0 }.forEach { $0.resolve(.failure(ProbeFailure.cancelled)) }
    }
}
