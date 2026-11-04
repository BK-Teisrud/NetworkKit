import Foundation
import Testing
@testable import NetworkKit

#if os(macOS)
/// Real HTTP on a kernel-assigned loopback port. No TLS bypass, host-file changes,
/// external service, shared stores or persistent credential fixtures are used.
private final class StorageServer {
    private let fixture: BoundedFixtureProcess
    let base: URL
    let realm = UUID().uuidString
    init() throws {
        fixture = try BoundedFixtureProcess(script: #"""
import http.server, json, threading, sys
records = []
lock = threading.Lock()
realm = sys.argv[1]
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/records':
            with lock: body = json.dumps(records).encode()
            self.send_response(200)
            self.send_header('Cache-Control', 'no-store')
        else:
            with lock:
                records.append({'path': self.path, 'cookie': self.headers.get('Cookie'),
                                'authorization': self.headers.get('Authorization'),
                                'ifNoneMatch': self.headers.get('If-None-Match')})
                hit = len([r for r in records if r['path'] == self.path])
            body = json.dumps({'hit': hit, 'cookie': self.headers.get('Cookie')}).encode()
            if self.path == '/challenge' and not self.headers.get('Authorization'):
                self.send_response(401)
                self.send_header('WWW-Authenticate', 'Basic realm="%s"' % realm)
                self.send_header('Cache-Control', 'no-store')
            else:
                self.send_response(200)
                self.send_header('Cache-Control', 'public, max-age=3600' if self.path == '/cache' else 'no-store')
            if self.path == '/cookie':
                self.send_header('Set-Cookie', 'snk_fixture=memory-only; Path=/; Max-Age=3600')
            if self.path == '/cache': self.send_header('ETag', '"fixture-v1"')
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
print(server.server_port, flush=True)
server.serve_forever()
"""#, arguments: [realm])
        let line = try fixture.startupLine()
        guard let port = Int(line) else {
            _ = fixture.stop(); throw URLError(.cannotConnectToHost)
        }
        base = URL(string: "http://127.0.0.1:\(port)")!
    }
    func stop() { #expect(fixture.stop(), "Storage fixture did not terminate within its bounded cleanup") }
}
private struct StorageReply: Decodable, Sendable { let hit: Int; let cookie: String? }
private struct StorageRecord: Decodable, Sendable {
    let path: String
    let cookie: String?
    let authorization: String?
    let ifNoneMatch: String?
}
#endif

private final class StorageDelegate: NSObject, URLSessionDelegate {}

@Suite(.timeLimit(.minutes(1))) struct StorageIntegrationTests {
    private func publicClient(_ base: URL, session: URLSession? = nil,
                              storage: SessionStorageProfile = .strict) throws -> APIClient {
        let config = NetworkConfiguration(baseURL: base, timeouts: try NetworkTimeouts(inactivity: 5, total: 10),
            security: NetworkSecurityPolicy(allowInsecureLoopback: true))
        if let session { return try APIClient(configuration: config, session: session, storage: storage) }
        return try APIClient(configuration: config)
    }

    @Test(arguments: [false, true]) func strictProfileDoesNotRetainOrSendCookies(borrowed: Bool) async throws {
        #if os(macOS)
        let server = try StorageServer(); defer { server.stop() }
        let injected = borrowed ? URLSession(configuration: URLSessionTransport.configuration()) : nil
        defer { injected?.invalidateAndCancel() }
        let client = try publicClient(server.base, session: injected)
        let url = server.base.appendingPathComponent("cookie")
        for hit in 1...2 {
            let response = try await client.send(URLRequest(url: url), response: .json(StorageReply.self))
            #expect(response.value.hit == hit)
            #expect(response.value.cookie == nil)
        }
        let records = try await client.send(URLRequest(url: server.base.appendingPathComponent("records")), response: .json([StorageRecord].self)).value
        #expect(records.count == 2 && records.allSatisfy { $0.cookie == nil && $0.authorization == nil })
        await client.shutdown()
        // Positive control: a separate raw ephemeral app session really receives/sends
        // this fixture cookie. Its private in-memory store is never a shared user store.
        let config = URLSessionConfiguration.ephemeral
        config.urlCredentialStorage = nil; config.urlCache = nil
        config.httpCookieAcceptPolicy = .always
        let store = try #require(config.httpCookieStorage)
        try #require(store !== HTTPCookieStorage.shared)
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        _ = try await session.data(from: url)
        #expect(store.cookies(for: url)?.contains { $0.name == "snk_fixture" } == true)
        let (data, _) = try await session.data(from: url)
        #expect(try JSONDecoder().decode(StorageReply.self, from: data).cookie?.contains("snk_fixture=memory-only") == true)
        for cookie in store.cookies ?? [] { store.deleteCookie(cookie) }
        #expect(store.cookies(for: url)?.isEmpty != false)
        #else
        // Real-server evidence is macOS-only. Check the real owned session's
        // configuration and per-request copy for each ownership mode with scripted I/O.
        let operation: URLSessionTransport.DataOperation = { session, request, _ in
            #expect(session.configuration.httpCookieStorage == nil)
            #expect(!session.configuration.httpShouldSetCookies)
            #expect(!request.httpShouldHandleCookies)
            return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 204,
                httpVersion: nil, headerFields: ["Set-Cookie": "snk_fixture=memory-only"])!)
        }
        let session = URLSession(configuration: URLSessionTransport.configuration())
        defer { session.invalidateAndCancel() }
        let transport: URLSessionTransport
        if borrowed { transport = try URLSessionTransport(session: session, dataOperation: operation) }
        else { transport = try URLSessionTransport(dataOperation: operation) }
        _ = try await transport.send(URLRequest(url: URL(string: "https://example.invalid/cookie")!))
        await transport.shutdown()
        #endif
    }

    @Test(arguments: [false, true]) func strictProfileCannotServeAnAutomaticHTTPCacheEntry(borrowed: Bool) async throws {
        #if os(macOS)
        let probe = borrowed ? "borrowed" : "owned"
        FileHandle.standardOutput.write(Data("Storage cache \(probe): startup\n".utf8))
        let server = try StorageServer(); defer {
            FileHandle.standardOutput.write(Data("Storage cache \(probe): teardown\n".utf8))
            server.stop()
            FileHandle.standardOutput.write(Data("Storage cache \(probe): complete\n".utf8))
        }
        let injected = borrowed ? URLSession(configuration: URLSessionTransport.configuration()) : nil
        defer { injected?.invalidateAndCancel() }
        let client = try publicClient(server.base, session: injected)
        var request = URLRequest(url: server.base.appendingPathComponent("cache"))
        request.cachePolicy = .returnCacheDataDontLoad
        for hit in 1...2 {
            FileHandle.standardOutput.write(Data("Storage cache \(probe): strict request \(hit)\n".utf8))
            let response = try await client.send(request, response: .json(StorageReply.self))
            #expect(response.value.hit == hit)
        }
        FileHandle.standardOutput.write(Data("Storage cache \(probe): wire records\n".utf8))
        let records = try await client.send(URLRequest(url: server.base.appendingPathComponent("records")), response: .json([StorageRecord].self)).value
        #expect(records.count == 2 && records.allSatisfy { $0.ifNoneMatch == nil })
        FileHandle.standardOutput.write(Data("Storage cache \(probe): client shutdown\n".utf8))
        await client.shutdown()
        // Positive control: an explicitly app-owned memory cache serves a seeded
        // response using URLSession, without contacting the local server again.
        FileHandle.standardOutput.write(Data("Storage cache \(probe): positive cache control\n".utf8))
        let cache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Cache-Control": "max-age=3600"])!
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data("seeded-cache".utf8), storagePolicy: .allowedInMemoryOnly), for: request)
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil; config.urlCache = cache
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); cache.removeAllCachedResponses() }
        let (data, _) = try await session.data(for: request)
        #expect(data == Data("seeded-cache".utf8))
        FileHandle.standardOutput.write(Data("Storage cache \(probe): positive cache control complete\n".utf8))
        #else
        let operation: URLSessionTransport.DataOperation = { session, request, _ in
            #expect(session.configuration.urlCache == nil)
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 204,
                httpVersion: nil, headerFields: ["Cache-Control": "public, max-age=3600"])!)
        }
        let session = URLSession(configuration: URLSessionTransport.configuration())
        defer { session.invalidateAndCancel() }
        let transport: URLSessionTransport
        if borrowed { transport = try URLSessionTransport(session: session, dataOperation: operation) }
        else { transport = try URLSessionTransport(dataOperation: operation) }
        var request = URLRequest(url: URL(string: "https://example.invalid/cache")!)
        request.cachePolicy = .returnCacheDataDontLoad
        _ = try await transport.send(request)
        await transport.shutdown()
        #endif
    }

    @Test func ownedStrictProfileNeverSuppliesBasicChallengeCredentials() async throws {
        #if os(macOS)
        let server = try StorageServer(); defer { server.stop() }
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false; settings.urlCache = nil
        let store = try #require(settings.urlCredentialStorage)
        try #require(store !== URLCredentialStorage.shared)
        let protection = URLProtectionSpace(host: "127.0.0.1", port: server.base.port!, protocol: "http",
            realm: server.realm, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        let credential = URLCredential(user: "fixture", password: UUID().uuidString, persistence: .forSession)
        store.setDefaultCredential(credential, for: protection)
        let control = URLSession(configuration: settings)
        defer { control.invalidateAndCancel(); store.remove(credential, for: protection) }
        let challenge = server.base.appendingPathComponent("challenge")
        let (data, controlResponse) = try await control.data(from: challenge)
        #expect((controlResponse as? HTTPURLResponse)?.statusCode == 200)
        let controlHits = try JSONDecoder().decode(StorageReply.self, from: data).hit
        // The same server has demonstrably accepted the isolated app credential.
        // A fresh strict client must not inherit it or supply auth after a challenge.
        let client = try publicClient(server.base)
        do {
            let response = try await client.send(URLRequest(url: server.base.appendingPathComponent("challenge")),
                response: .data, options: NetworkCallOptions(acceptedStatuses: HTTPStatusPolicy(codes: [401])))
            #expect(response.status.code == 401)
        } catch let error as NetworkError {
            // Foundation may report authentication-challenge cancellation as a
            // system transport failure instead of delivering the 401 response.
            let failure = try #require(error.transportFailure)
            #expect(failure.domain == NSURLErrorDomain)
            #expect([URLError.userCancelledAuthentication.rawValue, URLError.cancelled.rawValue].contains(failure.code))
        }
        let records = try await client.send(URLRequest(url: server.base.appendingPathComponent("records")), response: .json([StorageRecord].self)).value
        let strictRecords = Array(records.dropFirst(controlHits))
        #expect(!strictRecords.isEmpty && strictRecords.allSatisfy { $0.path == "/challenge" && $0.authorization == nil })
        #expect(store.defaultCredential(for: protection) != nil)
        await client.shutdown()
        #else
        let transport = try URLSessionTransport(dataOperation: { session, request, _ in
            #expect(session.configuration.urlCredentialStorage == nil)
            #expect(NetworkTaskDelegate.challengeDisposition(for: NSURLAuthenticationMethodHTTPBasic) == .cancelAuthenticationChallenge)
            #expect(NetworkTaskDelegate.challengeDisposition(for: NSURLAuthenticationMethodHTTPDigest) == .cancelAuthenticationChallenge)
            return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 401,
                httpVersion: nil, headerFields: ["WWW-Authenticate": "Basic realm=fixture"])!)
        })
        _ = try await transport.send(URLRequest(url: URL(string: "https://example.invalid/challenge")!))
        await transport.shutdown()
        #endif
    }

    @Test(arguments: [SessionStorageProfile.strict, .appManaged])
    func publicProfilesRejectCredentialsGlobalHeadersDelegatesAndBackgrounds(storage: SessionStorageProfile) throws {
        let base = URL(string: "https://example.invalid")!
        for kind in ["credentials", "headers", "delegate", "background"] {
            let config: URLSessionConfiguration
            if kind == "background" { config = .background(withIdentifier: "NetworkKitTests-" + UUID().uuidString) }
            else { config = URLSessionTransport.configuration() }
            if kind == "credentials" {
                let privateSettings = URLSessionConfiguration.ephemeral
                let store = try #require(privateSettings.urlCredentialStorage)
                config.urlCredentialStorage = store
            }
            if kind == "headers" { config.httpAdditionalHeaders = ["Authorization": "fixture"] }
            let session = URLSession(configuration: config, delegate: kind == "delegate" ? StorageDelegate() : nil, delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let reason: NetworkError.InvalidRequestReason = kind == "credentials" && storage == .strict
                ? .invalidConfiguration : .unsupportedRequest
            #expect(throws: NetworkError.invalidRequest(reason)) { try publicClient(base, session: session, storage: storage) }
        }
    }

    @Test(arguments: ["cookie", "cache"])
    func appManagedActiveStoresCannotRunOverLoopbackHTTP(kind: String) async throws {
        let config = URLSessionTransport.configuration()
        if kind == "cookie" {
            let privateSettings = URLSessionConfiguration.ephemeral
            let store = try #require(privateSettings.httpCookieStorage)
            config.httpCookieStorage = store
            config.httpShouldSetCookies = true; config.httpCookieAcceptPolicy = .always
        } else { config.urlCache = URLCache(memoryCapacity: 1024, diskCapacity: 0) }
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let base = URL(string: "http://127.0.0.1:1")! // No task may reach this unused port.
        let client = try publicClient(base, session: session, storage: .appManaged)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await client.send(URLRequest(url: base), response: .data)
        }
        await client.shutdown()
    }

    @Test func appManagedCookiesCannotFollowAdditionalRawOriginPermission() async throws {
        let settings = URLSessionConfiguration.ephemeral
        settings.urlCredentialStorage = nil
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        let other = URL(string: "https://other.invalid")!
        let config = NetworkConfiguration(baseURL: URL(string: "https://base.invalid")!,
            security: NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(other)]))
        let client = try APIClient(configuration: config, session: session, storage: .appManaged)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await client.send(URLRequest(url: other), response: .data)
        }
        await client.shutdown()
    }

    @Test func additionalRawOriginWithoutCookiesCannotUseAppCachePolicy() async throws {
        let settings = URLSessionTransport.configuration()
        let cache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0)
        settings.urlCache = cache
        #if !os(watchOS)
        settings.protocolClasses = [SessionStubProtocol.self]
        #endif
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel(); cache.removeAllCachedResponses() }
        let url = SessionStubProtocol.install(.init(data: Data("foreign".utf8), status: 200, headers: [:]))
        defer { SessionStubProtocol.remove(url) }
        let base = URL(string: "https://base.invalid")!
        let policy = NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(url)])
        let transport = try URLSessionTransport(session: session, storagePolicy: .appManaged,
            dataOperation: { session, request, delegate in
                #expect(!request.httpShouldHandleCookies)
                #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
                return try await SessionStubProtocol.dataOperation(session, request, delegate)
            }, securityPolicy: policy, baseURL: base)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base, security: policy), transport: transport)
        var request = URLRequest(url: url); request.cachePolicy = .returnCacheDataDontLoad
        #expect(try await client.send(request, response: .text).value == "foreign")
        #expect(request.cachePolicy == .returnCacheDataDontLoad) // The app's value is untouched.
        await client.shutdown()
        #expect(session.configuration.urlCache === cache)
    }

    @Test func appManagedCookieCacheProfileRequiresExplicitPublicSelection() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.urlCredentialStorage = nil
        let base = URL(string: "https://example.invalid")!
        let store = try #require(config.httpCookieStorage)
        try #require(store !== HTTPCookieStorage.shared)
        store.cookieAcceptPolicy = .always
        let cookie = try #require(HTTPCookie(properties: [.domain: "example.invalid", .path: "/",
            .name: "snk_owner", .value: "fixture", .secure: "TRUE"]))
        store.setCookie(cookie)
        let cache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0)
        config.urlCache = cache
        let request = URLRequest(url: base)
        cache.storeCachedResponse(CachedURLResponse(response: HTTPURLResponse(url: base, statusCode: 200,
            httpVersion: nil, headerFields: [:])!, data: Data("owner".utf8), storagePolicy: .allowedInMemoryOnly), for: request)
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); store.deleteCookie(cookie); cache.removeAllCachedResponses() }
        #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) { try publicClient(base, session: session) }
        let client = try publicClient(base, session: session, storage: .appManaged)
        let original = session.configuration
        await client.shutdown()
        #expect(session.configuration.httpCookieStorage === original.httpCookieStorage)
        #expect(session.configuration.urlCache === original.urlCache)
        #expect(session.configuration.httpShouldSetCookies == original.httpShouldSetCookies)
        #expect(store.cookies(for: base)?.contains { $0.name == "snk_owner" } == true)
        #expect(cache.cachedResponse(for: request)?.data == Data("owner".utf8))
        // The app, not NetworkKit shutdown, owns selective deletion of its state.
        store.deleteCookie(cookie); cache.removeCachedResponse(for: request)
        #expect(store.cookies(for: base)?.contains { $0.name == "snk_owner" } != true)
        #expect(cache.cachedResponse(for: request) == nil)
    }
}
