import Foundation
import Testing
import os
import NetworkKit

@Suite struct PublicResponseAPITests {
    @Test func preRetryInitializerFunctionValuesRemainSourceCompatible() throws {
        typealias LegacyFactory = (HTTPHeaders, TimeInterval?, TimeInterval?, HTTPStatusPolicy, AuthenticationPolicy) throws -> NetworkCallOptions
        let labeled: LegacyFactory = NetworkCallOptions.init(headers:inactivityTimeout:totalTimeout:acceptedStatuses:authentication:)
        let inferred: LegacyFactory = NetworkCallOptions.init
        for factory in [labeled, inferred] {
            let options = try factory(HTTPHeaders(), nil, 3, .successful, .automatic)
            #expect(options.retry == .disabled)
            #expect(options.totalTimeout == 3)
            #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
                try factory(HTTPHeaders(), nil, -1, .successful, .automatic)
            }
        }
        #expect(try NetworkCallOptions(retry: .oneRetryForSafeReads).retry == .oneRetryForSafeReads)
    }

    @Test(arguments: [SessionStorageProfile.strict, .appManaged])
    func externalConsumerSelectsBorrowedStorageProfile(storage: SessionStorageProfile) async throws {
        let settings = URLSessionConfiguration.ephemeral
        settings.urlCredentialStorage = nil
        if storage == .strict {
            settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
            settings.httpCookieAcceptPolicy = .never; settings.urlCache = nil
            settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        }
        #if !os(watchOS)
        settings.protocolClasses = [SessionStubProtocol.self]
        #endif
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        let url = SessionStubProtocol.install(.init(data: Data("profile".utf8), status: 200, headers: [:]))
        defer { SessionStubProtocol.remove(url) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: url), session: session, storage: storage)
        #if !os(watchOS)
        #expect(try await client.send(URLRequest(url: url), response: .text).value == "profile")
        await client.shutdown()
        let (data, _) = try await session.data(from: url)
        #expect(data == Data("profile".utf8))
        #else
        // Public construction/lifecycle evidence; interception is unsupported on watchOS.
        await client.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.send(URLRequest(url: url), response: .text)
        }
        #endif
    }

    @Test func externalConsumerReceivesOnlySanitizedDiagnostics() async throws {
        final class Sink: NetworkDiagnosticSink {
            let storage = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
            var events: [NetworkDiagnosticEvent] { storage.withLock { $0 } }
            func record(_ event: NetworkDiagnosticEvent) { storage.withLock { $0.append(event) } }
        }
        let sink = Sink()
        #if !os(watchOS)
        let canary = "snk-private-canary"
        let url = SessionStubProtocol.install(.init(data: Data(canary.utf8), status: 401, headers: ["Set-Cookie": canary]))
        defer { SessionStubProtocol.remove(url) }
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
        settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil
        settings.urlCache = nil; settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.protocolClasses = [SessionStubProtocol.self]
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        for enabled in [false, true] {
            let client = try APIClient(configuration: NetworkConfiguration(baseURL: url,
                diagnostics: enabled ? sink : nil), session: session)
            do { _ = try await client.send(URLRequest(url: url), response: .data); Issue.record("Expected HTTP error") }
            catch {
                if case NetworkError.httpStatus(let status, _) = error { #expect(status.code == 401) }
                else { Issue.record("Unexpected error category") }
                #expect(!String(reflecting: error).contains(canary))
                #expect(!error.localizedDescription.contains(canary))
            }
            await client.shutdown()
        }
        #expect(sink.events.count == 1)
        #expect(sink.events.first?.outcome == .httpStatus)
        #expect(sink.events.first?.method == .get)
        #expect(sink.events.first?.status?.code == 401)
        #expect(!String(reflecting: sink.events).contains(canary))
        #else
        // Public API/admission check; native URLProtocol interception is unsupported on watchOS.
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: URL(string: "https://example.invalid")!, diagnostics: sink))
        await client.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.send(URLRequest(url: URL(string: "https://example.invalid")!), response: .data)
        }
        #expect(sink.events.count == 1)
        #expect(sink.events.first?.outcome == .invalidRequest(.clientClosed))
        #endif
    }

    @Test func externalConsumerCanConfigureAuthenticationProvider() async throws {
        actor Provider: AuthenticationHeaderProvider {
            private(set) var contexts: [AuthenticationContext] = []
            func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
                contexts.append(context)
                return try HTTPHeaders(["Authorization": "Bearer public-test"])
            }
        }
        let provider = Provider()
        #if !os(watchOS)
        let url = SessionStubProtocol.install(.init(data: Data(), status: 204, headers: [:], onRequest: { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer public-test")
        }))
        defer { SessionStubProtocol.remove(url) }
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
        settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil
        settings.urlCache = nil; settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.protocolClasses = [SessionStubProtocol.self]
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: url,
            authentication: NetworkAuthentication(provider: provider, account: "A", environment: "test")), session: session)
        _ = try await client.send(URLRequest(url: url), response: .empty)
        let contexts = await provider.contexts
        #expect(contexts.count == 1)
        #expect(contexts.first?.account == "A")
        #expect(contexts.first?.environment == "test")
        #else
        // Public construction/security check; native interception is unsupported on watchOS.
        let url = URL(string: "http://localhost:8080")!
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: url,
            security: NetworkSecurityPolicy(allowInsecureLoopback: true),
            authentication: NetworkAuthentication(provider: provider, account: "A", environment: "test")))
        await #expect(throws: NetworkError.invalidRequest(.credentialsOverHTTP)) {
            try await client.send(URLRequest(url: url), response: .empty)
        }
        #expect(await provider.contexts.isEmpty)
        #endif
        await client.shutdown()
    }

    @Test func externalConsumerCanShutdownThroughClientBoundary() async throws {
        struct Call: Endpoint {
            typealias Response = EmptyResponse
            let path = try! EndpointPath(segments: [])
        }
        let url = URL(string: "https://example.invalid")!
        let client: any NetworkClient = try APIClient(configuration: NetworkConfiguration(baseURL: url))
        await client.shutdown()
        await client.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) { try await client.send(Call()) }
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.send(URLRequest(url: url), response: .empty)
        }
    }

    @Test func systemTimeoutRetainsOnlySafeTransportIdentity() {
        #expect(NetworkError.timeout(.system).transportFailure == .init(URLError(.timedOut)))
        #expect(NetworkError.transport(.init(URLError(.cancelled))).transportFailure == .init(URLError(.cancelled)))
        #expect(NetworkError.timeout(.totalBudget).transportFailure == nil)
        #expect(NetworkError.decoding.transportFailure == nil)
    }
    @Test func externalConsumerCanInjectAndExecuteClientBoundary() async throws {
        struct Mock: NetworkClient {
            func shutdown() async {}
            func send<E: Endpoint>(_ endpoint: E) async throws -> NetworkResponse<E.Response> {
                throw NetworkError.invalidRequest(.unsupportedRequest)
            }
            func send<Value: Sendable>(_ request: URLRequest, response: ResponseStrategy<Value>,
                                      options: NetworkCallOptions) async throws -> NetworkResponse<Value> {
                let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])!
                return try response.decode(Data("mock".utf8), response: http, acceptedStatuses: options.acceptedStatuses)
            }
        }
        let client: any NetworkClient = Mock()
        #expect(try await client.send(URLRequest(url: URL(string: "https://example.invalid")!), response: .text).value == "mock")
        let configuration = NetworkConfiguration(baseURL: URL(string: "https://example.invalid")!)
        let owned: any NetworkClient = try APIClient(configuration: configuration)
        await owned.shutdown()
        await client.shutdown()
    }

    @Test func externalConsumerCanBorrowCompatibleSession() async throws {
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil
        settings.httpShouldSetCookies = false
        settings.httpCookieAcceptPolicy = .never
        settings.urlCredentialStorage = nil
        settings.urlCache = nil
        settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        #if !os(watchOS)
        settings.protocolClasses = [SessionStubProtocol.self]
        #endif
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: URL(string: "https://example.invalid")!),
                                   session: session)
        #if !os(watchOS)
        let url = SessionStubProtocol.install(.init(data: Data("public".utf8), status: 200, headers: [:]))
        defer { SessionStubProtocol.remove(url) }
        #expect(try await client.send(URLRequest(url: url), response: .text).value == "public")
        #else
        // URLProtocol interception is unsupported on watchOS; construction is still checked.
        _ = client
        #endif
    }
    @Test func externalConsumerCanSelectTypedAndRawStrategies() throws {
        struct Model: Decodable, Sendable { let name: String }
        struct Call: Endpoint {
            let path: EndpointPath
            let responseStrategy: ResponseStrategy<Model> = .json()
            let options = NetworkCallOptions.default
        }
        let local = URL(string: "http://localhost:8080")!
        let security = NetworkSecurityPolicy(allowInsecureLoopback: true, additionalRawOrigins: [try NetworkOrigin(local)])
        #expect(try NetworkOrigin(local).port == 8080)
        #expect(try Call(path: EndpointPath(segments: [])).request(configuration:
            NetworkConfiguration(baseURL: local, security: security)).url == local)
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        let call = Call(path: try EndpointPath(segments: ["items"]))
        #expect(try call.decodeResponse(Data(#"{"name":"ok"}"#.utf8), response: response).value.name == "ok")
        #expect(try ResponseStrategy<String>.text.decode(Data("hello".utf8), response: response).value == "hello")
        #expect(try ResponseStrategy<Data>.data.decode(Data([0,255]), response: response).value == Data([0,255]))
        #expect(try ResponseStrategy<EmptyResponse>.empty.decode(Data(), response: response).value == EmptyResponse())
    }
}
