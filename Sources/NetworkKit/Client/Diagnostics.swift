import Foundation
import os

/// A local, app-owned, concurrency-safe receiver. Keep recording fast and nonblocking.
/// No raw request/response/error hook, automatic file write or telemetry is provided.
public protocol NetworkDiagnosticSink: Sendable {
    func record(_ event: NetworkDiagnosticEvent)
}

/// Terminal metadata only. The library constructs events from a fixed allowlist.
public struct NetworkDiagnosticEvent: Sendable, Equatable {
    public enum Method: String, Sendable {
        case get = "GET", head = "HEAD", post = "POST", put = "PUT", patch = "PATCH"
        case delete = "DELETE", options = "OPTIONS", custom
        internal init(_ value: String) { self = Self(rawValue: value) ?? .custom }
    }
    public enum CancellationCause: String, Sendable { case caller, shutdown, unspecified }
    public enum Outcome: Sendable, Equatable {
        case success
        case invalidRequest(NetworkError.InvalidRequestReason)
        case transport
        case httpStatus
        case invalidResponse(NetworkError.InvalidResponseReason)
        case encoding
        case decoding
        case timeout(NetworkError.TimeoutReason)
        case cancelled(CancellationCause)
        case other
    }
    public let requestID: UUID
    /// Nil when preparation failed or admission was rejected; custom strings are never retained.
    public let method: Method?
    /// A validated HTTP status if transport delivered one, including before decoding failed.
    public let status: HTTPStatus?
    /// Monotonic call-entry through joined cleanup, excluding the sink callback itself.
    public let duration: TimeInterval
    /// Actual library transport invocations (0...2), excluding redirects/OS attempts.
    public let attemptCount: Int
    public let outcome: Outcome
}

/// Stores only already-sanitized fields. No app callback runs with this lock held.
internal final class DiagnosticObservation: Sendable {
    let requestID = UUID()
    private struct State: Sendable {
        var method: NetworkDiagnosticEvent.Method?
        var status: HTTPStatus?
        var attemptCount = 0
        var cancellation: NetworkDiagnosticEvent.CancellationCause?
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let sink: (any NetworkDiagnosticSink)?
    private let clock: any NetworkClock
    private let start: ContinuousClock.Instant
    init(sink: (any NetworkDiagnosticSink)?, clock: any NetworkClock, start: ContinuousClock.Instant) {
        self.sink = sink; self.clock = clock; self.start = start
    }
    func prepared(_ request: URLRequest) {
        let method = NetworkDiagnosticEvent.Method(request.httpMethod ?? "GET")
        state.withLock { $0.method = method }
    }
    func attemptStarted() {
        state.withLock { $0.attemptCount += 1; $0.status = nil }
    }
    func received(_ response: URLResponse) {
        let status = (response as? HTTPURLResponse).flatMap { try? HTTPStatus($0.statusCode) }
        state.withLock { $0.status = status }
    }
    func cancelled(by cause: NetworkDiagnosticEvent.CancellationCause?) {
        state.withLock { $0.cancellation = cause }
    }
    func complete(error: (any Error)? = nil) {
        guard let sink else { return }
        let snapshot = state.withLock { $0 }
        let outcome: NetworkDiagnosticEvent.Outcome
        if let error {
            if error is CancellationError { outcome = .cancelled(snapshot.cancellation ?? (Task.isCancelled ? .caller : .unspecified)) }
            else if let error = error as? NetworkError {
                switch error {
                case .invalidRequest(let reason): outcome = .invalidRequest(reason)
                case .transport: outcome = .transport
                case .httpStatus: outcome = .httpStatus
                case .invalidResponse(let reason): outcome = .invalidResponse(reason)
                case .encoding: outcome = .encoding
                case .decoding: outcome = .decoding
                case .timeout(let reason): outcome = .timeout(reason)
                }
            } else { outcome = .other }
        } else { outcome = .success }
        let components = start.duration(to: clock.now()).components
        let duration = max(0, Double(components.seconds) + Double(components.attoseconds) / 1e18)
        sink.record(NetworkDiagnosticEvent(requestID: requestID, method: snapshot.method,
            status: snapshot.status, duration: duration, attemptCount: snapshot.attemptCount, outcome: outcome))
    }
}
