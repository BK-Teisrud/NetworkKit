import Foundation
import Testing
import os
@testable import NetworkKit

private struct BudgetCall: Endpoint {
    typealias Response = EmptyResponse
    let path = try! EndpointPath(segments: [])
    var options = NetworkCallOptions.default
    var method: HTTPMethod = .get
    var body: RequestBody? = nil
}
private struct BudgetEncoding: Encodable, Sendable {
    let clock: BudgetTestClock
    func encode(to encoder: any Encoder) throws {
        clock.advance(61)
        var container = encoder.singleValueContainer()
        try container.encode("payload")
    }
}
private struct BudgetDecoding: Decodable, Sendable {
    static let clocks = OSAllocatedUnfairLock(initialState: [UUID: BudgetTestClock]())
    init(from decoder: any Decoder) throws {
        let id = try decoder.singleValueContainer().decode(UUID.self)
        Self.clocks.withLock { $0[id] }?.advance(61)
    }
}
private struct BudgetImmediateTransport: NetworkTransport {
    let data: Data
    func send(_ request: URLRequest) async throws -> TransportResponse {
        TransportResponse(data: data, response: HTTPURLResponse(url: request.url!, statusCode: 200,
                                                               httpVersion: nil, headerFields: [:])!)
    }
}
private struct BudgetSystemTimeoutTransport: NetworkTransport {
    let clock: BudgetTestClock
    func send(_ request: URLRequest) async throws -> TransportResponse {
        try await clock.sleep(until: clock.now().advanced(by: .seconds(30)))
        throw URLError(.timedOut)
    }
}

