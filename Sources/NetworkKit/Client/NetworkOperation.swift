import Foundation
import os

/// Per-call terminal arbitration. No lock is held across suspension or app code.
internal final class NetworkOperation<Value: Sendable>: Sendable {
    private struct State: Sendable {
        var result: Result<Value, any Error>?
        var terminalWaiter: CheckedContinuation<Void, Never>?
        var cancellation: NetworkDiagnosticEvent.CancellationCause?
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let clock: any NetworkClock
    private let start: ContinuousClock.Instant
    private let total: TimeInterval

    private init(clock: any NetworkClock, start: ContinuousClock.Instant, total: TimeInterval) {
        self.clock = clock
        self.start = start
        self.total = total
    }

    private func elapsed(at instant: ContinuousClock.Instant? = nil) -> Double {
        let components = start.duration(to: instant ?? clock.now()).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    /// Called only under state synchronization. The internal clock must read time
    /// synchronously without invoking callbacks or acquiring this operation's lock.
    private func interruption() -> (any Error)? {
        if Task.isCancelled { return CancellationError() }
        if elapsed() >= total { return NetworkError.timeout(.totalBudget) }
        return nil
    }

    /// Reads the original budget; retries never create a new operation or deadline.
    func remainingBudget() -> TimeInterval { max(0, total - elapsed()) }

    func checkpoint() throws {
        let result: ((any Error)?, CheckedContinuation<Void, Never>?) = state.withLock { state in
            if case .failure(let error) = state.result { return (error, nil) }
            guard state.result == nil, let error = interruption() else { return (nil, nil) }
            state.result = .failure(error)
            if error is CancellationError { state.cancellation = .caller }
            let waiter = state.terminalWaiter
            state.terminalWaiter = nil
            return (error, waiter)
        }
        result.1?.resume()
        if let error = result.0 { throw error }
    }

    private func finish(_ result: Result<Value, any Error>) {
        let waiter = state.withLock { state in
            guard state.result == nil else { return Optional<CheckedContinuation<Void, Never>>.none }
            if let error = interruption() {
                state.result = .failure(error)
                if error is CancellationError { state.cancellation = .caller }
            } else {
                state.result = result
                if case .failure(let error) = result, error is CancellationError { state.cancellation = .unspecified }
            }
            let waiter = state.terminalWaiter
            state.terminalWaiter = nil
            return waiter
        }
        waiter?.resume()
    }

    private func cancel(cause: NetworkDiagnosticEvent.CancellationCause) {
        let waiter = state.withLock { state in
            guard state.result == nil else { return Optional<CheckedContinuation<Void, Never>>.none }
            state.result = .failure(CancellationError())
            state.cancellation = cause
            let waiter = state.terminalWaiter
            state.terminalWaiter = nil
            return waiter
        }
        waiter?.resume()
    }

    private func waitForTerminal() async {
        await withCheckedContinuation { continuation in
            let ready = state.withLock {
                if $0.result != nil { return true }
                $0.terminalWaiter = continuation
                return false
            }
            if ready { continuation.resume() }
        }
    }

    private func watch() async {
        while !Task.isCancelled {
            let wake: (ContinuousClock.Instant?, CheckedContinuation<Void, Never>?) = state.withLock { state in
                guard state.result == nil else { return (nil, nil) }
                let now = clock.now()
                let remaining = total - elapsed(at: now)
                if remaining <= 0 {
                    state.result = .failure(NetworkError.timeout(.totalBudget))
                    let waiter = state.terminalWaiter
                    state.terminalWaiter = nil
                    return (nil, waiter)
                }
                // Bound only the next sleep, not the selected total budget.
                let interval = min(max(remaining, 1e-9), 86_400)
                return (now.advanced(by: .seconds(interval)), nil)
            }
            wake.1?.resume()
            guard let deadline = wake.0 else { return }
            // No arbitrary finite Double is converted into an overflowing duration.
            // Tiny waits round up to a nanosecond; each wake rechecks elapsed time.
            do {
                try await clock.sleep(until: deadline)
            } catch is CancellationError {
                if !Task.isCancelled {
                    finish(.failure(NetworkError.invalidRequest(.invalidConfiguration)))
                }
                return // Group cleanup cancellation is not caller cancellation.
            } catch {
                finish(.failure(NetworkError.invalidRequest(.invalidConfiguration)))
                return
            }
        }
    }

    static func run(clock: any NetworkClock, start: ContinuousClock.Instant, total: TimeInterval,
                    registration: ClientOperationRegistration? = nil, diagnostic: DiagnosticObservation? = nil,
                    body: @escaping @Sendable (NetworkOperation<Value>) async throws -> Value) async throws -> Value {
        guard total.isFinite, total > 0 else { throw NetworkError.invalidRequest(.invalidConfiguration) }
        let operation = NetworkOperation(clock: clock, start: start, total: total)
        registration?.bind { operation.cancel(cause: .shutdown) }
        defer { registration?.unbind() }
        return try await withTaskCancellationHandler {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        try operation.checkpoint()
                        let value = try await body(operation)
                        operation.finish(.success(value))
                    } catch { operation.finish(.failure(error)) }
                }
                group.addTask { await operation.watch() }
                await operation.waitForTerminal()
                group.cancelAll()
                // Join both children: never leave an operation or watchdog detached.
                while await group.next() != nil {}
            }
            let terminal = operation.state.withLock { ($0.result, $0.cancellation) }
            diagnostic?.cancelled(by: terminal.1)
            guard let result = terminal.0 else {
                throw NetworkError.invalidRequest(.invalidConfiguration)
            }
            return try result.get()
        } onCancel: { operation.cancel(cause: .caller) }
    }
}
