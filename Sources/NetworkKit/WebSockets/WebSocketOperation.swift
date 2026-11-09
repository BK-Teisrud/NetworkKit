#if !os(watchOS)
import Foundation
import Synchronization

/// One shared result; concurrent close callers may register separate continuations. No lock held while resuming.
internal final class WebSocketPromise<Value: Sendable>: Sendable {
    private struct State: Sendable {
        var result: Result<Value, any Error>?
        var waiters: [CheckedContinuation<Value, any Error>] = []
    }
    private let state = Mutex(State())

    func resolve(_ result: Result<Value, any Error>) {
        let waiters: [CheckedContinuation<Value, any Error>] = state.withLock { s in
            guard s.result == nil else { return [] }
            s.result = result
            let waiters = s.waiters
            s.waiters = []
            return waiters
        }
        for waiter in waiters { waiter.resume(with: result) }
    }
    func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let result: Result<Value, any Error>? = state.withLock { s in
                if let result = s.result { return result }
                s.waiters.append(continuation)
                return nil
            }
            if let result { continuation.resume(with: result) }
        }
    }
}

internal struct WebSocketOpenRequest: Sendable {
    let endpoint: URL
    let headers: HTTPHeaders
    let subprotocols: [String]
    let maximumMessageBytes: Int
}
internal enum WebSocketIncoming: Sendable {
    case message(WebSocketMessage)
    case peerClose(WebSocketCloseInfo)
    case orderlyEnd
}
internal enum WebSocketTransportEvent: Sendable {
    case opened(selectedProtocol: String?)
    case peerClose(WebSocketCloseInfo)
    case failed(WebSocketError)
    case orderlyEnd
    case stopped
}
internal protocol WebSocketTransport: Sendable {
    var peerCloseInfo: WebSocketCloseInfo? { get }
    func start()
    func send(_ message: WebSocketMessage, completion: @escaping @Sendable (Result<Void, WebSocketError>) async -> Void)
    func receive(completion: @escaping @Sendable (Result<WebSocketIncoming, WebSocketError>) async -> Void)
    func close(code: WebSocketCloseCode, reason: String?)
    func cancel()
}
extension WebSocketTransport {
    internal var peerCloseInfo: WebSocketCloseInfo? { nil }
}
internal typealias WebSocketTransportFactory = @Sendable (
    WebSocketOpenRequest, @escaping @Sendable (WebSocketTransportEvent) async -> Void
) -> any WebSocketTransport
#endif
