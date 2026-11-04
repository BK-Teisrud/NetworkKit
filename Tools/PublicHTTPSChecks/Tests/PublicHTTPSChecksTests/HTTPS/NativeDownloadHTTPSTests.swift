import Foundation
import NetworkKit
import Security
import Testing

private enum DownloadFixtureFailure: Error { case malformed }
private struct FileBearerReply: Decodable { let authenticated: Bool; let token: String }
private struct FileCookieReply: Decodable { let cookies: [String: String] }
private struct FileStoreObservation: Equatable { let echoed: Bool; let retained: Bool; let cachePublished: Bool }

private actor FileHeaderProvider: AuthenticationHeaderProvider {
    private var observed: [AuthenticationContext] = []
    func headers(for context: AuthenticationContext) throws -> HTTPHeaders {
        observed.append(context)
        guard let account = context.account, ["A", "B"].contains(account) else { throw DownloadFixtureFailure.malformed }
        return try HTTPHeaders(["Authorization": "Bearer synthetic-f4-" + account])
    }
    var contexts: [AuthenticationContext] { observed }
}

private func decodeFile<Value: Decodable>(_ file: DownloadedFile, as type: Value.Type) throws -> Value {
    // No arbitrary body or decoder error is logged; downloaded echo files are explicitly removed.
    do { return try JSONDecoder().decode(type, from: Data(contentsOf: file.url)) }
    catch { throw DownloadFixtureFailure.malformed }
}

extension PublicHTTPSTests {
    @Test(arguments: Ownership.allCases)
    func nativeHTTPSDownloadPayloads(ownership: Ownership) async throws {
        let base = try #require(URL(string: "https://httpbingo.org"))
        let settings = downloadSession(ownership)
        defer { settings?.invalidateAndCancel() }
        let client = try settings.map { try APIClient(configuration: .init(baseURL: base,
            timeouts: .default), session: $0) }
            ?? APIClient(configuration: .init(baseURL: base, timeouts: .default))
        let expected = Data("networkkit-file".utf8)
        let target = base.appendingPathComponent("base64").appendingPathComponent(expected.base64EncodedString())
        var files: [URL] = []
        defer { for url in files { try? FileManager.default.removeItem(at: url) } }
        do {
            let direct = try await client.download(URLRequest(url: target), maximumBytes: 1024)
            files.append(direct.value.url)
            #expect(direct.status.code == 200 && direct.value.byteCount == Int64(expected.count))
            #expect(try Data(contentsOf: direct.value.url) == expected)
            var redirect = try #require(URLComponents(url: base.appendingPathComponent("redirect-to"), resolvingAgainstBaseURL: false))
            redirect.queryItems = [.init(name: "url", value: target.absoluteString)]
            let followed = try await client.download(URLRequest(url: #require(redirect.url)), maximumBytes: 1024)
            files.append(followed.value.url)
            #expect(try Data(contentsOf: followed.value.url) == expected)
            do {
                let unexpected = try await client.download(URLRequest(url: target), maximumBytes: Int64(expected.count - 1))
                files.append(unexpected.value.url); Issue.record("HTTPS size limit was not enforced")
            } catch DownloadError.sizeLimitExceeded {}
            let empty = try await client.download(URLRequest(url: base.appendingPathComponent("status/200")), maximumBytes: 1)
            files.append(empty.value.url)
            #expect(empty.value.byteCount == 0)
            do {
                let unexpected = try await client.download(URLRequest(url: base.appendingPathComponent("status/206")), maximumBytes: 1024)
                files.append(unexpected.value.url); Issue.record("Partial HTTPS response was accepted")
            } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 206) }
            await client.shutdown()
            #expect(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
            print("NativeHTTPS download payload \(ownership.rawValue): bytes/status/redirect/output-limit/handoff passed")
        } catch { await client.shutdown(); throw error }
    }

