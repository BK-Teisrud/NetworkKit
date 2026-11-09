#if !os(watchOS)
import Foundation
import Synchronization
@testable import NetworkKit

final class WebSocketTestTransport: WebSocketTransport {
    struct State: Sendable {
        var requests: [WebSocketMessage] = []
        var receiveCount = 0
        var cancellations = 0
        var closes: [(WebSocketCloseCode, String?)] = []
        var sendCallback: (@Sendable (Result<Void, WebSocketError>) async -> Void)?
        var receiveCallback: (@Sendable (Result<WebSocketIncoming, WebSocketError>) async -> Void)?
        var peer: WebSocketCloseInfo?
    }
    let state = Mutex(State())
    let sends = WebSocketTestCounter()
    let receives = WebSocketTestCounter()
    let sendStarted = WebSocketPromise<Void>()
    let receiveStarted = WebSocketPromise<Void>()
    let closeStarted = WebSocketPromise<Void>()
    let started = WebSocketPromise<Void>()
    let events: @Sendable (WebSocketTransportEvent) async -> Void
    let autoOpen: Bool
    let selected: String?
    let autoClose: Bool
    init(autoOpen: Bool = true, selected: String? = nil, autoClose: Bool = true,
         events: @escaping @Sendable (WebSocketTransportEvent) async -> Void) {
        self.autoOpen = autoOpen; self.selected = selected; self.autoClose = autoClose; self.events = events
    }
    func start() {
        started.resolve(.success(()))
        if autoOpen { Task { await events(.opened(selectedProtocol: selected)) } }
    }
    func send(_ message: WebSocketMessage, completion: @escaping @Sendable (Result<Void, WebSocketError>) async -> Void) {
        state.withLock { $0.requests.append(message); $0.sendCallback = completion }
        sends.increment(); sendStarted.resolve(.success(()))
    }
    func receive(completion: @escaping @Sendable (Result<WebSocketIncoming, WebSocketError>) async -> Void) {
        state.withLock { $0.receiveCount += 1; $0.receiveCallback = completion }
        receives.increment(); receiveStarted.resolve(.success(()))
    }
    func close(code: WebSocketCloseCode, reason: String?) {
        state.withLock { $0.closes.append((code, reason)) }
        closeStarted.resolve(.success(()))
        if autoClose { Task { await events(.stopped) } }
    }
    func cancel() { state.withLock { $0.cancellations += 1 } }
    var peerCloseInfo: WebSocketCloseInfo? { state.withLock { $0.peer } }
    func finishSend(_ result: Result<Void, WebSocketError> = .success(())) async {
        let callback = state.withLock { s in let c = s.sendCallback; s.sendCallback = nil; return c }
        await callback?(result)
    }
    func finishReceive(_ result: Result<WebSocketIncoming, WebSocketError>) async {
        let callback = state.withLock { s in let c = s.receiveCallback; s.receiveCallback = nil; return c }
        await callback?(result)
    }
    func peer(_ info: WebSocketCloseInfo) async {
        state.withLock { $0.peer = info }; await events(.peerClose(info))
    }
}

final class WebSocketTestFactory: Sendable {
    struct State: Sendable {
        var requests: [WebSocketOpenRequest] = []
        var transports: [WebSocketTestTransport] = []
    }
    let state = Mutex(State())
    let created = WebSocketPromise<WebSocketTestTransport>()
    let autoOpen: Bool, autoClose: Bool
    let selected: String?
    init(autoOpen: Bool = true, selected: String? = nil, autoClose: Bool = true) {
        self.autoOpen = autoOpen; self.selected = selected; self.autoClose = autoClose
    }
    func make(_ request: WebSocketOpenRequest,
              events: @escaping @Sendable (WebSocketTransportEvent) async -> Void) -> any WebSocketTransport {
        let transport = WebSocketTestTransport(autoOpen: autoOpen, selected: selected, autoClose: autoClose, events: events)
        state.withLock { $0.requests.append(request); $0.transports.append(transport) }
        created.resolve(.success(transport))
        return transport
    }
}

func webSocketTestConfiguration(maximum: Int = 65536, auth: NetworkAuthentication? = nil,
                                headers: HTTPHeaders = .init(), protocols: [String] = []) throws -> WebSocketConfiguration {
    try WebSocketConfiguration(endpoint: URL(string: "wss://service.invalid:8443/data%20feed?q=a%2Bb")!,
        maximumMessageBytes: maximum, headers: headers, authentication: auth, subprotocols: protocols)
}
func webSocketTestConnection(configuration: WebSocketConfiguration? = nil,
                             factory: WebSocketTestFactory = WebSocketTestFactory(),
                             clock: any NetworkClock = BudgetTestClock()) async throws -> WebSocketConnection {
    try await WebSocketConnection.connect(configuration: configuration ?? webSocketTestConfiguration(),
        clock: clock, factory: { request, events in factory.make(request, events: events) })
}
#endif
#if !os(watchOS)
final class WebSocketTestCounter: Sendable {
    struct State: Sendable { var count = 0; var waiters: [(Int, WebSocketPromise<Void>)] = [] }
    let state = Mutex(State())
    func increment() {
        let ready = state.withLock { s in
            s.count += 1
            let ready = s.waiters.filter { $0.0 <= s.count }.map(\.1)
            s.waiters.removeAll { $0.0 <= s.count }
            return ready
        }
        ready.forEach { $0.resolve(.success(())) }
    }
    func wait(_ count: Int) async throws {
        let promise = WebSocketPromise<Void>()
        let ready = state.withLock { s in
            if s.count >= count { return true }; s.waiters.append((count, promise)); return false
        }
        if ready { promise.resolve(.success(())) }
        try await promise.value()
    }
}

actor WebSocketTestProvider: AuthenticationHeaderProvider {
    let started = BudgetLatch()
    let finished = BudgetLatch()
    let release: BudgetLatch?
    let supplied: HTTPHeaders
    let failure: (any Error)?
    private(set) var contexts: [AuthenticationContext] = []
    private(set) var cancellationObserved = false
    init(supplied: HTTPHeaders = .init(), release: BudgetLatch? = nil, failure: (any Error)? = nil) {
        self.supplied = supplied; self.release = release; self.failure = failure
    }
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        contexts.append(context); await started.open()
        if let release { await release.wait() }
        cancellationObserved = Task.isCancelled
        await finished.open()
        if let failure { throw failure }
        return supplied
    }
}
#endif
