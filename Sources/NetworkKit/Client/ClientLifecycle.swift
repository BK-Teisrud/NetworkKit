import Foundation
import os

/// Admission can precede reading app-defined endpoint options. Cancellation is
/// remembered even if shutdown starts before the operation binds its handler.
internal final class ClientOperationRegistration: Sendable {
    let id = UUID()
    private struct State: Sendable {
        var cancelled = false
        var handler: (@Sendable () -> Void)?
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    func bind(_ handler: @escaping @Sendable () -> Void) {
        let cancelled = state.withLock {
            if $0.cancelled { return true }
            $0.handler = handler
            return false
        }
        if cancelled { handler() }
    }
    func unbind() { state.withLock { $0.handler = nil } }
    func cancel() {
        let handler: (@Sendable () -> Void)? = state.withLock {
            guard !$0.cancelled else { return nil }
            $0.cancelled = true
            return $0.handler
        }
        handler?()
    }
}

/// Only admission/phase/continuation bookkeeping is synchronized. No callbacks,
/// session operations or await occur while this lock is held.
internal final class ClientLifecycle: Sendable {
    private enum Phase: Sendable { case open, closing, closed }
    private struct State: Sendable {
        var phase = Phase.open
        var operations: [UUID: ClientOperationRegistration] = [:]
        var drained: CheckedContinuation<Void, Never>?
        var closedWaiters: [CheckedContinuation<Void, Never>] = []
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    func register() throws -> ClientOperationRegistration {
        try state.withLock {
            guard $0.phase == .open else { throw NetworkError.invalidRequest(.clientClosed) }
            let registration = ClientOperationRegistration()
            $0.operations[registration.id] = registration
            return registration
        }
    }

    func finish(_ registration: ClientOperationRegistration) {
        let continuation: CheckedContinuation<Void, Never>? = state.withLock {
            guard $0.operations.removeValue(forKey: registration.id) != nil else { return nil }
            guard $0.operations.isEmpty else { return nil }
            let continuation = $0.drained
            $0.drained = nil
            return continuation
        }
        continuation?.resume()
    }

    /// Exactly one caller owns finalization; its task remains responsible even
    /// when cancelled. Other shutdown callers await the same closed transition.
    func beginShutdown() -> [ClientOperationRegistration]? {
        state.withLock {
            guard $0.phase == .open else { return nil }
            $0.phase = .closing
            return Array($0.operations.values)
        }
    }

    func waitUntilDrained() async {
        await withCheckedContinuation { continuation in
            let ready = state.withLock {
                if $0.operations.isEmpty { return true }
                $0.drained = continuation
                return false
            }
            if ready { continuation.resume() }
        }
    }

    func waitUntilClosed() async {
        await withCheckedContinuation { continuation in
            let ready = state.withLock {
                if $0.phase == .closed { return true }
                $0.closedWaiters.append(continuation)
                return false
            }
            if ready { continuation.resume() }
        }
    }

    func completeShutdown() {
        let waiters = state.withLock {
            $0.phase = .closed
            let waiters = $0.closedWaiters
            $0.closedWaiters.removeAll()
            return waiters
        }
        for waiter in waiters { waiter.resume() }
    }
}
