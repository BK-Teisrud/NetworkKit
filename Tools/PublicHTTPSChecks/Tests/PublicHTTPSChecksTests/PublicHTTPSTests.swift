import Foundation
import Testing
import NetworkKit
import Security
import os

enum Input: String, CaseIterable, Sendable { case typed, raw }
enum Ownership: String, CaseIterable, Sendable { case owned, borrowed }

private struct CookieReply: Decodable, Sendable { let cookies: [String: String] }
private struct CookieObservation: Equatable, Sendable {
    let echoed: Bool
    let retained: Bool
    let deleted: Bool
}

private struct PublicEndpoint<Value: Sendable>: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Value>
    let options: NetworkCallOptions
    let query: [HTTPQueryItem]
}

private struct SlideShow: Decodable, Sendable {
    struct Contents: Decodable, Sendable { let title: String }
    let slideshow: Contents
}

/// Fixed public fixtures and synthetic headers; system trust is never overridden.
/// The outer guard leaves cleanup time beyond the production 60-second total budget.
@Suite(.serialized, .timeLimit(.minutes(2)))
struct PublicHTTPSTests: Sendable {
    private func run(base: String = "https://httpbingo.org",
                     timeouts: NetworkTimeouts? = nil,
                     body: (APIClient, URL) async throws -> Void) async throws {
        let url = try #require(URL(string: base))
        let limits: NetworkTimeouts
        if let timeouts { limits = timeouts }
        else { limits = try .init(inactivity: 5, total: 10) }
        let client = try APIClient(configuration: .init(baseURL: url, timeouts: limits))
        do {
            try await body(client, url)
            await client.shutdown()
        } catch {
            await client.shutdown()
            throw error
        }
    }

