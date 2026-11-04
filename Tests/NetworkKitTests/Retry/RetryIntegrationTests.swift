import Foundation
import Testing
import os
@testable import NetworkKit

private struct RetryCall<Value: Sendable>: Endpoint {
    let path = try! EndpointPath(segments: ["read"])
    let responseStrategy: ResponseStrategy<Value>
    var options: NetworkCallOptions = .default
    var method: HTTPMethod = .get
    var body: RequestBody?
}
private actor RetryTransport: NetworkTransport {
    private(set) var requests: [URLRequest] = []
    private(set) var active = 0
    private(set) var peak = 0
    let work: @Sendable (Int, URLRequest) async throws -> TransportResponse
    init(_ work: @escaping @Sendable (Int, URLRequest) async throws -> TransportResponse) { self.work = work }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request); active += 1; peak = max(peak, active)
        let index = requests.count
        defer { active -= 1 }
        return try await work(index, request)
    }
}
private actor RetryProvider: AuthenticationHeaderProvider {
    private(set) var contexts: [AuthenticationContext] = []
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        contexts.append(context)
        return try HTTPHeaders(["Authorization": "synthetic-auth"])
    }
}
private final class RetrySink: NetworkDiagnosticSink {
    private let lock = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    var events: [NetworkDiagnosticEvent] { lock.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) { lock.withLock { $0.append(event) } }
}
private func retryResponse(_ request: URLRequest, status: Int, headers: [String: String] = [:],
                           data: Data = Data("ok".utf8)) -> TransportResponse {
    TransportResponse(data: data, response: HTTPURLResponse(url: request.url!, statusCode: status,
        httpVersion: nil, headerFields: headers)!)
}

/// Models time consumed after a budget snapshot without real-time timing assertions.
/// Rejects an attempted sleep past admission's deadline instead of hanging a bad build.
private final class RetryDecisionBudgetClock: NetworkClock {
    let base = BudgetTestClock()
    private let advance = OSAllocatedUnfairLock(initialState: 0.0)
    private let violations = OSAllocatedUnfairLock(initialState: 0)
    private let originalDeadline: ContinuousClock.Instant
    init() { originalDeadline = base.now().advanced(by: .seconds(1)) }
    func consumeAfterNextSnapshot(_ seconds: Double) { advance.withLock { $0 = seconds } }
    var forbiddenSleeps: Int { violations.withLock { $0 } }
    func now() -> ContinuousClock.Instant {
        let snapshot = base.now()
        let elapsed = advance.withLock { value in let result = value; value = 0; return result }
        if elapsed > 0 { base.advance(elapsed) }
        return snapshot
    }
    func sleep(until deadline: ContinuousClock.Instant) async throws {
        if deadline > originalDeadline {
            violations.withLock { $0 += 1 }
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        try await base.sleep(until: deadline)
    }
}

@Suite(.timeLimit(.minutes(1))) struct RetryIntegrationTests {
    private let base = URL(string: "https://example.invalid")!
    private let timing = RetryTiming(wallNow: { Date(timeIntervalSince1970: 784111777) }, jitter: { 0.25 })
    private func send(_ client: APIClient, raw: Bool = true, options: NetworkCallOptions) async throws -> NetworkResponse<String> {
        if raw { return try await client.send(URLRequest(url: base.appendingPathComponent("read")), response: .text, options: options) }
        return try await client.send(RetryCall(responseStrategy: .text, options: options))
    }

    @Test(arguments: [false, true], [429, 503])
    func retriesPrepareAuthOnceAndReportOneTerminal(raw: Bool, status: Int) async throws {
        let clock = BudgetTestClock(), sink = RetrySink(), provider = RetryProvider()
        let transport = RetryTransport { index, request in
            retryResponse(request, status: index == 1 ? status : 200,
                          headers: index == 1 ? ["Retry-After": "0"] : [:],
                          data: index == 1 ? Data([0xff]) : Data("ok".utf8))
        }
        let client = try APIClient(configuration: .init(baseURL: base,
            authentication: .init(provider: provider, account: "synthetic-account"), diagnostics: sink),
            transport: transport, clock: clock, retryTiming: timing)
        let task = Task { try await send(client, raw: raw, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2)
        #expect(await transport.requests.count == 1)
        clock.advance(0.25)
        #expect(try await task.value.value == "ok")
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests[0] == requests[1])
        #expect(await transport.peak == 1)
        #expect(await provider.contexts.count == 1)
        #expect(sink.events.count == 1)
        #expect(sink.events.first?.attemptCount == 2)
        #expect(sink.events.first?.status?.code == 200)
        #expect(clock.pending == 0)
    }

    @Test(arguments: [-1004, -1005]) func exactTransportFailuresRetry(code: Int) async throws {
        let clock = BudgetTestClock()
        let transport = RetryTransport { index, request in
            if index == 1 { throw NSError(domain: NSURLErrorDomain, code: code) }
            return retryResponse(request, status: 200)
        }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2); clock.advance(0.25)
        #expect(try await task.value.status.code == 200)
        #expect(await transport.requests.count == 2)
    }

