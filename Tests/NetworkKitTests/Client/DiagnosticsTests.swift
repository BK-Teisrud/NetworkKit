import Foundation
import Testing
import os
@testable import NetworkKit

private let diagnosticCanary = "snk-private-canary"
private final class EventSink: NetworkDiagnosticSink {
    private let storage = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    let hook: @Sendable (NetworkDiagnosticEvent) -> Void
    init(hook: @escaping @Sendable (NetworkDiagnosticEvent) -> Void = { _ in }) { self.hook = hook }
    var events: [NetworkDiagnosticEvent] { storage.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) {
        storage.withLock { $0.append(event) }
        hook(event)
    }
}
private struct DiagnosticProvider: AuthenticationHeaderProvider {
    let work: @Sendable (AuthenticationContext) async throws -> HTTPHeaders
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders { try await work(context) }
}
private actor DiagnosticTransport: NetworkTransport {
    private(set) var requests: [URLRequest] = []
    let work: @Sendable (URLRequest) async throws -> TransportResponse
    init(_ work: @escaping @Sendable (URLRequest) async throws -> TransportResponse) { self.work = work }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request)
        return try await work(request)
    }
}
private func diagnosticResponse(_ request: URLRequest, status: Int = 200) -> TransportResponse {
    TransportResponse(data: Data(diagnosticCanary.utf8), response: HTTPURLResponse(url: request.url!,
        statusCode: status, httpVersion: nil, headerFields: ["Set-Cookie": diagnosticCanary])!)
}
private struct DiagnosticCall: Endpoint, CustomStringConvertible {
    typealias Response = String
    let path = try! EndpointPath(segments: [diagnosticCanary])
    let query = [try! HTTPQueryItem(name: "secret", value: diagnosticCanary)]
    var method = try! HTTPMethod("SNK-PRIVATE-CANARY-METHOD")
    var body: RequestBody? = .text(diagnosticCanary)
    var responseStrategy: ResponseStrategy<String> = .text
    var options: NetworkCallOptions = .default
    var description: String { diagnosticCanary }
}
private struct DiagnosticBadEncoder: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws {
        throw NSError(domain: diagnosticCanary, code: 1, userInfo: [NSLocalizedDescriptionKey: diagnosticCanary])
    }
}
private struct DiagnosticModel: Decodable, Sendable, CustomStringConvertible {
    let value: String
    var description: String { diagnosticCanary }
}