    private func send<Value: Sendable>(_ input: Input, client: APIClient, base: URL,
        path: [String], response: ResponseStrategy<Value>,
        options: NetworkCallOptions = .default, query: [HTTPQueryItem] = []) async throws -> NetworkResponse<Value> {
        switch input {
        case .typed:
            return try await client.send(PublicEndpoint(path: .init(segments: path),
                responseStrategy: response, options: options, query: query))
        case .raw:
            let pathURL = path.reduce(base) { $0.appendingPathComponent($1) }
            var components = try #require(URLComponents(url: pathURL, resolvingAgainstBaseURL: false))
            if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.name, value: $0.value) } }
            let url = try #require(components.url)
            return try await client.send(URLRequest(url: url), response: response, options: options)
        }
    }

    @Test(arguments: Input.allCases)
    func trustedJSON(input: Input) async throws {
        try await run { client, base in
            let response = try await send(input, client: client, base: base, path: ["json"],
                response: .json(SlideShow.self))
            try #require(response.status.code == 200)
            let valid = !response.value.slideshow.title.isEmpty
            try #require(valid)
            print("PublicHTTPS json \(input.rawValue): status=200")
        }
    }

    @Test(arguments: Input.allCases)
    func explicitEmptyResponse(input: Input) async throws {
        try await run { client, base in
            let response = try await send(input, client: client, base: base, path: ["status", "204"], response: .empty)
            try #require(response.status.code == 204)
            print("PublicHTTPS empty \(input.rawValue): status=204")
        }
    }

    @Test(arguments: Input.allCases)
    func HTTPFailurePrecedesDecode(input: Input) async throws {
        try await run { client, base in
            do {
                _ = try await send(input, client: client, base: base, path: ["status", "503"],
                    response: .json(SlideShow.self))
                Issue.record("Expected an HTTP status failure")
            } catch NetworkError.httpStatus(let status, _) {
                try #require(status.code == 503)
                print("PublicHTTPS status \(input.rawValue): status=503")
            }
        }
    }

    @Test(arguments: Input.allCases)
    func sameOriginRedirect(input: Input) async throws {
        try await run { client, base in
            let response = try await send(input, client: client, base: base,
                path: ["relative-redirect", "1"], response: .data)
            try #require(response.status.code == 200)
            // The echo contains client/network metadata: inspect locally, never print/save it.
            let object = (try? JSONSerialization.jsonObject(with: response.value)) as? [String: Any]
            let finalURL = (object?["url"] as? String).flatMap(URL.init(string:))
            let valid = finalURL?.scheme == "https" && finalURL?.host == "httpbingo.org" && finalURL?.path == "/get"
            try #require(valid)
            print("PublicHTTPS redirect \(input.rawValue): status=200")
        }
    }

    @Test(arguments: Input.allCases)
    func validBadsslControl(input: Input) async throws {
        try await run(base: "https://sha256.badssl.com", timeouts: .default) { client, base in
            let response = try await send(input, client: client, base: base, path: [], response: .data)
            try #require(response.status.code == 200)
            let valid = !response.value.isEmpty
            try #require(valid)
            print("PublicHTTPS valid-certificate \(input.rawValue): status=200")
        }
    }

    @Test(arguments: Input.allCases)
    func untrustedCertificate(input: Input) async throws {
        try await rejection(input, base: "https://self-signed.badssl.com", name: "self-signed", expectedTrustError: Int(errSecNotTrusted))
    }

    @Test(arguments: Input.allCases)
    func operatorDesignatedHostnameMismatch(input: Input) async throws {
        try await rejection(input, base: "https://wrong.host.badssl.com", name: "wrong-host", expectedTrustError: Int(errSecHostNameMismatch))
    }

    private func rejection(_ input: Input, base: String, name: String, expectedTrustError: Int) async throws {
        try await run(base: base, timeouts: .default) { client, base in
            do {
                _ = try await send(input, client: client, base: base, path: [], response: .data)
                Issue.record("Invalid public certificate was accepted")
            } catch NetworkError.transport(let failure) {
                var certificateRejected = failure.domain == NSURLErrorDomain &&
                    [URLError.serverCertificateUntrusted.rawValue, URLError.serverCertificateHasUnknownRoot.rawValue].contains(failure.code)
                if !certificateRejected && failure.domain == NSURLErrorDomain && failure.code == URLError.secureConnectionFailed.rawValue {
                    print("PublicHTTPS certificate-observation \(name) \(input.rawValue): known-domain=\(failure.domain == NSURLErrorDomain) code=\(failure.code)")
                    certificateRejected = await TrustObservation().corroborate(base: base, name: name, input: input, expectedTrustError: expectedTrustError)
                }
                try #require(certificateRejected)
                print("PublicHTTPS \(name) \(input.rawValue): certificate-rejected=\(failure.code)")
            }
        }
    }

    @Test(arguments: Input.allCases)
    func totalBudget(input: Input) async throws {
        try await run { client, base in
            do {
                _ = try await send(input, client: client, base: base, path: ["delay", "3"],
                    response: .data, options: .init(totalTimeout: 0.25))
                Issue.record("Delayed public response escaped the total budget")
            } catch NetworkError.timeout(.totalBudget) {
                print("PublicHTTPS total-budget \(input.rawValue): totalBudget")
            }
        }
    }
    private func requireCancellation<Value: Sendable>(_ result: Result<Value, any Error>) throws {
        let cancelled = switch result {
        case .success: false
        case .failure(let error): error is CancellationError
        }
        try #require(cancelled, "Expected CancellationError from the joined delayed operation")
    }

    private func runBorrowed(_ body: (APIClient, URL, URLSession) async throws -> Void) async throws {
        let base = try #require(URL(string: "https://httpbingo.org"))
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
        settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil; settings.urlCache = nil
        settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.timeoutIntervalForRequest = 5; settings.timeoutIntervalForResource = 10
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() } // App-owned cleanup, after the client joins.
        let client = try APIClient(configuration: .init(baseURL: base,
            timeouts: .init(inactivity: 5, total: 10)), session: session)
        do { try await body(client, base, session); await client.shutdown() }
        catch { await client.shutdown(); throw error }
    }

    @Test(arguments: Input.allCases)
    func nativeLifecycleCallerCancellation(input: Input) async throws {
        try await run { client, base in
            let pending = Task { try await send(input, client: client, base: base, path: ["delay", "3"], response: .data) }
            do {
                try await Task.sleep(for: .milliseconds(150))
                pending.cancel()
                try requireCancellation(await pending.result)
                let next = try await send(input, client: client, base: base, path: ["status", "204"], response: .empty)
                try #require(next.status.code == 204)
                print("NativeLifecycle cancel \(input.rawValue): cancelled-and-reused")
            } catch {
                pending.cancel(); _ = await pending.result
                throw error
            }
        }
    }

    @Test(arguments: Input.allCases)
    func nativeLifecycleOwnedShutdown(input: Input) async throws {
        try await run { client, base in
            let pending = Task { try await send(input, client: client, base: base, path: ["delay", "3"], response: .data) }
            do {
                try await Task.sleep(for: .milliseconds(150))
                await client.shutdown()
                try requireCancellation(await pending.result)
                do {
                    _ = try await send(input, client: client, base: base, path: ["status", "204"], response: .empty)
                    Issue.record("Closed client admitted a new call")
                } catch NetworkError.invalidRequest(.clientClosed) {
                    print("NativeLifecycle shutdown \(input.rawValue): cancelled-and-closed")
                }
            } catch {
                pending.cancel(); _ = await pending.result
                throw error
            }
        }
    }

    @Test(arguments: Input.allCases)
    func nativeLifecycleBorrowedShutdown(input: Input) async throws {
        try await runBorrowed { client, base, session in
            let before = try await send(input, client: client, base: base, path: ["status", "204"], response: .empty)
            try #require(before.status.code == 204)
            let pending = Task { try await send(input, client: client, base: base, path: ["delay", "3"], response: .data) }
            do {
                try await Task.sleep(for: .milliseconds(150))
                await client.shutdown()
                try requireCancellation(await pending.result)
                let (_, response) = try await session.data(for: URLRequest(url: base.appendingPathComponent("status").appendingPathComponent("204")))
                try #require((response as? HTTPURLResponse)?.statusCode == 204)
                print("NativeLifecycle borrowed \(input.rawValue): cancelled-and-session-alive")
            } catch {
                pending.cancel(); _ = await pending.result
                throw error
            }
        }
    }

    private func cookieObservation(input: Input?, base: URL) async throws -> CookieObservation {
        let settings = URLSessionConfiguration.ephemeral
        settings.urlCredentialStorage = nil; settings.urlCache = nil
        settings.httpCookieAcceptPolicy = .always; settings.httpShouldSetCookies = true
        settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.timeoutIntervalForRequest = 5; settings.timeoutIntervalForResource = 10
        let store = try #require(settings.httpCookieStorage)
        try #require(store !== HTTPCookieStorage.shared)
        settings.httpCookieStorage = store
        let session = URLSession(configuration: settings)
        defer {
            for cookie in store.cookies ?? [] { store.deleteCookie(cookie) }
            session.invalidateAndCancel()
        }
        let client: APIClient?
        if input != nil {
            client = try APIClient(configuration: .init(baseURL: base,
                timeouts: .init(inactivity: 5, total: 10)), session: session, storage: .appManaged)
        } else { client = nil }
        func fetch(_ path: [String], query: [HTTPQueryItem] = []) async throws -> CookieReply {
            if let input, let client {
                let response = try await send(input, client: client, base: base, path: path,
                    response: .json(CookieReply.self), query: query)
                try #require(response.status.code == 200)
                return response.value
            }
            let pathURL = path.reduce(base) { $0.appendingPathComponent($1) }
            var components = try #require(URLComponents(url: pathURL, resolvingAgainstBaseURL: false))
            if !query.isEmpty { components.queryItems = query.map { .init(name: $0.name, value: $0.value) } }
            let (data, response) = try await session.data(from: #require(components.url))
            try #require((response as? HTTPURLResponse)?.statusCode == 200)
            return try JSONDecoder().decode(CookieReply.self, from: data)
        }
        do {
            let seed = try await fetch(["cookies", "set"], query: [.init(name: "networkkit_fixture", value: "synthetic")])
            let echoed = seed.cookies["networkkit_fixture"] == "synthetic"
            let retained = store.cookies(for: base.appendingPathComponent("cookies"))?.contains {
                $0.name == "networkkit_fixture" && $0.value == "synthetic"
            } == true
            for cookie in store.cookies ?? [] { store.deleteCookie(cookie) }
            let after = try await fetch(["cookies"])
            let deleted = after.cookies["networkkit_fixture"] == nil
            await client?.shutdown()
            return .init(echoed: echoed, retained: retained, deleted: deleted)
        } catch { await client?.shutdown(); throw error }
    }

    @Test(arguments: Input.allCases)
    func nativeAppManagedCookieMatchesFoundation(input: Input) async throws {
        let base = try #require(URL(string: "https://httpbingo.org"))
        let reference = try await cookieObservation(input: nil, base: base)
        let observed = try await cookieObservation(input: input, base: base)
        #expect(reference.deleted && observed.deleted)
        #expect(observed == reference)
        print("NativeLifecycle appManaged \(input.rawValue): Foundation echo=\(reference.echoed) retained=\(reference.retained); SDK echo=\(observed.echoed) retained=\(observed.retained); deletion=\(observed.deleted)")
    }

    @Test(arguments: Input.allCases)
    func nativeCookieFixtureAcceptsExplicitHeader(input: Input) async throws {
        try await run { client, base in
            let settings = URLSessionConfiguration.ephemeral
            settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
            settings.urlCredentialStorage = nil; settings.urlCache = nil
            settings.timeoutIntervalForRequest = 5; settings.timeoutIntervalForResource = 10
            let session = URLSession(configuration: settings)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: base.appendingPathComponent("cookies"))
            request.setValue("networkkit_fixture=synthetic", forHTTPHeaderField: "Cookie")
            let (data, response) = try await session.data(for: request)
            try #require((response as? HTTPURLResponse)?.statusCode == 200)
            let reference = try JSONDecoder().decode(CookieReply.self, from: data)
            try #require(reference.cookies["networkkit_fixture"] == "synthetic")
            let observed = try await send(input, client: client, base: base, path: ["cookies"],
                response: .json(CookieReply.self), options: .init(headers: .init(["Cookie": "networkkit_fixture=synthetic"])))
            try #require(observed.value.cookies["networkkit_fixture"] == "synthetic")
            print("NativeLifecycle explicit-cookie \(input.rawValue): fixture and SDK header observed")
        }
    }

    @Test(arguments: Input.allCases, Ownership.allCases)
    func nativeLifecycleStrictCookies(input: Input, ownership: Ownership) async throws {
        let check: @Sendable (APIClient, URL) async throws -> Void = { client, base in
            let seed = try await send(input, client: client, base: base, path: ["cookies", "set"],
                response: .json(CookieReply.self), query: [.init(name: "networkkit_fixture", value: "synthetic")])
            let seedAbsent = seed.value.cookies["networkkit_fixture"] == nil
            try #require(seedAbsent)
            let after = try await send(input, client: client, base: base, path: ["cookies"], response: .json(CookieReply.self))
            let remainsAbsent = after.value.cookies["networkkit_fixture"] == nil
            try #require(remainsAbsent)
            print("NativeLifecycle cookies \(input.rawValue) \(ownership.rawValue): strict-absence")
        }
        switch ownership {
        case .owned: try await run(body: check)
        case .borrowed: try await runBorrowed { client, base, _ in try await check(client, base) }
        }
    }

}