    @Test(arguments: [false, true]) func defaultNeverRetries(raw: Bool) async throws {
        let sink = RetrySink()
        let transport = RetryTransport { _, request in retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport)
        await #expect(throws: NetworkError.httpStatus(try HTTPStatus(503), headers: HTTPHeaders())) {
            try await send(client, raw: raw, options: .default)
        }
        #expect(await transport.requests.count == 1)
        #expect(sink.events.first?.attemptCount == 1)
    }

    @Test(arguments: ["401", "offline", "tls", "dns", "timeout", "domain", "decode", "accepted503", "badHint"])
    func excludedOutcomesNeverSendAgain(mode: String) async throws {
        let sink = RetrySink()
        let transport = RetryTransport { _, request in
            switch mode {
            case "offline": throw URLError(.notConnectedToInternet)
            case "tls": throw URLError(.serverCertificateUntrusted)
            case "dns": throw URLError(.cannotFindHost)
            case "timeout": throw URLError(.timedOut)
            case "domain": throw NSError(domain: "OtherDomain", code: -1005)
            default: return retryResponse(request, status: mode == "401" ? 401 : mode == "decode" ? 200 : 503,
                headers: mode == "badHint" ? ["Retry-After": "1, 2"] : [:], data: Data([0xff]))
            }
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport)
        let options = try NetworkCallOptions(acceptedStatuses: mode == "accepted503" ? HTTPStatusPolicy(codes: [503]) : .successful,
                                            retry: .oneRetryForSafeReads)
        do { _ = try await send(client, options: options); Issue.record("Expected failure") }
        catch { #expect(!(error is CancellationError)) }
        #expect(await transport.requests.count == 1)
        #expect(sink.events.first?.attemptCount == 1)
        if mode == "accepted503" || mode == "decode" { #expect(sink.events.first?.outcome == .decoding) }
    }

    @Test func secondFailureIsFinalAndClearsPreviousStatus() async throws {
        let clock = BudgetTestClock(), sink = RetrySink()
        let transport = RetryTransport { index, request in
            if index == 2 { throw URLError(.networkConnectionLost) }
            return retryResponse(request, status: 503)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2); clock.advance(0.25)
        await #expect(throws: NetworkError.transport(.init(URLError(.networkConnectionLost)))) { try await task.value }
        #expect(await transport.requests.count == 2)
        #expect(sink.events.first?.status == nil)
        #expect(sink.events.first?.attemptCount == 2)
    }

    @Test(arguments: [false, true]) func invalidReplayRejectedBeforeAuthOrTransport(raw: Bool) async throws {
        let sink = RetrySink(), provider = RetryProvider()
        let transport = RetryTransport { _, request in retryResponse(request, status: 200) }
        let client = try APIClient(configuration: .init(baseURL: base, authentication: .init(provider: provider), diagnostics: sink),
                                   transport: transport)
        let options = try NetworkCallOptions(retry: .oneRetryForSafeReads)
        for mode in ["POST", "body", "custom"] {
            await #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
                if raw {
                    var request = URLRequest(url: base)
                    request.httpMethod = mode == "POST" ? "POST" : mode == "custom" ? "CUSTOM" : "GET"
                    if mode == "body" { request.httpBody = Data() }
                    return try await client.send(request, response: .text, options: options)
                }
                return try await client.send(RetryCall(responseStrategy: .text, options: options,
                    method: mode == "POST" ? .post : mode == "custom" ? HTTPMethod("CUSTOM") : .get,
                    body: mode == "body" ? .data(Data()) : nil))
            }
        }
        #expect(await transport.requests.isEmpty)
        #expect(await provider.contexts.isEmpty)
        #expect(sink.events.allSatisfy { $0.attemptCount == 0 })
    }

    @Test(arguments: [false, true]) func interruptionDuringWaitPreventsRetry(shutdown: Bool) async throws {
        let clock = BudgetTestClock(), sink = RetrySink()
        let transport = RetryTransport { _, request in retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2)
        if shutdown { await client.shutdown() } else { task.cancel() }
        await #expect(throws: CancellationError.self) { try await task.value }
        clock.advance(100)
        #expect(await transport.requests.count == 1)
        #expect(clock.pending == 0)
        #expect(sink.events.first?.attemptCount == 1)
        #expect(sink.events.first?.outcome == .cancelled(shutdown ? .shutdown : .caller))
        if shutdown {
            await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await send(client, options: .default) }
            #expect(sink.events.last?.attemptCount == 0)
        }
    }

    @Test func originalDeadlineIncludesFirstAttemptAndWait() async throws {
        let clock = BudgetTestClock(), sink = RetrySink()
        let transport = RetryTransport { index, request in
            if index == 1 { clock.advance(5); return retryResponse(request, status: 503) }
            try await clock.sleep(until: clock.now().advanced(by: .seconds(100)))
            return retryResponse(request, status: 200)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(totalTimeout: 10, retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2); clock.advance(0.25)
        // Both the original watchdog and the second transport must be waiting.
        await clock.waitForSleepers(2); clock.advance(4.75)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(await transport.requests.count == 2)
        #expect(await transport.active == 0)
        #expect(clock.pending == 0)
    }

    @Test func insufficientBudgetPreservesCurrentFailure() async throws {
        let clock = BudgetTestClock()
        let transport = RetryTransport { _, request in clock.advance(0.9); return retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, retryTiming: timing)
        await #expect(throws: NetworkError.httpStatus(try HTTPStatus(503), headers: HTTPHeaders())) {
            try await send(client, options: NetworkCallOptions(totalTimeout: 1, retry: .oneRetryForSafeReads))
        }
        #expect(await transport.requests.count == 1)
    }
    @Test func remainingBudgetTracksAdmissionInsteadOfRetry() async throws {
        let clock = BudgetTestClock(), start = clock.now()
        let value = try await NetworkOperation<Int>.run(clock: clock, start: start, total: 10) { operation in
            clock.advance(4)
            #expect(abs(operation.remainingBudget() - 6) < 0.001)
            clock.advance(5)
            #expect(abs(operation.remainingBudget() - 1) < 0.001)
            return 1
        }
        #expect(value == 1)
    }

    @Test func concurrentCallsKeepIndependentRetryState() async throws {
        let clock = BudgetTestClock(), sink = RetrySink()
        let transport = RetryTransport { _, request in
            retryResponse(request, status: request.url?.path == "/read" ? 503 : 200)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let retry = Task { try await send(client, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2)
        let other = try await client.send(URLRequest(url: base.appendingPathComponent("other")), response: .text)
        #expect(other.value == "ok")
        clock.advance(0.25)
        await #expect(throws: NetworkError.httpStatus(try HTTPStatus(503), headers: HTTPHeaders())) { try await retry.value }
        #expect(await transport.requests.count == 3)
        #expect(sink.events.map(\.attemptCount).sorted() == [1, 2])
        #expect(Set(sink.events.map(\.requestID)).count == 2)
        #expect(clock.pending == 0)
    }

    @Test func accepted503IsReturnedWithoutRetry() async throws {
        let sink = RetrySink()
        let transport = RetryTransport { _, request in retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport)
        let result = try await send(client, options: NetworkCallOptions(acceptedStatuses: HTTPStatusPolicy(codes: [503]),
                                                                       retry: .oneRetryForSafeReads))
        #expect(result.value == "ok")
        #expect(await transport.requests.count == 1)
        #expect(sink.events.first?.attemptCount == 1)
    }

    @Test func deadlineDuringWaitPreventsSecondInvocation() async throws {
        let clock = BudgetTestClock(), sink = RetrySink()
        let transport = RetryTransport { _, request in retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(totalTimeout: 0.5, retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2); clock.advance(1)
        await #expect(throws: NetworkError.timeout(.totalBudget)) { try await task.value }
        #expect(await transport.requests.count == 1)
        #expect(sink.events.first?.attemptCount == 1)
        #expect(clock.pending == 0)
    }

    @Test func shutdownJoinsRetrySleeperCleanup() async throws {
        let started = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (started, release)), sink = RetrySink()
        let transport = RetryTransport { _, request in retryResponse(request, status: 503) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport,
                                   clock: clock, retryTiming: timing)
        let task = Task { try await send(client, options: NetworkCallOptions(retry: .oneRetryForSafeReads)) }
        await clock.waitForSleepers(2)
        let shutdown = Task { await client.shutdown() }
        await started.wait()
        #expect(sink.events.isEmpty) // Terminal event waits for joined child cleanup.
        #expect(await transport.requests.count == 1)
        await release.open()
        await shutdown.value
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(clock.pending == 0)
        #expect(sink.events.first?.attemptCount == 1)
    }

    @Test func budgetSpentAfterDelaySnapshotDoesNotEnterWait() async throws {
        let clock = RetryDecisionBudgetClock()
        let transport = RetryTransport { _, request in
            await clock.base.waitForSleepers(1) // Original watchdog is already registered.
            return retryResponse(request, status: 503)
        }
        let timing = RetryTiming(jitter: { clock.consumeAfterNextSnapshot(0.8); return 0.25 })
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, retryTiming: timing)
        await #expect(throws: NetworkError.httpStatus(try HTTPStatus(503), headers: HTTPHeaders())) {
            try await send(client, options: NetworkCallOptions(totalTimeout: 1, retry: .oneRetryForSafeReads))
        }
        #expect(clock.forbiddenSleeps == 0)
        #expect(await transport.requests.count == 1)
        #expect(clock.base.pending == 0)
    }

}
