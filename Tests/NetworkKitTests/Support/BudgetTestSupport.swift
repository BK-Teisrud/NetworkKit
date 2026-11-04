import Foundation
import os
@testable import NetworkKit

actor BudgetLatch {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    var isOpen: Bool { opened }
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

private final class BudgetSleep: Sendable {
    private enum State: Sendable {
        case pending
        case waiting(CheckedContinuation<Void, any Error>)
        case finished(Result<Void, any Error>)
    }
    private let state = OSAllocatedUnfairLock(initialState: State.pending)
    var finished: Bool { state.withLock { if case .finished = $0 { true } else { false } } }
    func register(_ continuation: CheckedContinuation<Void, any Error>) {
        let result: Result<Void, any Error>? = state.withLock {
            if case .finished(let result) = $0 { return result }
            $0 = .waiting(continuation)
            return nil
        }
        if let result { continuation.resume(with: result) }
    }
    func finish(_ result: Result<Void, any Error>) {
        let continuation: CheckedContinuation<Void, any Error>? = state.withLock {
            if case .finished = $0 { return nil }
            let continuation: CheckedContinuation<Void, any Error>?
            if case .waiting(let value) = $0 { continuation = value } else { continuation = nil }
            $0 = .finished(result)
            return continuation
        }
        continuation?.resume(with: result)
    }
}

/// No real sleeps: advancing time resolves registered continuations exactly once.
/// Clock state is released before callbacks. Cancellation before registration is
/// retained by the per-sleep ticket rather than leaking cancellation tombstones.
final class BudgetTestClock: NetworkClock {
    private struct Sleeper: Sendable { let deadline: ContinuousClock.Instant; let ticket: BudgetSleep }
    private struct Observer: Sendable { let count: Int; let continuation: CheckedContinuation<Void, Never> }
    private struct State: Sendable {
        var now = ContinuousClock().now
        var sleepers: [UUID: Sleeper] = [:]
        var observers: [Observer] = []
        var scheduled: [ContinuousClock.Instant] = []
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let cleanup: (started: BudgetLatch, release: BudgetLatch)?
    init(cleanup: (started: BudgetLatch, release: BudgetLatch)? = nil) { self.cleanup = cleanup }
    func now() -> ContinuousClock.Instant { state.withLock { $0.now } }
    var pending: Int { state.withLock { $0.sleepers.count } }
    var scheduled: [ContinuousClock.Instant] { state.withLock { $0.scheduled } }
    func advance(_ seconds: Double) {
        let ready: [BudgetSleep] = state.withLock { state in
            state.now = state.now.advanced(by: .seconds(seconds))
            let ready = state.sleepers.filter { $0.value.deadline <= state.now }
            for id in ready.keys { state.sleepers.removeValue(forKey: id) }
            return ready.values.map(\.ticket)
        }
        for ticket in ready { ticket.finish(.success(())) }
    }
    func waitForSleepers(_ count: Int) async {
        await withCheckedContinuation { continuation in
            let ready = state.withLock {
                if $0.sleepers.count >= count { return true }
                $0.observers.append(Observer(count: count, continuation: continuation))
                return false
            }
            if ready { continuation.resume() }
        }
    }
    func sleep(until deadline: ContinuousClock.Instant) async throws {
        let id = UUID(), ticket = BudgetSleep()
        do {
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    ticket.register(continuation)
                    let result: (Bool, [Observer]) = state.withLock {
                        $0.scheduled.append(deadline)
                        if ticket.finished { return (false, []) }
                        if deadline <= $0.now { return (true, []) }
                        $0.sleepers[id] = Sleeper(deadline: deadline, ticket: ticket)
                        let count = $0.sleepers.count
                        let ready = $0.observers.filter { $0.count <= count }
                        $0.observers.removeAll { $0.count <= count }
                        return (false, ready)
                    }
                    for observer in result.1 { observer.continuation.resume() }
                    if result.0 { ticket.finish(.success(())) }
                }
            } onCancel: {
                _ = self.state.withLock { $0.sleepers.removeValue(forKey: id) }
                ticket.finish(.failure(CancellationError()))
            }
        } catch {
            if let cleanup {
                await cleanup.started.open()
                await cleanup.release.wait()
            }
            throw error
        }
    }
}

actor BudgetTransport: NetworkTransport {
    let clock: BudgetTestClock
    private(set) var requests: [URLRequest] = []
    private(set) var active = 0
    private(set) var cancelled = 0
    init(clock: BudgetTestClock) { self.clock = clock }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request); active += 1
        defer { active -= 1 }
        do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
        catch { cancelled += 1; throw URLError(.cancelled) }
        return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 204,
                                                                        httpVersion: nil, headerFields: [:])!)
    }
}