@Suite(.timeLimit(.minutes(1))) struct OperationBudgetTests {
    private let base = URL(string: "https://example.invalid")!
    private func send(_ client: APIClient, raw: Bool, options: NetworkCallOptions = .default) async throws -> NetworkResponse<EmptyResponse> {
        if raw { return try await client.send(URLRequest(url: base), response: .empty, options: options) }
        return try await client.send(BudgetCall(options: options))
    }

    @Test(arguments: [false, true]) func defaultBudgetExpiresAndJoinsBothChildren(raw: Bool) async throws {
        let clock = BudgetTestClock()
        let origin = clock.now()
        let transport = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let task = Task { try await send(client, raw: raw) }
        await clock.waitForSleepers(2)
        #expect(clock.scheduled.contains(origin.advanced(by: .seconds(60))))
        #expect(await transport.requests.first?.timeoutInterval == 30)
        clock.advance(59)
        #expect(await transport.active == 1)
        clock.advance(1)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(await transport.cancelled == 1)
        #expect(await transport.active == 0)
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func callOverridesClientLimits(raw: Bool) async throws {
        let clock = BudgetTestClock()
        let recording = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            timeouts: NetworkTimeouts(inactivity: 40, total: 90)), transport: recording, clock: clock)
        let options = try NetworkCallOptions(inactivityTimeout: 2, totalTimeout: 5)
        let task = Task { try await send(client, raw: raw, options: options) }
        await clock.waitForSleepers(2)
        #expect(await recording.requests.first?.timeoutInterval == 2)
        clock.advance(5)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(clock.pending == 0)
    }

    @Test func clientLimitsOverrideLibraryDefaults() async throws {
        let clock = BudgetTestClock()
        let start = clock.now(), transport = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            timeouts: NetworkTimeouts(inactivity: 44, total: 120)), transport: transport, clock: clock)
        let task = Task { try await send(client, raw: true) }
        await clock.waitForSleepers(2)
        #expect(clock.scheduled.contains(start.advanced(by: .seconds(120))))
        #expect(await transport.requests.first?.timeoutInterval == 44)
        clock.advance(120)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func preCancelledCallerDoesNotStartTransport(raw: Bool) async throws {
        let clock = BudgetTestClock()
        let recording = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: recording, clock: clock)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await send(client, raw: raw)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await recording.requests.isEmpty)
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func cancellationDuringIOStopsAndJoinsWork(raw: Bool) async throws {
        let clock = BudgetTestClock()
        let transport = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let task = Task { try await send(client, raw: raw) }
        await clock.waitForSleepers(2)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await transport.cancelled == 1)
        #expect(await transport.active == 0)
        #expect(clock.pending == 0)
    }

    @Test func cancellationIsScopedToOneCall() async throws {
        let clock = BudgetTestClock()
        let recording = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: recording, clock: clock)
        let first = Task { try await send(client, raw: false) }
        let second = Task { try await send(client, raw: true) }
        await clock.waitForSleepers(4)
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await recording.active == 1)
        #expect(clock.pending == 2)
        clock.advance(60)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await second.value }
        #expect(clock.pending == 0)
    }

    @Test func encodingTimeCannotSendAfterExpiration() async throws {
        let clock = BudgetTestClock()
        let transport = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let call = BudgetCall(method: .post, body: .json(BudgetEncoding(clock: clock)))
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await client.send(call) }
        #expect(await transport.requests.isEmpty)
        #expect(clock.pending == 0)
    }

    @Test func optionsAndSchedulingTimeBelongToBudget() async throws {
        struct SlowOptions: Endpoint {
            typealias Response = EmptyResponse
            let clock: BudgetTestClock
            let path = try! EndpointPath(segments: [])
            var options: NetworkCallOptions { clock.advance(61); return .default }
        }
        let clock = BudgetTestClock()
        let transport = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await client.send(SlowOptions(clock: clock)) }
        #expect(await transport.requests.isEmpty)
        #expect(clock.pending == 0)
    }

    @Test func decodingTimeCannotProduceLateSuccess() async throws {
        let clock = BudgetTestClock(), id = UUID()
        BudgetDecoding.clocks.withLock { $0[id] = clock }
        defer { _ = BudgetDecoding.clocks.withLock { $0.removeValue(forKey: id) } }
        let data = try JSONEncoder().encode(id)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base),
            transport: BudgetImmediateTransport(data: data), clock: clock)
        await #expect(throws: NetworkError.timeout(.totalBudget)) {
            try await client.send(URLRequest(url: base), response: .json(BudgetDecoding.self))
        }
        #expect(clock.pending == 0)
    }

    @Test func futureSuspendingHookIsInsideOperationBudget() async throws {
        let clock = BudgetTestClock()
        let task = Task {
            try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: 5) { _ in
                try await clock.sleep(until: clock.now().advanced(by: .seconds(7200)))
                return 1
            }
        }
        await clock.waitForSleepers(2)
        clock.advance(5)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(clock.pending == 0)
    }

    @Test func systemTimeoutIsDistinctFromTotalTimeout() async throws {
        let clock = BudgetTestClock()
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base),
            transport: BudgetSystemTimeoutTransport(clock: clock), clock: clock)
        let task = Task { try await send(client, raw: true) }
        await clock.waitForSleepers(2)
        clock.advance(30)
        await #expect(throws: NetworkError.timeout(.system)) { try await task.value }
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func firstRecordedInterruptionSurvivesCleanupRace(timeoutFirst: Bool) async throws {
        let started = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (started, release))
        let recording = BudgetTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: recording, clock: clock)
        let task = Task { try await send(client, raw: true) }
        await clock.waitForSleepers(2)
        if timeoutFirst { clock.advance(60) } else { task.cancel() }
        await started.wait() // First terminal event is recorded; cooperative cleanup is held.
        if timeoutFirst { task.cancel() } else { clock.advance(60) }
        await release.open()
        if timeoutFirst {
            await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        } else { await #expect(throws: CancellationError.self) { try await task.value } }
        #expect(clock.pending == 0)
        #expect(await recording.active == 0)
    }

    @Test(arguments: [false, true]) func selectedCompletionSurvivesCancellationWhileWatchdogJoins(failure: Bool) async throws {
        let started = BudgetLatch(), release = BudgetLatch(), complete = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (started, release))
        let task = Task {
            try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: 60) { _ in
                await complete.wait()
                if failure { throw NetworkError.decoding }
                return 42
            }
        }
        await clock.waitForSleepers(1)
        await complete.open()
        await started.wait() // Watchdog cancellation proves worker completion was selected.
        task.cancel()
        await release.open()
        if failure { await #expect(throws: NetworkError.decoding) { try await task.value } }
        else { #expect(try await task.value == 42) }
        #expect(clock.pending == 0)
    }

    @Test func extremePositiveBudgetsDoNotOverflowOrLeaveSleepers() async throws {
        for total in [Double.greatestFiniteMagnitude, Double.leastNonzeroMagnitude] {
            let clock = BudgetTestClock()
            let task = Task {
                try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: total) { _ in
                    try await clock.sleep(until: clock.now().advanced(by: .seconds(7200)))
                    return 1
                }
            }
            await clock.waitForSleepers(2)
            if total > 1 { task.cancel() }
            else { clock.advance(1e-9) }
            if total > 1 { await #expect(throws: CancellationError.self) { try await task.value } }
            else { await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value } }
            #expect(clock.pending == 0)
        }
    }

    @Test func longBudgetContinuesAcrossBoundedSleeps() async throws {
        let clock = BudgetTestClock()
        let origin = clock.now()
        let task = Task {
            try await NetworkOperation<Int>.run(clock: clock, start: origin, total: 172_800) { _ in
                try await clock.sleep(until: origin.advanced(by: .seconds(259_200)))
                return 1
            }
        }
        await clock.waitForSleepers(2)
        clock.advance(86_400)
        await clock.waitForSleepers(2)
        #expect(clock.scheduled.contains(origin.advanced(by: .seconds(172_800))))
        clock.advance(86_400)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func borrowedSessionStopsOnlyThisOperation(expire: Bool) async throws {
        let clock = BudgetTestClock(), started = BudgetLatch(), stopped = BudgetLatch()
        let hold = SessionStubProtocol.install(.init(data: Data(), status: 204, headers: [:], hold: true,
            onStart: { Task { await started.open() } }, onStop: { Task { await stopped.open() } }))
        let other = SessionStubProtocol.install(.init(data: Data("other".utf8), status: 200, headers: [:]))
        defer { SessionStubProtocol.remove(hold); SessionStubProtocol.remove(other) }
        let settings = URLSessionTransport.configuration()
        #if !os(watchOS)
        settings.protocolClasses = [SessionStubProtocol.self]
        #endif
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        #if os(watchOS)
        // Explicit scripted I/O; watchOS cannot intercept URLSession with URLProtocol.
        let operation: URLSessionTransport.DataOperation = { _, request, _ in
            if request.url == hold {
                await started.open()
                do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
                catch { await stopped.open(); throw error }
            }
            return TransportResponse(data: Data("other".utf8), response: HTTPURLResponse(url: request.url!,
                statusCode: 200, httpVersion: nil, headerFields: [:])!)
        }
        #else
        let operation = URLSessionTransport.systemDataOperation
        #endif
        let transport = try URLSessionTransport(session: session, dataOperation: operation, baseURL: base)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let task = Task { try await client.send(URLRequest(url: hold), response: .empty) }
        await started.wait()
        #if os(watchOS)
        await clock.waitForSleepers(2)
        #else
        await clock.waitForSleepers(1)
        #endif
        if expire { clock.advance(60) } else { task.cancel() }
        if expire { await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value } }
        else { await #expect(throws: CancellationError.self) { try await task.value } }
        await stopped.wait()
        #expect(clock.pending == 0)
        #expect(await transport.ownsSession == false)
        #if os(watchOS)
        #expect(try await transport.send(URLRequest(url: other)).data == Data("other".utf8))
        #else
        // An independent app task still uses the original borrowed session successfully.
        let (data, _) = try await session.data(for: URLRequest(url: other))
        #expect(data == Data("other".utf8))
        #endif
    }

}
