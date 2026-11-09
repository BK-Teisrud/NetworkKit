#if !os(watchOS)
import Foundation

/// One foreground connection. The app closes it explicitly and owns any replacement connection.
public actor WebSocketConnection: CustomStringConvertible, CustomDebugStringConvertible {
    public nonisolated var description: String { "WebSocketConnection" }
    public nonisolated var debugDescription: String { description }
    public private(set) var selectedSubprotocol: String?
    public private(set) var closeInfo: WebSocketCloseInfo?

    private struct Pending<Value: Sendable>: Sendable {
        let id = UUID()
        let promise = WebSocketPromise<Value>()
        var timer: Task<Void, Never>?
        var deadline: ContinuousClock.Instant?
    }
    private enum Terminal: Sendable {
        case end
        case cancelled
        case failed(WebSocketError)
        var error: any Error {
            switch self {
            case .end: WebSocketError.closed
            case .cancelled: CancellationError()
            case .failed(let error): error
            }
        }
    }
    private enum Deadline: Sendable { case opening(UUID), send(UUID), close(UUID) }
    private let configuration: WebSocketConfiguration
    private let clock: any NetworkClock
    private let factory: WebSocketTransportFactory
    private var opening: Pending<Void>?
    private var sending: Pending<Void>?
    private var receiving: Pending<WebSocketMessage?>?
    private var closing: Pending<Void>?
    private var providerWork: Task<Void, Never>?
    private var transport: (any WebSocketTransport)?
    private var terminal: Terminal?
    private var didOpen = false
    private var pendingCloseInfo: WebSocketCloseInfo?

    private init(configuration: WebSocketConfiguration, clock: any NetworkClock,
                 factory: @escaping WebSocketTransportFactory) {
        self.configuration = configuration; self.clock = clock; self.factory = factory
    }
    deinit {
        providerWork?.cancel()
        opening?.timer?.cancel(); sending?.timer?.cancel(); closing?.timer?.cancel()
        transport?.cancel()
    }

    public static func connect(configuration: WebSocketConfiguration) async throws -> WebSocketConnection {
        try await connect(configuration: configuration, clock: ContinuousNetworkClock()) { request, events in
            WebSocketSessionTransport(request: request, events: events)
        }
    }
    internal static func connect(configuration: WebSocketConfiguration, clock: any NetworkClock,
                                 factory: @escaping WebSocketTransportFactory) async throws -> WebSocketConnection {
        try Task.checkCancellation()
        let connection = WebSocketConnection(configuration: configuration, clock: clock, factory: factory)
        try await connection.open()
        return connection
    }

    private func open() async throws {
        try Task.checkCancellation()
        var operation = Pending<Void>()
        let deadline = clock.now().advanced(by: .seconds(configuration.timeouts.connect))
        operation.deadline = deadline
        operation.timer = timer(deadline, kind: .opening(operation.id))
        opening = operation
        let id = operation.id, configuration = configuration
        // Inherit caller task-local context, but run app work off this connection actor.
        providerWork = Task { [weak self] in
            do {
                let headers = try await Self.prepareHeaders(configuration, id: id)
                await self?.prepared(headers, id: id)
            } catch is CancellationError { await self?.openingFailed(.cancelled, id: id) }
            catch let error as WebSocketError { await self?.openingFailed(.failed(error), id: id) }
            catch { await self?.openingFailed(.failed(.authenticationFailed), id: id) }
        }
        try await withTaskCancellationHandler {
            try await operation.promise.value()
        } onCancel: { [weak self] in
            Task { await self?.cancelOpening(id) }
        }
    }

    @concurrent
    private static func prepareHeaders(_ configuration: WebSocketConfiguration, id: UUID) async throws -> HTTPHeaders {
        try Task.checkCancellation()
        let origin = try WebSocketValidation.origin(configuration.endpoint,
            allowInsecureLoopback: configuration.allowInsecureLoopback)
        guard let binding = configuration.authentication else { return configuration.headers }
        let context = AuthenticationContext(origin: origin, requestID: id, method: .get,
            account: binding.account, environment: binding.environment)
        let supplied: HTTPHeaders
        do { supplied = try await binding.provider.headers(for: context) }
        catch is CancellationError { throw CancellationError() }
        catch { throw WebSocketError.authenticationFailed }
        try Task.checkCancellation()
        return try WebSocketValidation.merged(configuration.headers, supplied, origin: origin)
    }

    private func prepared(_ headers: HTTPHeaders, id: UUID) {
        guard terminal == nil, opening?.id == id else { return }
        if let deadline = opening?.deadline, clock.now() >= deadline {
            terminate(.failed(.timeout(.connect))); return
        }
        providerWork = nil
        let request = WebSocketOpenRequest(endpoint: configuration.endpoint, headers: headers,
            subprotocols: configuration.subprotocols, maximumMessageBytes: configuration.maximumMessageBytes)
        let adapter = factory(request) { [weak self] event in
            await self?.event(event)
        }
        transport = adapter
        adapter.start()
    }

    public func send(_ message: WebSocketMessage) async throws {
        if let terminal { throw terminal.error }
        try Task.checkCancellation()
        guard message.byteCount <= configuration.maximumMessageBytes else { throw WebSocketError.messageTooLarge }
        guard sending == nil else { throw WebSocketError.operationConflict(.send) }
        guard didOpen, let transport else { throw WebSocketError.closed }
        var operation = Pending<Void>()
        let deadline = clock.now().advanced(by: .seconds(configuration.timeouts.send))
        operation.deadline = deadline
        operation.timer = timer(deadline, kind: .send(operation.id))
        sending = operation
        let id = operation.id
        transport.send(message) { [weak self] result in await self?.sent(result, id: id) }
        try await withTaskCancellationHandler {
            try await operation.promise.value()
        } onCancel: { [weak self] in Task { await self?.cancelActive(id) } }
    }

    public func receive() async throws -> WebSocketMessage? {
        if let terminal {
            if case .end = terminal { return nil }; throw terminal.error
        }
        try Task.checkCancellation()
        guard receiving == nil else { throw WebSocketError.operationConflict(.receive) }
        guard didOpen, let transport else { throw WebSocketError.closed }
        let operation = Pending<WebSocketMessage?>()
        let id = operation.id
        receiving = operation
        transport.receive { [weak self] result in await self?.received(result, id: id) }
        return try await withTaskCancellationHandler {
            try await operation.promise.value()
        } onCancel: { [weak self] in Task { await self?.cancelActive(id) } }
    }

    public func close(code: WebSocketCloseCode = .normal, reason: String? = nil) async throws {
        try WebSocketValidation.closeReason(reason)
        if let closing {
            let id = closing.id
            try await withTaskCancellationHandler { try await closing.promise.value() }
                onCancel: { [weak self] in Task { await self?.expediteClose(id) } }
            return
        }
        if terminal != nil { return }
        try Task.checkCancellation()
        var operation = Pending<Void>()
        let deadline = clock.now().advanced(by: .seconds(configuration.timeouts.close))
        operation.timer = timer(deadline, kind: .close(operation.id))
        closing = operation
        terminate(.end, graceful: true)
        let id = operation.id
        transport?.close(code: code, reason: reason)
        if transport == nil { finishClosing() }
        try await withTaskCancellationHandler {
            try await operation.promise.value()
        } onCancel: { [weak self] in Task { await self?.expediteClose(id) } }
    }

    private func event(_ event: WebSocketTransportEvent) {
        switch event {
        case .opened(let selected):
            guard terminal == nil, let operation = opening else { return }
            if let deadline = operation.deadline, clock.now() >= deadline {
                terminate(.failed(.timeout(.connect))); return
            }
            let offered = configuration.subprotocols
            let selectionAllowed: Bool
            if offered.isEmpty { selectionAllowed = selected == nil }
            else if let selected, HTTPToken.isValid(selected) {
                selectionAllowed = offered.contains { $0.utf8.elementsEqual(selected.utf8) }
            } else { selectionAllowed = false }
            guard selectionAllowed else {
                terminate(.failed(.subprotocolMismatch)); return
            }
            selectedSubprotocol = selected; didOpen = true
            opening = nil; operation.timer?.cancel(); operation.promise.resolve(.success(()))
        case .peerClose(let info): peerClosed(info)
        case .failed(let error):
            if closing != nil { transport?.cancel(); finishClosing() }
            else { terminate(.failed(error)) }
        case .orderlyEnd:
            if closing == nil { terminate(.end) }
        case .stopped:
            if closing != nil { finishClosing() }
            else if terminal == nil {
                terminate(.failed(.transport(.init(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue))))
            }
        }
    }
    private func sent(_ result: Result<Void, WebSocketError>, id: UUID) {
        guard terminal == nil, let operation = sending, operation.id == id else { return }
        if let deadline = operation.deadline, clock.now() >= deadline {
            terminate(.failed(.timeout(.send))); return
        }
        switch result {
        case .success:
            sending = nil; operation.timer?.cancel(); operation.promise.resolve(.success(()))
        case .failure(let error): terminate(.failed(error))
        }
    }
    private func received(_ result: Result<WebSocketIncoming, WebSocketError>, id: UUID) {
        guard terminal == nil, let operation = receiving, operation.id == id else { return }
        switch result {
        case .success(.message(let message)):
            guard message.byteCount <= configuration.maximumMessageBytes else {
                terminate(.failed(.messageTooLarge)); return
            }
            receiving = nil; operation.promise.resolve(.success(message))
        case .success(.peerClose(let info)): peerClosed(info)
        case .success(.orderlyEnd): terminate(.end)
        case .failure(let error): terminate(.failed(error))
        }
    }
    private func peerClosed(_ info: WebSocketCloseInfo) {
        if closing != nil { pendingCloseInfo = info; return }
        guard terminal == nil else { return }
        pendingCloseInfo = info
        if info.code == nil || info.code == 1000 || info.code == 1001 { terminate(.end) }
        else { terminate(.failed(.peerClosed(code: info.code))) }
    }

    private func terminate(_ cause: Terminal, graceful: Bool = false) {
        guard terminal == nil else { return }
        terminal = cause
        providerWork?.cancel(); providerWork = nil
        if let pending = opening {
            opening = nil; pending.timer?.cancel(); pending.promise.resolve(.failure(cause.error))
        }
        if let pending = sending {
            sending = nil; pending.timer?.cancel(); pending.promise.resolve(.failure(cause.error))
        }
        if let pending = receiving {
            receiving = nil
            if case .end = cause { pending.promise.resolve(.success(nil)) }
            else { pending.promise.resolve(.failure(cause.error)) }
        }
        if !graceful {
            closeInfo = pendingCloseInfo ?? transport?.peerCloseInfo
            transport?.cancel(); transport = nil
        }
    }
    private func finishClosing() {
        guard let pending = closing else { return }
        closing = nil; pending.timer?.cancel()
        closeInfo = pendingCloseInfo ?? transport?.peerCloseInfo
        transport?.cancel(); transport = nil
        pending.promise.resolve(.success(()))
    }
    private func cancelOpening(_ id: UUID) {
        if opening?.id == id { terminate(.cancelled) }
    }
    private func cancelActive(_ id: UUID) {
        if sending?.id == id || receiving?.id == id { terminate(.cancelled) }
    }
    private func openingFailed(_ cause: Terminal, id: UUID) {
        guard opening?.id == id else { return }
        if let deadline = opening?.deadline, clock.now() >= deadline { terminate(.failed(.timeout(.connect))) }
        else { terminate(cause) }
    }
    private func expediteClose(_ id: UUID) {
        guard closing?.id == id else { return }
        transport?.cancel(); finishClosing()
    }
    private func deadline(_ kind: Deadline) {
        switch kind {
        case .opening(let id):
            if opening?.id == id { terminate(.failed(.timeout(.connect))) }
        case .send(let id):
            if sending?.id == id { terminate(.failed(.timeout(.send))) }
        case .close(let id): expediteClose(id)
        }
    }
    private func timer(_ deadline: ContinuousClock.Instant, kind: Deadline) -> Task<Void, Never> {
        Task.detached { [weak self, clock] in
            do { try await clock.sleep(until: deadline) }
            catch { return }
            await self?.deadline(kind)
        }
    }
}
#endif
