import Foundation
import Testing
@testable import NetworkKit

private struct LifecycleCall: Endpoint {
    typealias Response = EmptyResponse
    let path = try! EndpointPath(segments: [])
    var options: NetworkCallOptions = .default
}
private actor LifecycleTransport: NetworkTransport {
    let work: BudgetTransport
    let closeStarted = BudgetLatch()
    let closeRelease: BudgetLatch?
    private(set) var closes = 0
    init(clock: BudgetTestClock, closeRelease: BudgetLatch? = nil) {
        work = BudgetTransport(clock: clock)
        self.closeRelease = closeRelease
    }
    func send(_ request: URLRequest) async throws -> TransportResponse { try await work.send(request) }
    func shutdown() async {
        closes += 1
        await closeStarted.open()
        if let closeRelease { await closeRelease.wait() }
    }
}
private actor LifecycleImmediateTransport: NetworkTransport {
    let mode: String
    private(set) var requests = 0
    private(set) var closes = 0
    init(mode: String = "success") { self.mode = mode }
    func send(_ request: URLRequest) throws -> TransportResponse {
        requests += 1
        if mode == "transport" { throw URLError(.notConnectedToInternet) }
        let status = mode == "HTTP" ? 503 : 200
        return TransportResponse(data: Data("bad JSON".utf8), response: HTTPURLResponse(url: request.url!,
            statusCode: status, httpVersion: nil, headerFields: [:])!)
    }
    func shutdown() { closes += 1 }
}
private struct LifecyclePayload: Codable, Sendable, Equatable { let requestNumber: Int }
private struct LifecyclePOST: Endpoint {
    let path: EndpointPath
    let method = HTTPMethod.post
    let body: RequestBody?
    let options: NetworkCallOptions
    let responseStrategy: ResponseStrategy<LifecyclePayload>
}
private actor LifecycleEchoTransport: NetworkTransport {
    let target: Int
    private let allArrived = BudgetLatch()
    private(set) var requests: [URLRequest] = []
    private(set) var active = 0
    private(set) var maximum = 0
    private(set) var closes = 0
    init(target: Int) { self.target = target }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request); active += 1; maximum = max(maximum, active)
        defer { active -= 1 }
        if requests.count == target { await allArrived.open() }
        await allArrived.wait()
        return TransportResponse(data: request.httpBody!, response: HTTPURLResponse(url: request.url!, statusCode: 201,
            httpVersion: nil, headerFields: ["X-ID": request.value(forHTTPHeaderField: "X-ID")!])!)
    }
    func shutdown() { closes += 1 }
}
private struct LifecycleFailingEncoder: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws { throw NetworkError.encoding }
}