@Suite(.timeLimit(.minutes(1))) struct DiagnosticsTests {
    private let base = URL(string: "https://snk-private-canary.invalid")!
    private func assertSafe(_ events: [NetworkDiagnosticEvent], sourceLocation: SourceLocation = #_sourceLocation) {
        for event in events {
            let text = (String(describing: event) + String(reflecting: event)).lowercased()
            #expect(!text.contains(diagnosticCanary), sourceLocation: sourceLocation)
            #expect(!text.contains("https://"), sourceLocation: sourceLocation)
            #expect(Set(Mirror(reflecting: event).children.compactMap(\.label)) ==
                ["requestID", "method", "status", "duration", "attemptCount", "outcome"], sourceLocation: sourceLocation)
            #expect(event.duration.isFinite && event.duration >= 0, sourceLocation: sourceLocation)
        }
    }

    @Test(arguments: ["success", "model", "status", "transport", "systemCancelled", "decoding", "encoding", "provider", "nonHTTP", "invalidStatus", "invalid"])
    func canariesInEveryBoundaryStayOutOfEventsAndErrorDescriptions(mode: String) async throws {
        for raw in [false, true] {
            if raw && mode == "encoding" { continue } // Raw Data has no Encodable stage.
            let sink = EventSink(), identifier = OSAllocatedUnfairLock<UUID?>(initialState: nil)
            let provider = DiagnosticProvider { context in
                identifier.withLock { $0 = context.requestID }
                if mode == "provider" {
                    throw NSError(domain: diagnosticCanary, code: 1, userInfo: [NSLocalizedDescriptionKey: diagnosticCanary])
                }
                return try HTTPHeaders(["Authorization": diagnosticCanary])
            }
            let transport = DiagnosticTransport { request in
                if mode == "systemCancelled" { throw URLError(.cancelled) }
                if mode == "transport" {
                    throw NSError(domain: diagnosticCanary, code: -123,
                        userInfo: [NSLocalizedDescriptionKey: diagnosticCanary, NSURLErrorFailingURLErrorKey: request.url!])
                }
                if mode == "nonHTTP" {
                    return TransportResponse(data: Data(diagnosticCanary.utf8),
                        response: URLResponse(url: request.url!, mimeType: diagnosticCanary, expectedContentLength: 1, textEncodingName: nil))
                }
                if mode == "model" {
                    return TransportResponse(data: Data(("{\"value\":\"" + diagnosticCanary + "\"}").utf8),
                        response: diagnosticResponse(request).response)
                }
                return diagnosticResponse(request, status: mode == "status" ? 503 : mode == "invalidStatus" ? 600 : 200)
            }
            let configuration = NetworkConfiguration(baseURL: base,
                headers: try HTTPHeaders(["Cookie": diagnosticCanary, "X-Secret": diagnosticCanary]),
                authentication: NetworkAuthentication(provider: provider, account: diagnosticCanary, environment: diagnosticCanary),
                diagnostics: sink)
            let client = try APIClient(configuration: configuration, transport: transport)
            do {
                if mode == "decoding" || mode == "model" {
                    if raw { _ = try await client.send(URLRequest(url: base.appendingPathComponent(diagnosticCanary)), response: .json(DiagnosticModel.self)) }
                    else {
                        struct JSONCall: Endpoint {
                            typealias Response = DiagnosticModel
                            let path = try! EndpointPath(segments: [diagnosticCanary])
                            let responseStrategy = ResponseStrategy<DiagnosticModel>.json()
                        }
                        _ = try await client.send(JSONCall())
                    }
                } else {
                    var call = DiagnosticCall()
                    if mode == "encoding" { call.body = .json(DiagnosticBadEncoder()) }
                    if mode == "invalid" { call.options = try NetworkCallOptions(headers: HTTPHeaders(["Host": diagnosticCanary])) }
                    if raw {
                        var request: URLRequest
                        if mode == "invalid" {
                            request = URLRequest(url: base)
                            request.setValue(diagnosticCanary, forHTTPHeaderField: "Host")
                        } else { request = try call.request(configuration: configuration) }
                        _ = try await client.send(request, response: .text)
                    }
                    else { _ = try await client.send(call) }
                }
                #expect(mode == "success" || mode == "model")
            } catch {
                #expect(mode != "success" && mode != "model")
                for text in [String(describing: error), String(reflecting: error), error.localizedDescription] {
                    #expect(!text.lowercased().contains(diagnosticCanary))
                }
            }
            let event = try #require(sink.events.first)
            #expect(sink.events.count == 1)
            assertSafe(sink.events)
            if let id = identifier.withLock({ $0 }) { #expect(event.requestID == id) }
            switch mode {
            case "success": #expect(event.outcome == .success); #expect(event.status?.code == 200); #expect(event.method == .custom)
            case "model": #expect(event.outcome == .success); #expect(event.status?.code == 200)
            case "invalidStatus": #expect(event.outcome == .invalidResponse(.invalidStatusCode)); #expect(event.status == nil)
            case "status": #expect(event.outcome == .httpStatus); #expect(event.status?.code == 503)
            case "transport", "systemCancelled": #expect(event.outcome == .transport); #expect(event.status == nil)
            case "decoding": #expect(event.outcome == .decoding); #expect(event.status?.code == 200)
            case "encoding": #expect(event.outcome == .encoding); #expect(event.method == nil)
            case "provider": #expect(event.outcome == .invalidRequest(.authenticationProviderFailure))
            case "nonHTTP": #expect(event.outcome == .invalidResponse(.nonHTTPResponse)); #expect(event.status == nil)
            default: #expect(event.outcome == .invalidRequest(.unsupportedRequest)); #expect(event.method == nil)
            }
            await client.shutdown()
        }
    }

    @Test(arguments: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "get", "SNK-PRIVATE-CANARY", "TRACE"])
    func onlyExactAllowlistedMethodNamesAreRetained(method: String) async throws {
        let sink = EventSink(), transport = DiagnosticTransport { diagnosticResponse($0) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink), transport: transport)
        var request = URLRequest(url: base); request.httpMethod = method
        // Foundation may canonicalize familiar spelling; classification follows the prepared method.
        _ = try await client.send(request, response: .data)
        let prepared = try #require(await transport.requests.first)
        let expected = ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"].contains(prepared.httpMethod!)
            ? prepared.httpMethod! : "custom"
        #expect(sink.events.first?.method?.rawValue == expected)
        assertSafe(sink.events)
        await client.shutdown()
    }

    @Test(arguments: ["success", "status", "transport"])
    func enablingAndDisablingPreservesResultsAndRequests(mode: String) async throws {
        let sink = EventSink()
        var results: [Result<Data, NetworkError>] = []
        var requests: [URLRequest] = []
        for enabled in [false, true] {
            let transport = DiagnosticTransport { request in
                if mode == "transport" { throw URLError(.notConnectedToInternet) }
                return diagnosticResponse(request, status: mode == "status" ? 401 : 200)
            }
            let configuration = NetworkConfiguration(baseURL: base, diagnostics: enabled ? sink : nil)
            #expect((configuration.diagnostics == nil) == !enabled)
            let client = try APIClient(configuration: configuration, transport: transport)
            do { results.append(.success(try await client.send(URLRequest(url: base), response: .data).value)) }
            catch let error as NetworkError { results.append(.failure(error)) }
            requests += await transport.requests
            await client.shutdown()
        }
        #expect(results.count == 2 && results[0] == results[1])
        #expect(requests.count == 2 && requests[0] == requests[1])
        #expect(sink.events.count == 1)
        #expect(NetworkConfiguration(baseURL: base).diagnostics == nil)
    }

    @Test func loggingDoesNotReadEndpointPropertiesOrDescriptionsAgain() async throws {
        let counts = OSAllocatedUnfairLock(initialState: [String: Int]())
        struct Call: Endpoint, CustomStringConvertible {
            typealias Response = EmptyResponse
            let counts: OSAllocatedUnfairLock<[String: Int]>
            func read(_ key: String) { counts.withLock { $0[key, default: 0] += 1 } }
            var path: EndpointPath { read("path"); return try! EndpointPath(segments: []) }
            var query: [HTTPQueryItem] { read("query"); return [] }
            var method: HTTPMethod { read("method"); return .get }
            var body: RequestBody? { read("body"); return nil }
            var options: NetworkCallOptions { read("options"); return .default }
            var responseStrategy: ResponseStrategy<EmptyResponse> { read("response"); return .empty }
            var description: String { read("description"); return diagnosticCanary }
        }
        for sink: EventSink? in [nil, EventSink()] {
            let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink),
                transport: DiagnosticTransport { diagnosticResponse($0) })
            _ = try await client.send(Call(counts: counts))
            await client.shutdown()
        }
        #expect(counts.withLock { $0 } == ["path": 2, "query": 2, "method": 2, "body": 2, "options": 2, "response": 2])
    }

    @Test func rejectedAdmissionAndPreCancellationEmitOneSafeEvent() async throws {
        let sink = EventSink(), transport = DiagnosticTransport { diagnosticResponse($0) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink), transport: transport)
        let gate = BudgetLatch()
        let task = Task { await gate.wait(); return try await client.send(DiagnosticCall()) }
        task.cancel(); await gate.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(sink.events.first?.outcome == .cancelled(.caller)) // Pre-cancelled before the operation binds.
        await client.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(DiagnosticCall()) }
        #expect(sink.events.count == 2)
        #expect(sink.events.last?.outcome == .invalidRequest(.clientClosed))
        #expect(sink.events.allSatisfy { $0.method == nil && $0.status == nil })
        #expect(await transport.requests.isEmpty)
        assertSafe(sink.events)
    }

    @Test func eventWaitsForJoinedCleanupAndIncludesItsDuration() async throws {
        let cleanup = BudgetLatch(), cleanupRelease = BudgetLatch(), transportRelease = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (cleanup, cleanupRelease)), sink = EventSink()
        let transport = DiagnosticTransport { request in await transportRelease.wait(); return diagnosticResponse(request) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink), transport: transport, clock: clock)
        let task = Task { try await client.send(URLRequest(url: base), response: .data) }
        await clock.waitForSleepers(1)
        clock.advance(2); await transportRelease.open(); await cleanup.wait()
        #expect(sink.events.isEmpty)
        clock.advance(7); await cleanupRelease.open()
        _ = try await task.value
        #expect(sink.events.count == 1 && sink.events.first?.duration == 9)
        #expect(sink.events.first?.outcome == .success)
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test func sinkLatencyCannotRewriteSelectedResultOrMeasuredDuration() async throws {
        let clock = BudgetTestClock()
        let sink = EventSink { _ in clock.advance(120) }
        let transport = DiagnosticTransport { request in clock.advance(2); return diagnosticResponse(request) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink), transport: transport, clock: clock)
        _ = try await client.send(URLRequest(url: base), response: .data)
        #expect(sink.events.first?.outcome == .success)
        #expect(sink.events.first?.duration == 2)
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test(arguments: ["caller", "shutdown", "provider"])
    func cancellationCategoriesFollowTheSelectedCause(mode: String) async throws {
        let sink = EventSink(), clock = BudgetTestClock()
        let provider = DiagnosticProvider { _ in throw CancellationError() }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            authentication: mode == "provider" ? NetworkAuthentication(provider: provider) : nil, diagnostics: sink),
            transport: BudgetTransport(clock: clock), clock: clock)
        let task = Task { try await client.send(URLRequest(url: base), response: .data) }
        var closing: Task<Void, Never>?
        if mode != "provider" {
            await clock.waitForSleepers(2)
            if mode == "shutdown" { closing = Task { await client.shutdown() } }
            else { task.cancel() }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        await closing?.value
        let cause: NetworkDiagnosticEvent.CancellationCause = mode == "provider" ? .unspecified : mode == "caller" ? .caller : .shutdown
        #expect(sink.events.count == 1 && sink.events.first?.outcome == .cancelled(cause))
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test(arguments: [false, true]) func firstCancellationCauseSurvivesTheLaterCause(shutdownFirst: Bool) async throws {
        let cleanup = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (cleanup, release)), sink = EventSink()
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink),
            transport: BudgetTransport(clock: clock), clock: clock)
        let task = Task { try await client.send(URLRequest(url: base), response: .data) }
        await clock.waitForSleepers(2)
        var closing: Task<Void, Never>?
        if shutdownFirst { closing = Task { await client.shutdown() } } else { task.cancel() }
        await cleanup.wait()
        if shutdownFirst { task.cancel() } else { closing = Task { await client.shutdown() } }
        #expect(sink.events.isEmpty)
        await release.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        await closing?.value
        #expect(sink.events.first?.outcome == .cancelled(shutdownFirst ? .shutdown : .caller))
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func selectedCompletionSurvivesLateCancellation(failure: Bool) async throws {
        let cleanup = BudgetLatch(), release = BudgetLatch(), workRelease = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (cleanup, release)), sink = EventSink()
        let transport = DiagnosticTransport { request in
            await workRelease.wait()
            if failure { throw NetworkError.decoding }
            return diagnosticResponse(request)
        }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, diagnostics: sink), transport: transport, clock: clock)
        let task = Task { try await client.send(URLRequest(url: base), response: .data) }
        await clock.waitForSleepers(1); await workRelease.open(); await cleanup.wait()
        task.cancel(); await release.open()
        if failure { await #expect(throws: NetworkError.decoding) { try await task.value } }
        else { _ = try await task.value }
        #expect(sink.events.first?.outcome == (failure ? .decoding : .success))
        #expect(sink.events.count == 1 && clock.pending == 0)
        await client.shutdown()
    }

    @Test(arguments: ["total", "system", "provider"])
    func timeoutsRemainCategorizedWithoutPendingDiagnosticsWork(mode: String) async throws {
        let clock = BudgetTestClock(), sink = EventSink()
        let provider = DiagnosticProvider { _ in throw NetworkError.timeout(.inactivity) }
        let transport: any NetworkTransport = mode == "total" ? BudgetTransport(clock: clock)
            : DiagnosticTransport { _ in throw URLError(.timedOut) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            authentication: mode == "provider" ? NetworkAuthentication(provider: provider) : nil,
            diagnostics: sink), transport: transport, clock: clock)
        let task = Task { try await client.send(URLRequest(url: base), response: .data) }
        if mode == "total" { await clock.waitForSleepers(2); clock.advance(60) }
        let reason: NetworkError.TimeoutReason = mode == "total" ? .totalBudget : mode == "system" ? .system : .inactivity
        await #expect(throws: NetworkError.timeout(reason)) { try await task.value }
        #expect(sink.events.first?.outcome == .timeout(reason))
        #expect(sink.events.count == 1 && sink.events.first?.duration == (mode == "total" ? 60 : 0))
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test func concurrentAccountsProduceOnlyIndependentSanitizedTerminalEvents() async throws {
        let ids = OSAllocatedUnfairLock(initialState: [UUID]()), arrived = BudgetLatch(), sink = EventSink()
        let provider = DiagnosticProvider { context in
            let ready = ids.withLock { $0.append(context.requestID); return $0.count == 32 }
            if ready { await arrived.open() }; await arrived.wait()
            return try HTTPHeaders(["Authorization": diagnosticCanary + (context.account ?? "")])
        }
        let transport = DiagnosticTransport { diagnosticResponse($0) }
        let clients = try ["A", "B"].map { (account: String) in
            try APIClient(configuration: NetworkConfiguration(baseURL: base,
                authentication: NetworkAuthentication(provider: provider, account: diagnosticCanary + account), diagnostics: sink), transport: transport)
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<32 { group.addTask { _ = try await clients[index % 2].send(DiagnosticCall()) } }
            try await group.waitForAll()
        }
        #expect(sink.events.count == 32)
        #expect(Set(sink.events.map(\.requestID)).count == 32)
        #expect(Set(sink.events.map(\.requestID)) == Set(ids.withLock { $0 }))
        #expect(sink.events.allSatisfy { $0.outcome == .success && $0.method == .custom && $0.status?.code == 200 })
        assertSafe(sink.events)
        for client in clients { await client.shutdown() }
    }

    @Test func unknownErrorsAreClassifiedWithoutFormattingThem() {
        let reads = OSAllocatedUnfairLock(initialState: 0)
        struct PrivateError: Error, LocalizedError, CustomStringConvertible {
            let reads: OSAllocatedUnfairLock<Int>
            var description: String { reads.withLock { $0 += 1 }; return diagnosticCanary }
            var errorDescription: String? { reads.withLock { $0 += 1 }; return diagnosticCanary }
        }
        let clock = BudgetTestClock(), sink = EventSink()
        let observation = DiagnosticObservation(sink: sink, clock: clock, start: clock.now())
        observation.complete(error: PrivateError(reads: reads))
        #expect(sink.events.first?.outcome == .other)
        #expect(reads.withLock { $0 } == 0)
        assertSafe(sink.events)
    }
}