    @Test(arguments: Ownership.allCases)
    func nativeHTTPSDownloadAuthentication(ownership: Ownership) async throws {
        let base = try #require(URL(string: "https://httpbingo.org"))
        let session = downloadSession(ownership)
        defer { session?.invalidateAndCancel() }
        let provider = FileHeaderProvider()
        let events = NativeRetryEvents()
        var clients: [APIClient] = []
        do {
            for account in ["A", "B"] {
                let config = NetworkConfiguration(baseURL: base, timeouts: .default,
                    authentication: .init(provider: provider, account: account, environment: "synthetic-f4"), diagnostics: events)
                let client = try session.map { try APIClient(configuration: config, session: $0) } ?? APIClient(configuration: config)
                clients.append(client)
                let result = try await client.download(URLRequest(url: base.appendingPathComponent("bearer")), maximumBytes: 4096)
                defer { try? FileManager.default.removeItem(at: result.value.url) }
                let reply = try decodeFile(result.value, as: FileBearerReply.self)
                #expect(reply.authenticated && reply.token == "synthetic-f4-" + account)
            }
            let client = try #require(clients.last)
            do {
                let unexpected = try await client.download(URLRequest(url: base.appendingPathComponent("bearer")), maximumBytes: 4096,
                    options: .init(authentication: .disabled))
                try? FileManager.default.removeItem(at: unexpected.value.url)
                Issue.record("Disabled provider unexpectedly authenticated a download")
            } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 401) }
            let contexts = await provider.contexts
            #expect(contexts.map(\.account) == ["A", "B"])
            #expect(contexts.allSatisfy { $0.method == .get && $0.environment == "synthetic-f4" && $0.origin.scheme == "https" })
            #expect(events.events.count == 3 && events.events.allSatisfy { $0.attemptCount == 1 })
            for client in clients { await client.shutdown() }
            if let session {
                let (url, response) = try await session.download(from: base.appendingPathComponent("status/200"))
                defer { try? FileManager.default.removeItem(at: url) }
                #expect((response as? HTTPURLResponse)?.statusCode == 200)
            }
            print("NativeHTTPS download auth \(ownership.rawValue): one provider/account, no refresh/replay, disabled skip and isolation passed")
        } catch { for client in clients { await client.shutdown() }; throw error }
    }

    @Test(arguments: Ownership.allCases)
    func nativeHTTPSDownloadTrust(ownership: Ownership) async throws {
        for (host, name, expected) in [("sha256.badssl.com", "valid", 0),
                                     ("self-signed.badssl.com", "self-signed", Int(errSecNotTrusted)),
                                     ("wrong.host.badssl.com", "wrong-host", Int(errSecHostNameMismatch))] {
            let base = try #require(URL(string: "https://" + host))
            let session = downloadSession(ownership)
            defer { session?.invalidateAndCancel() }
            let config = NetworkConfiguration(baseURL: base)
            let client = try session.map { try APIClient(configuration: config, session: $0) } ?? APIClient(configuration: config)
            do {
                do {
                    let result = try await client.download(URLRequest(url: base), maximumBytes: 65536)
                    defer { try? FileManager.default.removeItem(at: result.value.url) }
                    try #require(expected == 0, "Invalid TLS fixture was accepted by download")
                    #expect(result.status.code == 200 && result.value.byteCount > 0)
                } catch NetworkError.transport(let failure) {
                    try #require(expected != 0, "Valid TLS download control failed")
                    var rejected = failure.domain == NSURLErrorDomain &&
                        [URLError.serverCertificateUntrusted.rawValue, URLError.serverCertificateHasUnknownRoot.rawValue].contains(failure.code)
                    if !rejected && failure.domain == NSURLErrorDomain && failure.code == URLError.secureConnectionFailed.rawValue {
                        rejected = await TrustObservation().corroborate(base: base, name: name, input: .raw,
                                                                       expectedTrustError: expected)
                    }
                    try #require(rejected, "Generic network failure is not TLS rejection evidence")
                }
                await client.shutdown()
            } catch { await client.shutdown(); throw error }
        }
        print("NativeHTTPS download trust \(ownership.rawValue): positive control and invalid certificate rejection passed")
    }

    @Test
    func nativeHTTPSDownloadAppManagedStores() async throws {
        let base = try #require(URL(string: "https://httpbingo.org"))
        func observe(library: Bool) async throws -> FileStoreObservation {
            let settings = URLSessionConfiguration.ephemeral
            settings.urlCredentialStorage = nil
            settings.httpCookieAcceptPolicy = .always; settings.httpShouldSetCookies = true
            settings.requestCachePolicy = .useProtocolCachePolicy
            settings.timeoutIntervalForRequest = NetworkTimeouts.default.inactivity
            settings.timeoutIntervalForResource = NetworkTimeouts.default.total
            let cookies = try #require(settings.httpCookieStorage)
            try #require(cookies !== HTTPCookieStorage.shared)
            let cache = URLCache(memoryCapacity: 131072, diskCapacity: 0, diskPath: nil)
            settings.urlCache = cache
            let session = URLSession(configuration: settings)
            let client = try library ? APIClient(configuration: .init(baseURL: base, timeouts: .default),
                                                 session: session, storage: .appManaged) : nil
            defer {
                for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
                cache.removeAllCachedResponses(); session.invalidateAndCancel()
            }
            func fetch(_ url: URL) async throws -> Data {
                let location: URL
                if let client {
                    let result = try await client.download(URLRequest(url: url), maximumBytes: 16384)
                    location = result.value.url
                    try #require(result.status.code == 200)
                } else {
                    let result = try await session.download(from: url)
                    location = result.0
                    guard (result.1 as? HTTPURLResponse)?.statusCode == 200 else {
                        try? FileManager.default.removeItem(at: location); throw DownloadFixtureFailure.malformed
                    }
                }
                defer { try? FileManager.default.removeItem(at: location) }
                return try Data(contentsOf: location)
            }
            do {
                var seed = try #require(URLComponents(url: base.appendingPathComponent("cookies/set"), resolvingAgainstBaseURL: false))
                seed.queryItems = [.init(name: "networkkit_file_fixture", value: "synthetic")]
                let data = try await fetch(#require(seed.url))
                let reply: FileCookieReply
                do { reply = try JSONDecoder().decode(FileCookieReply.self, from: data) }
                catch { throw DownloadFixtureFailure.malformed }
                let echoed = reply.cookies["networkkit_file_fixture"] == "synthetic"
                let retained = cookies.cookies(for: base)?.contains { $0.name == "networkkit_file_fixture" && $0.value == "synthetic" } == true
                let cacheURL = base.appendingPathComponent("cache/60")
                _ = try await fetch(cacheURL)
                let cachePublished = cache.cachedResponse(for: URLRequest(url: cacheURL)) != nil
                _ = try await fetch(cacheURL)
                await client?.shutdown()
                #expect((cookies.cookies(for: base)?.contains { $0.name == "networkkit_file_fixture" } == true) == retained)
                for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
                let (url, response) = try await session.download(from: base.appendingPathComponent("cookies"))
                defer { try? FileManager.default.removeItem(at: url) }
                #expect((response as? HTTPURLResponse)?.statusCode == 200)
                let after: FileCookieReply
                do { after = try JSONDecoder().decode(FileCookieReply.self, from: Data(contentsOf: url)) }
                catch { throw DownloadFixtureFailure.malformed }
                #expect(after.cookies["networkkit_file_fixture"] == nil)
                cache.removeAllCachedResponses()
                #expect(cache.cachedResponse(for: URLRequest(url: cacheURL)) == nil)
                return .init(echoed: echoed, retained: retained, cachePublished: cachePublished)
            } catch { await client?.shutdown(); throw error }
        }
        let reference = try await observe(library: false)
        let observed = try await observe(library: true)
        #expect(observed == reference)
        print("NativeHTTPS download appManaged: reference/SDK cookie echo=\(reference.echoed)/\(observed.echoed) retained=\(reference.retained)/\(observed.retained) cache publication=\(reference.cachePublished)/\(observed.cachePublished); owner deletion/reuse passed")
    }
}