@Suite(.timeLimit(.minutes(1))) struct ClientLifecycleTests {
    private let base = URL(string: "https://example.invalid")!

    @Test func shutdownWithoutActiveWorkIsIdempotent() async throws {
        let transport = LifecycleImmediateTransport()
        let client: any NetworkClient = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        await client.shutdown()
        await client.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(LifecycleCall()) }
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.send(URLRequest(url: base), response: .empty)
        }
        #expect(await transport.closes == 1)
        #expect(await transport.requests == 0)
    }

    @Test func closingRejectsBothInputsBeforeReadingOptionsAndJoinsCleanup() async throws {
        struct ForbiddenOptions: Endpoint {
            typealias Response = EmptyResponse
            let path = try! EndpointPath(segments: [])
            var options: NetworkCallOptions { Issue.record("Closed client read app options"); return .default }
        }
        let started = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (started, release))
        let transport = LifecycleTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let work = Task { try await client.send(LifecycleCall()) }
        await clock.waitForSleepers(2)
        let shutdown = Task { await client.shutdown() }
        await started.wait()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(ForbiddenOptions()) }
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.send(URLRequest(url: base), response: .empty)
        }
        #expect(await transport.closes == 0)
        #expect(await transport.work.active == 1)
        await release.open()
        await shutdown.value
        await #expect(throws: CancellationError.self) { try await work.value }
        #expect(await transport.work.active == 0)
        #expect(await transport.closes == 1)
        #expect(clock.pending == 0)
    }

    @Test(arguments: ["leader", "follower", "both", "preCancelled"])
    func concurrentShutdownRetainsCleanupOwnership(cancellation: String) async throws {
        let started = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(cleanup: (started, release))
        let transport = LifecycleTransport(clock: clock)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let work = Task { try await client.send(LifecycleCall()) }
        await clock.waitForSleepers(2)
        let leader = Task {
            if cancellation == "preCancelled" { withUnsafeCurrentTask { $0?.cancel() } }
            await client.shutdown()
        }
        await started.wait()
        let followers = (0..<10).map { _ in Task { await client.shutdown() } }
        if cancellation == "leader" || cancellation == "both" { leader.cancel() }
        if cancellation == "follower" || cancellation == "both" { followers[0].cancel() }
        #expect(await transport.closes == 0)
        await release.open()
        await leader.value
        for follower in followers { await follower.value }
        await #expect(throws: CancellationError.self) { try await work.value }
        #expect(await transport.closes == 1)
        #expect(await transport.work.active == 0)
        #expect(clock.pending == 0)
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(LifecycleCall()) }
    }

    @Test func shutdownWaitsForTransportFinalization() async throws {
        let clock = BudgetTestClock(), closeRelease = BudgetLatch(), returned = BudgetLatch()
        let transport = LifecycleTransport(clock: clock, closeRelease: closeRelease)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let leader = Task { await client.shutdown(); await returned.open() }
        await transport.closeStarted.wait()
        leader.cancel()
        #expect(await returned.isOpen == false)
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(LifecycleCall()) }
        let follower = Task { await client.shutdown() }
        follower.cancel()
        await closeRelease.open()
        await leader.value
        await follower.value
        #expect(await returned.isOpen)
        #expect(await transport.closes == 1)
    }

    @Test func admissionRemembersShutdownBeforeOperationBinding() async throws {
        let lifecycle = ClientLifecycle(), clock = BudgetTestClock()
        let registration = try lifecycle.register()
        let admitted = try #require(lifecycle.beginShutdown())
        for operation in admitted { operation.cancel() }
        #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try lifecycle.register() }
        await #expect(throws: CancellationError.self) {
            try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: 60,
                                                registration: registration) { _ in
                Issue.record("Shutdown admission reached app work")
                return 1
            }
        }
        lifecycle.finish(registration)
        await lifecycle.waitUntilDrained()
        lifecycle.completeShutdown()
        await lifecycle.waitUntilClosed()
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func firstTimeoutOrShutdownCauseIsPreserved(timeoutFirst: Bool) async throws {
        let started = BudgetLatch(), release = BudgetLatch(), registration = ClientOperationRegistration()
        let clock = BudgetTestClock(cleanup: (started, release))
        let work = Task {
            try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: 5,
                                                registration: registration) { _ in
                try await clock.sleep(until: clock.now().advanced(by: .seconds(7200)))
                return 1
            }
        }
        await clock.waitForSleepers(2)
        if timeoutFirst { clock.advance(5) } else { registration.cancel() }
        await started.wait()
        if timeoutFirst { registration.cancel() } else { clock.advance(5) }
        await release.open()
        if timeoutFirst { await #expect(throws: NetworkError.timeout(.totalBudget)) { try await work.value } }
        else { await #expect(throws: CancellationError.self) { try await work.value } }
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func selectedCompletionSurvivesShutdown(failure: Bool) async throws {
        let started = BudgetLatch(), release = BudgetLatch(), complete = BudgetLatch()
        let registration = ClientOperationRegistration(), clock = BudgetTestClock(cleanup: (started, release))
        let work = Task {
            try await NetworkOperation<Int>.run(clock: clock, start: clock.now(), total: 60,
                                                registration: registration) { _ in
                await complete.wait()
                if failure { throw NetworkError.decoding }
                return 42
            }
        }
        await clock.waitForSleepers(1)
        await complete.open()
        await started.wait()
        registration.cancel()
        await release.open()
        if failure { await #expect(throws: NetworkError.decoding) { try await work.value } }
        else { #expect(try await work.value == 42) }
        #expect(clock.pending == 0)
    }

    @Test func concurrentClientCallsKeepSnapshotsAndCodecsIndependent() async throws {
        let count = 64, clock = BudgetTestClock()
        let transport = LifecycleEchoTransport(target: count)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            headers: HTTPHeaders(["X-Default": "client", "X-ID": "overridden"])), transport: transport, clock: clock)
        let ids = try await withThrowingTaskGroup(of: Int.self) { group in
            for id in 0..<count {
                group.addTask {
                    let snake = id % 2 == 0
                    let call = LifecyclePOST(path: try EndpointPath(segments: [String(id)]),
                        body: .json(LifecyclePayload(requestNumber: id), options: JSONEncodingOptions(
                            keyStrategy: snake ? .convertToSnakeCase : .useDefaultKeys)),
                        options: try NetworkCallOptions(headers: HTTPHeaders(["X-ID": String(id)]),
                                                       inactivityTimeout: Double(id + 1)),
                        responseStrategy: .json(options: JSONDecodingOptions(
                            keyStrategy: snake ? .convertFromSnakeCase : .useDefaultKeys)))
                    let response = try await client.send(call)
                    #expect(response.value.requestNumber == id)
                    #expect(response.headers["x-id"] == String(id))
                    return response.value.requestNumber
                }
            }
            var ids = Set<Int>()
            for try await id in group { ids.insert(id) }
            return ids
        }
        #expect(ids == Set(0..<count))
        #expect(await transport.maximum == count)
        let requests = await transport.requests
        #expect(requests.count == count)
        for request in requests {
            let id = try #require(Int(request.value(forHTTPHeaderField: "X-ID")!))
            #expect(request.value(forHTTPHeaderField: "X-Default") == "client")
            #expect(request.timeoutInterval == Double(id + 1))
            #expect(request.url?.lastPathComponent == String(id))
        }
        await client.shutdown()
        #expect(await transport.closes == 1)
        #expect(await transport.active == 0)
        #expect(clock.pending == 0)
    }

    @Test(arguments: ["transport", "HTTP", "decoding", "invalidRequest", "preCancelled", "encoding"])
    func failedCallsReleaseAdmissionBeforeShutdown(mode: String) async throws {
        struct FailingCall: Endpoint {
            let path = try! EndpointPath(segments: [])
            let method = HTTPMethod.post
            let body: RequestBody? = .json(LifecycleFailingEncoder())
            let responseStrategy = ResponseStrategy<EmptyResponse>.empty
        }
        struct Model: Decodable, Sendable { let name: String }
        let transport = LifecycleImmediateTransport(mode: mode), clock = BudgetTestClock()
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        if mode == "preCancelled" {
            let work = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await client.send(LifecycleCall())
            }
            await #expect(throws: CancellationError.self) { try await work.value }
        } else if mode == "invalidRequest" {
            let options = try NetworkCallOptions(headers: HTTPHeaders(["Host": "blocked"]))
            await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
                try await client.send(LifecycleCall(options: options))
            }
        } else if mode == "encoding" {
            await #expect(throws: NetworkError.encoding) { try await client.send(FailingCall()) }
        } else {
            let expected: NetworkError = mode == "transport" ? .transport(.init(URLError(.notConnectedToInternet))) :
                (mode == "HTTP" ? .httpStatus(try HTTPStatus(503), headers: HTTPHeaders()) : .decoding)
            await #expect(throws: expected) {
                try await client.send(URLRequest(url: base), response: .json(Model.self))
            }
        }
        await client.shutdown()
        #expect(await transport.closes == 1)
        #expect(clock.pending == 0)
    }
    @Test func ownedSessionIsClosedAfterItsOperationsJoin() async throws {
        let started = BudgetLatch(), stopped = BudgetLatch(), clock = BudgetTestClock()
        let hold = SessionStubProtocol.install(.init(data: Data(), status: 204, headers: [:], hold: true,
            onStart: { Task { await started.open() } }, onStop: { Task { await stopped.open() } }))
        defer { SessionStubProtocol.remove(hold) }
        let settings = URLSessionTransport.configuration()
        #if os(watchOS)
        let operation: URLSessionTransport.DataOperation = { _, request, _ in
            await started.open()
            do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
            catch { await stopped.open(); throw error }
            return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 204,
                                                                            httpVersion: nil, headerFields: [:])!)
        }
        #else
        settings.protocolClasses = [SessionStubProtocol.self]
        let operation = URLSessionTransport.systemDataOperation
        #endif
        let transport = try URLSessionTransport(ownedConfiguration: settings, dataOperation: operation, baseURL: base)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport, clock: clock)
        let work = Task { try await client.send(URLRequest(url: hold), response: .empty) }
        defer { work.cancel() }
        await started.wait()
        await client.shutdown()
        await #expect(throws: CancellationError.self) { try await work.value }
        await stopped.wait()
        #expect(await transport.ownsSession)
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await transport.send(URLRequest(url: hold))
        }
        await client.shutdown()
        #expect(clock.pending == 0)
    }

    @Test func borrowedSessionKeepsAnotherClientsActiveWorkAlive() async throws {
        let started = BudgetLatch(), stopped = BudgetLatch(), otherStarted = BudgetLatch()
        let otherRelease = BudgetLatch(), gate = SessionResponseGate(), clock = BudgetTestClock()
        let hold = SessionStubProtocol.install(.init(data: Data(), status: 204, headers: [:], hold: true,
            onStart: { Task { await started.open() } }, onStop: { Task { await stopped.open() } }))
        let other = SessionStubProtocol.install(.init(data: Data("other".utf8), status: 200, headers: [:],
            onStart: { Task { await otherStarted.open() } }, gate: gate))
        let independent = SessionStubProtocol.install(.init(data: Data("independent".utf8), status: 200, headers: [:]))
        defer { for url in [hold, other, independent] { SessionStubProtocol.remove(url) } }
        let settings = URLSessionTransport.configuration()
        #if os(watchOS)
        let operation: URLSessionTransport.DataOperation = { _, request, _ in
            if request.url == hold {
                await started.open()
                do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
                catch { await stopped.open(); throw error }
            } else if request.url == other {
                await otherStarted.open()
                await otherRelease.wait()
            }
            let data = Data((request.url == other ? "other" : "independent").utf8)
            return TransportResponse(data: data, response: HTTPURLResponse(url: request.url!, statusCode: 200,
                                                                          httpVersion: nil, headerFields: [:])!)
        }
        #else
        settings.protocolClasses = [SessionStubProtocol.self]
        let operation = URLSessionTransport.systemDataOperation
        #endif
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        let firstTransport = try URLSessionTransport(session: session, dataOperation: operation, baseURL: base)
        let secondTransport = try URLSessionTransport(session: session, dataOperation: operation, baseURL: base)
        let first = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: firstTransport, clock: clock)
        let second = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: secondTransport, clock: clock)
        let firstWork = Task { try await first.send(URLRequest(url: hold), response: .empty) }
        let secondWork = Task { try await second.send(URLRequest(url: other), response: .text) }
        defer { firstWork.cancel(); secondWork.cancel() }
        await started.wait()
        await otherStarted.wait()
        await first.shutdown()
        await #expect(throws: CancellationError.self) { try await firstWork.value }
        await stopped.wait()
        gate.open()
        await otherRelease.open()
        #expect(try await secondWork.value.value == "other")
        await second.shutdown()
        #expect(await firstTransport.ownsSession == false)
        #expect(await secondTransport.ownsSession == false)
        #if os(watchOS)
        #expect(try await secondTransport.send(URLRequest(url: independent)).data == Data("independent".utf8))
        #else
        let (data, _) = try await session.data(for: URLRequest(url: independent))
        #expect(data == Data("independent".utf8))
        #endif
        #expect(clock.pending == 0)
    }

}
