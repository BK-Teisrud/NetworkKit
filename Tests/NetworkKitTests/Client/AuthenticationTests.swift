import Foundation
import Testing
import os
@testable import NetworkKit

private actor AuthProvider: AuthenticationHeaderProvider {
    private(set) var contexts: [AuthenticationContext] = []
    private(set) var active = 0
    let work: @Sendable (AuthenticationContext) async throws -> HTTPHeaders
    init(_ work: @escaping @Sendable (AuthenticationContext) async throws -> HTTPHeaders) { self.work = work }
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        contexts.append(context); active += 1
        defer { active -= 1 }
        return try await work(context)
    }
}
private actor AuthTransport: NetworkTransport {
    private(set) var requests: [URLRequest] = []
    let status: Int
    init(status: Int = 204) { self.status = status }
    func send(_ request: URLRequest) -> TransportResponse {
        requests.append(request)
        return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: [:])!)
    }
}
private struct AuthCall: Endpoint {
    typealias Response = EmptyResponse
    let path = try! EndpointPath(segments: ["private"])
    let method = HTTPMethod.post
    let body: RequestBody? = .text("private-body")
    let query = [try! HTTPQueryItem(name: "private-query", value: "secret")]
    var options: NetworkCallOptions = .default
}
private struct AuthFailure: Error, CustomStringConvertible {
    var description: String { "PRIVATE-PROVIDER-ERROR" }
}

