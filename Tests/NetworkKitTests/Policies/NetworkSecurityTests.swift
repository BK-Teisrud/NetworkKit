import Foundation
import Testing
import os
@testable import NetworkKit

private struct SecurityEndpoint: Endpoint {
    typealias Response = EmptyResponse
    let path: EndpointPath
    var method: HTTPMethod = .get
    var options: NetworkCallOptions = .default
}

private final class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

@Suite struct NetworkSecurityTests {
    private func request(_ text: String, method: String = "GET", headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: URL(string: text)!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        return request
    }
    private func response(_ text: String, status: Int = 302) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: text)!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    @Test func originNormalizationAndSafeDescriptions() throws {
        #expect(try NetworkOrigin(URL(string: "https://EXAMPLE.invalid:443/a")!) == NetworkOrigin(URL(string: "https://example.invalid/b")!))
        #expect(try NetworkOrigin(URL(string: "https://[0:0:0:0:0:0:0:1]")!) == NetworkOrigin(URL(string: "https://[::1]:443")!))
        #expect(try NetworkOrigin(URL(string: "https://bücher.example")!) == NetworkOrigin(URL(string: "https://xn--bcher-kva.example")!))
        let origin = try NetworkOrigin(URL(string: "https://secret.example:1234/path?secret=token")!)
        let policy = NetworkSecurityPolicy(additionalRawOrigins: [origin])
        for text in [String(reflecting: origin), String(describing: origin), String(reflecting: policy)] {
            #expect(!text.contains("secret")); #expect(!text.contains("1234")); #expect(!text.contains("token"))
        }
    }

    @Test(arguments: ["http://localhost", "http://127.0.0.1", "http://[::1]", "http://example.invalid"])
    func HTTPIsDeniedByDefault(_ text: String) throws {
        #expect(throws: NetworkError.invalidRequest(.insecureTransport)) {
            try NetworkSecurityPolicy.default.validateRequest(request(text))
        }
    }

    @Test(arguments: ["http://LOCALHOST:8080/a", "http://127.0.0.1", "http://127.42.255.254:9999", "http://[::1]", "http://[0:0:0:0:0:0:0:1]"])
    func explicitLoopbackPermission(_ text: String) throws {
        let origin = try NetworkSecurityPolicy(allowInsecureLoopback: true).validateRequest(request(text))
        #expect(origin.isLoopback)
        #expect(origin.scheme == "http")
    }

    @Test(arguments: ["http://localhost.example.com", "http://localhost.", "http://localHOST.local", "http://192.168.1.1",
                      "http://10.0.0.1", "http://0.0.0.0", "http://128.0.0.1", "http://127.1", "http://0177.0.0.1",
                      "http://0x7f000001", "http://2130706433", "http://[::ffff:127.0.0.1]", "http://[::]", "http://[::2]"])
    func loopbackLookalikesAndNoncanonicalAddressesFail(_ text: String) {
        #expect(throws: NetworkError.self) { try NetworkSecurityPolicy(allowInsecureLoopback: true).validateRequest(request(text)) }
    }

    @Test(arguments: ["Authorization", "Proxy-Authorization", "Cookie", "X-API-Key", "X-Custom-Token"])
    func HTTPDoesNotAcceptCredentialOrCustomHeaders(_ name: String) {
        #expect(throws: NetworkError.invalidRequest(.credentialsOverHTTP)) {
            try NetworkSecurityPolicy(allowInsecureLoopback: true).validateRequest(
                request("http://localhost", headers: [name: "SECRET"]))
        }
    }

    @Test func HTTPMetadataAndTypedRawParity() throws {
        let config = NetworkConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!,
                                          security: NetworkSecurityPolicy(allowInsecureLoopback: true))
        let endpoint = SecurityEndpoint(path: try EndpointPath(segments: ["items"]),
                                        options: try NetworkCallOptions(headers: HTTPHeaders(["Accept": "application/json"])))
        let typed = try RequestBuilder.prepare(endpoint, configuration: config)
        let raw = try RequestBuilder.prepare(request("http://127.0.0.1:8080/items", headers: ["Accept": "application/json"]), configuration: config)
        #expect(typed.request.url == raw.request.url)
        #expect(typed.request.allHTTPHeaderFields == raw.request.allHTTPHeaderFields)
        let forbidden = NetworkConfiguration(baseURL: config.baseURL)
        #expect(throws: NetworkError.invalidRequest(.insecureTransport)) { try endpoint.request(configuration: forbidden) }
        #expect(throws: NetworkError.invalidRequest(.insecureTransport)) { try RequestBuilder.prepare(raw.request, configuration: forbidden) }
    }

    @Test func explicitExtraRawOriginDropsAllClientDefaultHeaders() throws {
        let extra = URL(string: "https://other.invalid")!
        let config = NetworkConfiguration(baseURL: URL(string: "https://example.invalid")!,
            headers: try HTTPHeaders(["Authorization": "SECRET", "X-Account": "SECRET"]),
            security: NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(extra)]))
        let prepared = try RequestBuilder.prepare(URLRequest(url: extra), configuration: config,
                                                  options: NetworkCallOptions(headers: HTTPHeaders(["X-Explicit": "call"])))
        #expect(prepared.request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(prepared.request.value(forHTTPHeaderField: "X-Account") == nil)
        #expect(prepared.request.value(forHTTPHeaderField: "X-Explicit") == "call")
        #expect(throws: NetworkError.invalidRequest(.unpermittedOrigin)) {
            try RequestBuilder.prepare(request("https://third.invalid"), configuration: config)
        }
        #expect(throws: NetworkError.invalidRequest(.unpermittedOrigin)) {
            try config.security.validateURL(extra, baseURL: config.baseURL)
        }
    }

    @Test func approvedRedirectsAndEffectivePorts() throws {
        let original = request("https://EXAMPLE.invalid/start", headers: ["Authorization": "SECRET"])
        let delegate = try NetworkTaskDelegate(request: original, policy: .default, disableAutomaticStorage: true)
        let accepted = delegate.redirectedRequest(response: response("https://example.invalid:443/start"),
            proposed: request("https://example.invalid:443/next", headers: ["Authorization": "SECRET"]))
        #expect(accepted?.value(forHTTPHeaderField: "Authorization") == "SECRET")
        #expect(accepted?.httpShouldHandleCookies == false)
        #expect(accepted?.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(delegate.failure == nil)
    }

    @Test(arguments: ["https://other.invalid/next", "https://example.invalid:444/next", "http://example.invalid/next", "https://user:secret@example.invalid/next", "https://example.invalid/next#fragment"])
    func unsafeRedirectsAreRefusedEvenWithExtraOriginPermission(_ text: String) throws {
        let policy = NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(URL(string: "https://other.invalid")!)])
        let delegate = try NetworkTaskDelegate(request: request("https://example.invalid/start"), policy: policy, disableAutomaticStorage: true)
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/start"), proposed: request(text)) == nil)
        #expect(delegate.failure == nil)
    }

    @Test(arguments: ["POST", "PUT", "PATCH", "DELETE", "OPTIONS", "CUSTOM", "GETTING"])
    func mutatingAndNonSelectedMethodsAreNeverReplayed(_ method: String) throws {
        let delegate = try NetworkTaskDelegate(request: request("https://example.invalid/start", method: method), policy: .default, disableAutomaticStorage: true)
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/start", status: 303),
            proposed: request("https://example.invalid/next")) == nil)
    }

    @Test func HEADPreservesMethodAndRejectsBodyOrChangedMethod() throws {
        let delegate = try NetworkTaskDelegate(request: request("https://example.invalid/start", method: "HEAD"), policy: .default, disableAutomaticStorage: true)
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/start"), proposed: request("https://example.invalid/a", method: "HEAD")) != nil)
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/a"), proposed: request("https://example.invalid/b")) == nil)
        var body = request("https://example.invalid/b", method: "HEAD"); body.httpBody = Data([1])
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/a"), proposed: body) == nil)
    }

    @Test func sixthHopAndLoopsBecomeStructuredErrors() throws {
        let delegate = try NetworkTaskDelegate(request: request("https://example.invalid/0"), policy: .default, disableAutomaticStorage: true)
        for i in 1...5 {
            #expect(delegate.redirectedRequest(response: response("https://example.invalid/\(i-1)"), proposed: request("https://example.invalid/\(i)")) != nil)
        }
        #expect(delegate.redirectedRequest(response: response("https://example.invalid/5"), proposed: request("https://example.invalid/6")) == nil)
        #expect(delegate.failure == .invalidResponse(.redirectLimitExceeded))
        let loop = try NetworkTaskDelegate(request: request("https://example.invalid/0"), policy: .default, disableAutomaticStorage: true)
        #expect(loop.redirectedRequest(response: response("https://example.invalid/0"), proposed: request("https://example.invalid/0")) == nil)
        #expect(loop.failure == .invalidResponse(.redirectLimitExceeded))
    }

    @Test func trustUsesSystemAndOtherChallengesNeverSupplyCredentials() {
        #expect(NetworkTaskDelegate.challengeDisposition(for: NSURLAuthenticationMethodServerTrust) == .performDefaultHandling)
        for method in [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest,
                       NSURLAuthenticationMethodClientCertificate, NSURLAuthenticationMethodDefault, "unknown"] {
            #expect(NetworkTaskDelegate.challengeDisposition(for: method) == .cancelAuthenticationChallenge)
        }
    }

    @Test func challengeCallbacksDiscardEvenProposedCredentials() throws {
        let session = URLSession(configuration: URLSessionTransport.configuration())
        let task = session.dataTask(with: request("https://example.invalid"))
        defer { task.cancel(); session.invalidateAndCancel() }
        let delegate = try NetworkTaskDelegate(request: request("https://example.invalid"), policy: .default, disableAutomaticStorage: true)
        for method in [NSURLAuthenticationMethodServerTrust, NSURLAuthenticationMethodHTTPBasic,
                       NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodClientCertificate] {
            let space = URLProtectionSpace(host: "example.invalid", port: 443, protocol: "https", realm: nil, authenticationMethod: method)
            let challenge = URLAuthenticationChallenge(protectionSpace: space,
                proposedCredential: URLCredential(user: "SECRET", password: "SECRET", persistence: .none),
                previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallengeSender())
            let calls = OSAllocatedUnfairLock(initialState: 0)
            let completion: @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { action, credential in
                #expect(credential == nil)
                #expect(action == (method == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge))
                calls.withLock { $0 += 1 }
            }
            delegate.urlSession(session, task: task, didReceive: challenge, completionHandler: completion)
            delegate.urlSession(session, didReceive: challenge, completionHandler: completion)
            #expect(calls.withLock { $0 } == 2)
        }
    }

    @Test func deniedInitialDestinationsNeverReachDataOperation() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let transport = try URLSessionTransport(dataOperation: { _, _, _ in
            calls.withLock { $0 += 1 }; throw URLError(.unknown)
        }, baseURL: URL(string: "https://example.invalid")!)
        for url in ["http://example.invalid", "https://other.invalid", "https://example.invalid:444"] {
            await #expect(throws: NetworkError.self) { try await transport.send(request(url)) }
        }
        #expect(calls.withLock { $0 } == 0)
        await transport.invalidateOwnedSession()
    }

    @Test func redirectCallbackRejectsBeforeExecutorCanFollow() async throws {
        let contacted = OSAllocatedUnfairLock(initialState: [String]())
        let transport = try URLSessionTransport(dataOperation: { session, request, delegate in
            contacted.withLock { $0.append(request.url!.host()!) }
            let next = self.request("https://evil.invalid/SECRET")
            let result = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
            let task = session.dataTask(with: request) // Never resumed; no network I/O.
            delegate.urlSession(session, task: task, willPerformHTTPRedirection: self.response(request.url!.absoluteString),
                                newRequest: next, completionHandler: { value in result.withLock { $0 = value } })
            task.cancel()
            if let follow = result.withLock({ $0 }) { contacted.withLock { $0.append(follow.url!.host()!) } }
            return TransportResponse(data: Data(), response: self.response(request.url!.absoluteString))
        }, baseURL: URL(string: "https://example.invalid")!)
        let response = try await transport.send(request("https://example.invalid/start"))
        #expect((response.response as? HTTPURLResponse)?.statusCode == 302)
        #expect(contacted.withLock { $0 } == ["example.invalid"])
        #expect(try ResponseStrategy<EmptyResponse>.empty.decode(response.data, response: response.response,
                                                               acceptedStatuses: HTTPStatusPolicy(codes: [302])).status.code == 302)
        await transport.invalidateOwnedSession()
    }

    @Test func loopFailurePropagatesThroughAdapter() async throws {
        let transport = try URLSessionTransport(dataOperation: { _, request, delegate in
            _ = delegate.redirectedRequest(response: self.response(request.url!.absoluteString), proposed: request)
            return TransportResponse(data: Data(), response: self.response(request.url!.absoluteString))
        })
        await #expect(throws: NetworkError.invalidResponse(.redirectLimitExceeded)) {
            try await transport.send(request("https://example.invalid/start"))
        }
        await transport.invalidateOwnedSession()
    }

    @Test func loopbackTransportDisablesAutomaticHandlingAndRejectsAppStores() async throws {
        let observed = OSAllocatedUnfairLock(initialState: [URLRequest]())
        let operation: URLSessionTransport.DataOperation = { _, request, _ in
            observed.withLock { $0.append(request) }
            return TransportResponse(data: Data(), response: self.response(request.url!.absoluteString, status: 200))
        }
        let policy = NetworkSecurityPolicy(allowInsecureLoopback: true)
        let owned = try URLSessionTransport(dataOperation: operation, securityPolicy: policy)
        _ = try await owned.send(request("http://localhost:8080"))
        let sent = observed.withLock { $0 }
        #expect(sent.count == 1)
        #expect(sent.first?.httpShouldHandleCookies == false)
        #expect(sent.first?.cachePolicy == .reloadIgnoringLocalCacheData)
        let config = URLSessionConfiguration.ephemeral; config.urlCredentialStorage = nil
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let borrowed = try URLSessionTransport(session: session, storagePolicy: .appManaged,
            dataOperation: operation, securityPolicy: policy)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await borrowed.send(request("http://localhost:8080"))
        }
        #expect(observed.withLock { $0.count } == 1)
        await owned.invalidateOwnedSession()
    }

    @Test func additionalPermissionDoesNotAuthorizeInsecureRemoteOrigin() throws {
        let insecure = URL(string: "http://example.invalid")!
        let policy = NetworkSecurityPolicy(allowInsecureLoopback: true,
                                          additionalRawOrigins: [try NetworkOrigin(insecure)])
        #expect(throws: NetworkError.invalidRequest(.insecureTransport)) {
            try policy.validateURL(insecure, baseURL: URL(string: "https://example.invalid")!, allowAdditionalOrigins: true)
        }
    }

    @Test func additionalRawOriginCannotInheritAnAppManagedCookieStore() async throws {
        let config = URLSessionConfiguration.ephemeral; config.urlCredentialStorage = nil
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let base = URL(string: "https://api.example.invalid")!
        let other = URL(string: "https://other.example.invalid")!
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let adapter = try URLSessionTransport(session: session, storagePolicy: .appManaged,
            dataOperation: { _, _, _ in calls.withLock { $0 += 1 }; throw URLError(.unknown) },
            securityPolicy: NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(other)]), baseURL: base)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try await adapter.send(URLRequest(url: other)) }
        #expect(calls.withLock { $0 } == 0)
    }

    @Test func credentialStoresAndSessionGlobalHeadersAreRejected() throws {
        for mode in 0..<2 {
            let config = URLSessionTransport.configuration()
            if mode == 0 { config.urlCredentialStorage = .shared }
            else { config.httpAdditionalHeaders = ["X-Secret": "SECRET"] }
            let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
            #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
                try URLSessionTransport(session: session, storagePolicy: .appManaged)
            }
        }
    }
}
