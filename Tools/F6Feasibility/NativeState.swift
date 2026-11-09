import Foundation
import os

enum ProbeFailure: Error, Sendable { case failed(String), cancelled, timeout, duplicate }
func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
    if !condition() { throw ProbeFailure.failed(label) }
}

final class Once<Value: Sendable>: Sendable {
    private struct State: Sendable {
        var result: Result<Value, any Error>?
        var waiters: [CheckedContinuation<Value, any Error>] = []
        var resolutions = 0
    }
    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let onWaiter: (@Sendable (Int) -> Void)?
    init(onWaiter: (@Sendable (Int) -> Void)? = nil) { self.onWaiter = onWaiter }
    @discardableResult func resolve(_ result: Result<Value, any Error>) -> Bool {
        let waiters: [CheckedContinuation<Value, any Error>]? = lock.withLock { state in
            guard state.result == nil else { return nil }
            state.result = result; state.resolutions += 1
            let all = state.waiters; state.waiters.removeAll(); return all
        }
        guard let waiters else { return false }
        for waiter in waiters { waiter.resume(with: result) }; return true
    }
    func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let registration = lock.withLock { state -> (Result<Value, any Error>?, Int) in
                if let result = state.result { return (result, 0) }
                state.waiters.append(continuation); return (nil, state.waiters.count)
            }
            if let result = registration.0 { continuation.resume(with: result) }
            else { onWaiter?(registration.1) }
        }
    }
    var resolutionCount: Int { lock.withLock { $0.resolutions } }
}

func bounded<Value: Sendable>(_ seconds: Double, cancel: @escaping @Sendable () -> Void,
                             operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask { try await Task.sleep(for: .seconds(seconds)); cancel(); throw ProbeFailure.timeout }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

/// Experiment-only terminal admission gate. Handlers are always invoked outside the lock.
/// Admission linearizes under the lock; an already admitted reply can physically return later.
final class ChallengeGate: Sendable {
    typealias Completion = @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    struct Snapshot: Sendable {
        let closed: Bool
        let registered: Int
        let completed: Int
        let admittedCredentials: Int
        let rejected: Int
        let suppressedLateResults: Int
        let pending: Int
    }
    private struct State: Sendable {
        var closed = false
        var next = 0
        var handlers: [Int: Completion] = [:]
        var completed = 0
        var admittedCredentials = 0
        var rejected = 0
        var suppressed = 0
    }
    private let lock = OSAllocatedUnfairLock(initialState: State())
    func register(_ completion: @escaping Completion) -> Int? {
        let token = lock.withLock { state -> Int? in
            state.next += 1
            guard !state.closed else { state.completed += 1; state.rejected += 1; return nil }
            state.handlers[state.next] = completion
            return state.next
        }
        if token == nil { completion(.cancelAuthenticationChallenge, nil) }
        return token
    }
    func complete(_ token: Int, credential: URLCredential?) {
        let reply = lock.withLock { state -> (Completion, URLCredential?)? in
            guard let callback = state.handlers.removeValue(forKey: token) else {
                state.suppressed += 1; return nil
            }
            let admitted = state.closed ? nil : credential
            state.completed += 1
            if admitted != nil { state.admittedCredentials += 1 } else { state.rejected += 1 }
            return (callback, admitted)
        }
        if let (callback, credential) = reply {
            callback(credential == nil ? .cancelAuthenticationChallenge : .useCredential, credential)
        }
    }
    func close() {
        let replies = lock.withLock { state -> [Completion] in
            guard !state.closed else { return [] }
            state.closed = true
            let callbacks = Array(state.handlers.values); state.handlers.removeAll()
            state.completed += callbacks.count; state.rejected += callbacks.count
            return callbacks
        }
        for callback in replies { callback(.cancelAuthenticationChallenge, nil) }
    }
    var snapshot: Snapshot {
        lock.withLock { Snapshot(closed: $0.closed, registered: $0.next, completed: $0.completed,
            admittedCredentials: $0.admittedCredentials, rejected: $0.rejected,
            suppressedLateResults: $0.suppressed, pending: $0.handlers.count) }
    }
}
