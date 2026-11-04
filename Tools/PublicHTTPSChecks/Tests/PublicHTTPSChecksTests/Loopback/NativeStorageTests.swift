import Foundation
import Network
import Testing
#if os(macOS)
@testable import NetworkKit
#else
import NetworkKit
#endif
import os
import Darwin

extension PublicHTTPSTests {
    @Test(arguments: Input.allCases, Ownership.allCases)
    func nativeLoopbackStrictStorage(input: Input, ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            let settings = URLSessionConfiguration.ephemeral
            settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
            settings.urlCredentialStorage = nil; settings.urlCache = nil
            settings.httpCookieAcceptPolicy = .never
            settings.requestCachePolicy = .reloadIgnoringLocalCacheData
            settings.timeoutIntervalForRequest = 2; settings.timeoutIntervalForResource = 4
            let session = ownership == .borrowed ? URLSession(configuration: settings) : nil
            defer { session?.invalidateAndCancel() }
            let client = try nativeClient(base, session: session)
            do {
                for _ in 0..<2 {
                    _ = try await nativeSend(input, client: client, base: base, path: "cookie", response: .data)
                    _ = try await nativeSend(input, client: client, base: base, path: "cache", response: .data)
                }
                #expect(fixture.count("/cookie") == 2 && fixture.count("/cache") == 2)
                #expect(fixture.receivedCookies == 0 && fixture.receivedCredentials == 0)
                do {
                    _ = try await nativeSend(input, client: client, base: base, path: "forbidden", response: .data,
                        options: .init(headers: .init(["Authorization": "Basic synthetic"])))
                    Issue.record("Expected credentials-over-HTTP rejection before contact")
                } catch NetworkError.invalidRequest(let reason) { #expect(reason == .credentialsOverHTTP) }
                #expect(fixture.count("/forbidden") == 0)
                let contactControl = URLSession(configuration: settings)
                defer { contactControl.invalidateAndCancel() }
                _ = try await contactControl.data(from: base.appendingPathComponent("forbidden"))
                #expect(fixture.count("/forbidden") == 1 && fixture.receivedCredentials == 0)
                do {
                    let response = try await nativeSend(input, client: client, base: base, path: "challenge", response: .data,
                        options: .init(acceptedStatuses: .init(codes: [401])))
                    #expect(response.status.code == 401)
                } catch let error as NetworkError {
                    let failure = try #require(error.transportFailure)
                    #expect(failure.domain == NSURLErrorDomain)
                    #expect([URLError.userCancelledAuthentication.rawValue, URLError.cancelled.rawValue].contains(failure.code))
                }
                #expect(fixture.count("/challenge") >= 1 && fixture.receivedCredentials == 0)
                await client.shutdown()
                if let session {
                    let (_, response) = try await session.data(from: base.appendingPathComponent("empty"))
                    #expect((response as? HTTPURLResponse)?.statusCode == 204)
                }
            } catch { await client.shutdown(); throw error }
            print("NativeLoopback storage \(input.rawValue) \(ownership.rawValue): counters passed")
        }
    }

    @Test
    func nativeLoopbackPrivateAppStoreControls() async throws {
        try await nativeFixture { fixture, base in
            let settings = URLSessionConfiguration.ephemeral
            settings.httpCookieAcceptPolicy = .always
            let cookies = try #require(settings.httpCookieStorage)
            let credentials = try #require(settings.urlCredentialStorage)
            try #require(cookies !== HTTPCookieStorage.shared && credentials !== URLCredentialStorage.shared)
            let cache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 0, diskPath: nil)
            settings.urlCache = cache
            let protection = URLProtectionSpace(host: "127.0.0.1", port: try #require(base.port), protocol: "http",
                realm: "NetworkKit-synthetic", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            let credential = URLCredential(user: "fixture", password: "synthetic", persistence: .forSession)
            credentials.setDefaultCredential(credential, for: protection)
            let session = URLSession(configuration: settings)
            defer {
                session.invalidateAndCancel()
                for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
                credentials.remove(credential, for: protection)
                cache.removeAllCachedResponses()
            }
            _ = try await session.data(from: base.appendingPathComponent("cookie"))
            _ = try await session.data(from: base.appendingPathComponent("cookie"))
            #expect(fixture.receivedCookies > 0 && cookies.cookies?.isEmpty == false)
            let request = URLRequest(url: base.appendingPathComponent("cache"))
            _ = try await session.data(for: request)
            for _ in 0..<200 {
                if cache.cachedResponse(for: request) != nil { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(cache.cachedResponse(for: request) != nil)
            _ = try await session.data(for: request)
            #expect(fixture.count("/cache") == 1)
            // Automatic credential-store use differs across Foundation targets.
            // It is not an SDK promise: injected credential stores are unsupported.
            #expect(credentials.defaultCredential(for: protection) != nil)
            let (_, response) = try await session.data(from: base.appendingPathComponent("challenge"))
            let automaticStatus = try #require((response as? HTTPURLResponse)?.statusCode)
            #expect([200, 401].contains(automaticStatus))
            #expect(automaticStatus == 200 ? fixture.receivedCredentials > 0 : fixture.receivedCredentials == 0)
            let explicitSettings = URLSessionConfiguration.ephemeral
            explicitSettings.httpCookieStorage = nil; explicitSettings.httpShouldSetCookies = false
            explicitSettings.urlCredentialStorage = nil; explicitSettings.urlCache = nil
            explicitSettings.timeoutIntervalForRequest = 2; explicitSettings.timeoutIntervalForResource = 4
            let explicitSession = URLSession(configuration: explicitSettings)
            defer { explicitSession.invalidateAndCancel() }
            var explicitRequest = URLRequest(url: base.appendingPathComponent("challenge"))
            explicitRequest.setValue("Basic " + Data("fixture:synthetic".utf8).base64EncodedString(),
                                     forHTTPHeaderField: "Authorization")
            let beforeExplicit = fixture.receivedCredentials
            let (_, explicitResponse) = try await explicitSession.data(for: explicitRequest)
            #expect((explicitResponse as? HTTPURLResponse)?.statusCode == 200)
            #expect(fixture.receivedCredentials == beforeExplicit + 1)
            print("NativeLoopback automatic Foundation challenge status=\(automaticStatus); explicit fixture control completed")
            for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
            credentials.remove(credential, for: protection)
            cache.removeAllCachedResponses()
            #expect(cookies.cookies?.isEmpty != false)
            #expect(credentials.defaultCredential(for: protection) == nil && cache.cachedResponse(for: request) == nil)
            print("NativeLoopback app controls: cookie/cache/explicit credential and private deletion observations recorded")
        }
    }
}