@Suite(.timeLimit(.minutes(1))) struct AuthenticationTests {
    private let base = URL(string: "https://example.invalid")!
    private func configuration(_ provider: AuthProvider, headers: HTTPHeaders = HTTPHeaders(),
                               base: URL? = nil, security: NetworkSecurityPolicy = .default) -> NetworkConfiguration {
        NetworkConfiguration(baseURL: base ?? self.base, headers: headers, security: security,
            authentication: NetworkAuthentication(provider: provider, account: "account-A", environment: "production"))
    }

    @Test(arguments: [false, true]) func bothInputsReceiveMinimalContextAndHeaders(typed: Bool) async throws {
        let provider = AuthProvider { _ in try HTTPHeaders(["Authorization": "Bearer A", "X-API-Key": "private-key"]) }
        let transport = AuthTransport(), clock = BudgetTestClock()
        let client = try APIClient(configuration: configuration(provider), transport: transport, clock: clock)
        if typed { _ = try await client.send(AuthCall()) }
        else {
            var request = URLRequest(url: base.appendingPathComponent("private?secret")); request.httpMethod = "POST"
            request.httpBody = Data("private-body".utf8)
            _ = try await client.send(request, response: .empty)
        }
        let contexts = await provider.contexts
        #expect(contexts.count == 1)
        #expect(contexts.first?.origin == (try NetworkOrigin(base)))
        #expect(contexts.first?.method == .post)
        #expect(contexts.first?.account == "account-A")
        #expect(contexts.first?.environment == "production")
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.first?.value(forHTTPHeaderField: "authorization") == "Bearer A")
        #expect(requests.first?.value(forHTTPHeaderField: "x-api-key") == "private-key")
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test(arguments: ["default", "raw", "options", "identical", "unicode"])
    func credentialConflictsAreNeverSilentlyOverwritten(source: String) async throws {
        let supplied = source == "unicode" ? "e\u{301}" : "Bearer provider"
        let explicit = source == "identical" ? supplied : source == "unicode" ? "\u{e9}" : "Bearer explicit"
        let provider = AuthProvider { _ in try HTTPHeaders(["AUTHORIZATION": supplied]) }
        let defaults = source == "default" ? try HTTPHeaders(["Authorization": explicit]) : HTTPHeaders()
        let transport = AuthTransport()
        let client = try APIClient(configuration: configuration(provider, headers: defaults), transport: transport)
        var request = URLRequest(url: base)
        if source != "default" && source != "options" { request.setValue(explicit, forHTTPHeaderField: "authorization") }
        let options = try NetworkCallOptions(headers: source == "options" ? HTTPHeaders(["Authorization": explicit]) : HTTPHeaders())
        if source == "identical" { _ = try await client.send(request, response: .empty, options: options) }
        else {
            await #expect(throws: NetworkError.invalidRequest(.conflictingHeaders)) {
                try await client.send(request, response: .empty, options: options)
            }
        }
        #expect(await provider.contexts.count == 1)
        #expect(await transport.requests.count == (source == "identical" ? 1 : 0))
        await client.shutdown()
    }

    @Test(arguments: ["name", "value", "host", "content-length", "transfer-encoding"])
    func providerFieldsCannotBypassValidation(kind: String) async throws {
        let provider = AuthProvider { _ in
            switch kind {
            case "name": try HTTPHeaders(["bad name": "value"])
            case "value": try HTTPHeaders(["Authorization": "secret\r\nInjected: yes"])
            default: try HTTPHeaders([kind: "1"])
            }
        }
        let transport = AuthTransport()
        let client = try APIClient(configuration: configuration(provider), transport: transport)
        let expected = NetworkError.invalidRequest(kind == "name" || kind == "value" ? .authenticationProviderFailure : .unsupportedRequest)
        await #expect(throws: expected) { try await client.send(AuthCall()) }
        #expect(await transport.requests.isEmpty)
        await client.shutdown()
    }

    @Test(arguments: [false, true]) func httpNeverInvokesProvider(typed: Bool) async throws {
        let provider = AuthProvider { _ in try HTTPHeaders(["Authorization": "secret"]) }
        let transport = AuthTransport()
        let local = URL(string: "http://localhost:8080")!
        let client = try APIClient(configuration: configuration(provider, base: local,
            security: NetworkSecurityPolicy(allowInsecureLoopback: true)), transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.credentialsOverHTTP)) {
            if typed { _ = try await client.send(AuthCall()) }
            else { _ = try await client.send(URLRequest(url: local), response: .empty) }
        }
        #expect(await provider.contexts.isEmpty)
        #expect(await transport.requests.isEmpty)
        _ = try await client.send(URLRequest(url: local), response: .empty,
                                  options: NetworkCallOptions(authentication: .disabled))
        #expect(await transport.requests.count == 1)
        await #expect(throws: NetworkError.invalidRequest(.credentialsOverHTTP)) {
            try await client.send(URLRequest(url: local), response: .empty, options: NetworkCallOptions(
                headers: HTTPHeaders(["Authorization": "explicit-secret"]), authentication: .disabled))
        }
        #expect(await transport.requests.count == 1)
        await client.shutdown()
    }

    @Test(arguments: ["https://other.invalid", "https://example.invalid:444", "http://localhost:8080"])
    func additionalOriginsNeverInheritProviderOrDefaults(destination: String) async throws {
        let other = URL(string: destination)!
        let provider = AuthProvider { _ in try HTTPHeaders(["X-Private-Provider": "secret"]) }
        let transport = AuthTransport()
        let defaults = try HTTPHeaders(["Authorization": "secret-default", "X-Account": "private-account"])
        let policy = NetworkSecurityPolicy(allowInsecureLoopback: true, additionalRawOrigins: [try NetworkOrigin(other)])
        let client = try APIClient(configuration: configuration(provider, headers: defaults, security: policy), transport: transport)
        _ = try await client.send(URLRequest(url: other), response: .empty)
        #expect(await provider.contexts.isEmpty)
        let request = try #require(await transport.requests.first)
        #expect(request.allHTTPHeaderFields?.isEmpty != false)
        await client.shutdown()
    }

    @Test func optOutSkipsOnlyProviderAndRetainsExplicitPrecedence() async throws {
        let provider = AuthProvider { _ in throw AuthFailure() }
        let transport = AuthTransport()
        let client = try APIClient(configuration: configuration(provider, headers: HTTPHeaders(["Authorization": "default", "X-Ordinary": "default"])), transport: transport)
        var request = URLRequest(url: base); request.setValue("raw", forHTTPHeaderField: "Authorization")
        _ = try await client.send(request, response: .empty, options: NetworkCallOptions(
            headers: HTTPHeaders(["Authorization": "call"]), authentication: .disabled))
        #expect(await provider.contexts.isEmpty)
        let sent = try #require(await transport.requests.first)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "call")
        #expect(sent.value(forHTTPHeaderField: "X-Ordinary") == "default")
        await client.shutdown()
    }

    @Test(arguments: ["arbitrary", "structured", "cancel", "timeout"])
    func providerFailuresAreSafeAndNeverReachTransport(kind: String) async throws {
        let provider = AuthProvider { _ in
            switch kind {
            case "cancel": throw CancellationError()
            case "timeout": throw NetworkError.timeout(.inactivity)
            case "structured": throw NetworkError.httpStatus(try HTTPStatus(401), headers: try HTTPHeaders(["secret": "PRIVATE"]))
            default: throw AuthFailure()
            }
        }
        let transport = AuthTransport()
        let client = try APIClient(configuration: configuration(provider), transport: transport)
        do { _ = try await client.send(AuthCall()); Issue.record("Expected provider error") }
        catch {
            if kind == "cancel" { #expect(error is CancellationError) }
            else { #expect(error as? NetworkError == (kind == "timeout" ? .timeout(.inactivity) : .invalidRequest(.authenticationProviderFailure))) }
            #expect(!String(describing: error).contains("PRIVATE"))
            #expect(!String(reflecting: error).contains("PRIVATE"))
        }
        #expect(await transport.requests.isEmpty)
        await client.shutdown()
    }

    @Test(arguments: ["cancel", "timeout", "shutdown"])
    func providerSharesCancellationBudgetAndJoinedCleanup(mode: String) async throws {
        let started = BudgetLatch(), cleanup = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(), transport = AuthTransport()
        let provider = AuthProvider { _ in
            await started.open()
            do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
            catch { await cleanup.open(); await release.wait() }
            // Even a provider ignoring cancellation cannot send these late credentials.
            return try HTTPHeaders(["Authorization": "late-secret"])
        }
        let client = try APIClient(configuration: configuration(provider), transport: transport, clock: clock)
        let call = Task { try await client.send(AuthCall()) }
        await started.wait(); await clock.waitForSleepers(2)
        var closing: Task<Void, Never>?
        switch mode {
        case "timeout": clock.advance(60)
        case "shutdown": closing = Task { await client.shutdown() }
        default: call.cancel()
        }
        await cleanup.wait()
        #expect(await provider.active == 1)
        #expect(await transport.requests.isEmpty)
        await release.open()
        do { _ = try await call.value; Issue.record("Expected interrupted call") }
        catch {
            if mode == "timeout" { #expect(error as? NetworkError == .timeout(.totalBudget)) }
            else { #expect(error is CancellationError) }
        }
        await closing?.value
        #expect(await provider.active == 0)
        #expect(await transport.requests.isEmpty)
        #expect(clock.pending == 0)
        await client.shutdown()
    }

    @Test func concurrentAccountsUseIndependentBindingsAndRequestIdentifiers() async throws {
        let arrived = BudgetLatch()
        let count = OSAllocatedUnfairLock(initialState: 0)
        let provider = AuthProvider { context in
            let ready = count.withLock { $0 += 1; return $0 == 32 }
            if ready { await arrived.open() }
            await arrived.wait()
            return try HTTPHeaders(["Authorization": "\(context.account!)/\(context.environment!)"])
        }
        let transport = AuthTransport()
        let clients = try ["A", "B"].map { (account: String) in
            try APIClient(configuration: NetworkConfiguration(baseURL: base,
                authentication: NetworkAuthentication(provider: provider, account: account, environment: "env-\(account)")), transport: transport)
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for number in 0..<32 {
                group.addTask {
                    var request = URLRequest(url: base.appendingPathComponent(number % 2 == 0 ? "A" : "B"))
                    request.httpMethod = "GET"
                    _ = try await clients[number % 2].send(request, response: .empty)
                }
            }
            try await group.waitForAll()
        }
        let contexts = await provider.contexts
        #expect(contexts.count == 32)
        #expect(Set(contexts.map(\.requestID)).count == 32)
        #expect(contexts.filter { $0.account == "A" && $0.environment == "env-A" }.count == 16)
        let requests = await transport.requests
        #expect(requests.count == 32)
        for request in requests {
            let account = request.url!.lastPathComponent
            #expect(request.value(forHTTPHeaderField: "Authorization") == "\(account)/env-\(account)")
        }
        for client in clients { await client.shutdown() }
    }

    @Test func cancellingOneAccountLeavesOtherProviderWorkAlive() async throws {
        let started = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock(), transport = AuthTransport()
        let count = OSAllocatedUnfairLock(initialState: 0)
        let provider = AuthProvider { context in
            let ready = count.withLock { $0 += 1; return $0 == 2 }
            if ready { await started.open() }
            if context.account == "A" {
                try await clock.sleep(until: clock.now().advanced(by: .seconds(7200)))
            } else { await release.wait() }
            return try HTTPHeaders(["Authorization": context.account!])
        }
        let clients = try ["A", "B"].map { (account: String) in
            try APIClient(configuration: NetworkConfiguration(baseURL: base,
                authentication: NetworkAuthentication(provider: provider, account: account)), transport: transport, clock: clock)
        }
        let first = Task { try await clients[0].send(AuthCall()) }
        let second = Task { try await clients[1].send(AuthCall()) }
        await started.wait(); await clock.waitForSleepers(3)
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await provider.active == 1)
        #expect(await transport.requests.isEmpty)
        await release.open()
        _ = try await second.value
        #expect(await provider.active == 0)
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "B")
        #expect(clock.pending == 0)
        for client in clients { await client.shutdown() }
    }

    @Test(arguments: [401, 302, 503]) func responsesDoNotRefreshOrReplay(status: Int) async throws {
        let provider = AuthProvider { _ in try HTTPHeaders(["Authorization": "secret"]) }
        let transport = AuthTransport(status: status)
        let client = try APIClient(configuration: configuration(provider), transport: transport)
        await #expect(throws: NetworkError.httpStatus(try HTTPStatus(status), headers: HTTPHeaders())) {
            try await client.send(AuthCall())
        }
        #expect(await provider.contexts.count == 1)
        #expect(await transport.requests.count == 1)
        await client.shutdown()
    }

    @Test func authDescriptionsExcludeAccountEnvironmentAndCredentials() async throws {
        let provider = AuthProvider { _ in try HTTPHeaders(["Authorization": "PRIVATE-TOKEN"]) }
        let authentication = NetworkAuthentication(provider: provider, account: "PRIVATE-ACCOUNT", environment: "PRIVATE-ENV")
        let config = NetworkConfiguration(baseURL: base, authentication: authentication)
        let transport = AuthTransport()
        let client = try APIClient(configuration: config, transport: transport)
        _ = try await client.send(AuthCall())
        let context = try #require(await provider.contexts.first)
        for value in [String(describing: authentication), String(reflecting: authentication),
                      String(describing: context), String(reflecting: context), String(reflecting: config)] {
            #expect(!value.contains("PRIVATE"))
        }
        await client.shutdown()
    }

    @Test func preCancelledCallNeverInvokesProvider() async throws {
        let provider = AuthProvider { _ in throw AuthFailure() }
        let client = try APIClient(configuration: configuration(provider), transport: AuthTransport())
        let release = BudgetLatch()
        let call = Task { await release.wait(); return try await client.send(AuthCall()) }
        call.cancel(); await release.open()
        await #expect(throws: CancellationError.self) { try await call.value }
        #expect(await provider.contexts.isEmpty)
        await client.shutdown()
    }

    @Test func invalidRequestsNeverInvokeProvider() async throws {
        let provider = AuthProvider { _ in throw AuthFailure() }
        let transport = AuthTransport()
        let client = try APIClient(configuration: configuration(provider), transport: transport)
        var request = URLRequest(url: base)
        request.setValue("wrong.invalid", forHTTPHeaderField: "Host")
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await client.send(request, response: .empty)
        }
        #expect(await provider.contexts.isEmpty)
        #expect(await transport.requests.isEmpty)
        await client.shutdown()
    }

    @Test func redirectCannotMoveProviderCredentialsToAnotherOrigin() async throws {
        let provider = AuthProvider { _ in try HTTPHeaders(["Authorization": "secret"]) }
        let destination = URL(string: "https://other.invalid/denied")!
        let policy = NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(destination)])
        let contacted = OSAllocatedUnfairLock(initialState: [URL]())
        let operation: URLSessionTransport.DataOperation = { session, request, delegate in
            contacted.withLock { $0.append(request.url!) }
            #expect(request.value(forHTTPHeaderField: "Authorization") == "secret")
            var next = request; next.url = destination
            let response = HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: nil,
                headerFields: ["Location": destination.absoluteString])!
            let task = session.dataTask(with: request) // Never resumed: scripted redirect delegate test.
            let followed = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
            delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: next,
                completionHandler: { next in followed.withLock { $0 = next } })
            task.cancel()
            #expect(followed.withLock { $0 } == nil)
            return TransportResponse(data: Data(), response: response)
        }
        let transport = try URLSessionTransport(dataOperation: operation, securityPolicy: policy, baseURL: base)
        let client = try APIClient(configuration: configuration(provider, security: policy), transport: transport)
        _ = try await client.send(URLRequest(url: base), response: .empty,
            options: NetworkCallOptions(acceptedStatuses: HTTPStatusPolicy(codes: [302])))
        #expect(await provider.contexts.count == 1)
        #expect(contacted.withLock { $0 } == [base])
        await client.shutdown()
    }
}
