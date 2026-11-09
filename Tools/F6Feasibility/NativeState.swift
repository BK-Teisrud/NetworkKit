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
