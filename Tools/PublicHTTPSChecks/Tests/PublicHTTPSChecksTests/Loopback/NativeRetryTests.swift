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
    func nativeLoopbackReadRetryCounters(input: Input, ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            let sink = NativeRetryEvents()
            let settings = URLSessionConfiguration.ephemeral
            settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false; settings.httpCookieAcceptPolicy = .never
            settings.urlCache = nil; settings.urlCredentialStorage = nil; settings.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = ownership == .borrowed ? URLSession(configuration: settings) : nil
            defer { session?.invalidateAndCancel() }
            let client = try nativeClient(base, session: session, diagnostics: sink)
            let enabled = try NetworkCallOptions(retry: .oneRetryForSafeReads)
            do {
                for path in ["retry-429", "retry-503", "retry-date"] {
                    let result = try await nativeSend(input, client: client, base: base, path: path,
                                                      response: .json(NativeReply.self), options: enabled)
                    #expect(result.value.value == "synthetic")
                    #expect(fixture.count("/" + path) == 2)
                }
                for (path, options) in [("retry-terminal", enabled), ("retry-disabled", NetworkCallOptions.default)] {
                    do {
                        _ = try await nativeSend(input, client: client, base: base, path: path,
                                                 response: .json(NativeReply.self), options: options)
                        Issue.record("Expected terminal native retry status")
                    } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 503) }
                    #expect(fixture.count("/" + path) == (path == "retry-terminal" ? 2 : 1))
                }
                let accepted = try await nativeSend(input, client: client, base: base, path: "retry-accepted",
                    response: .json(NativeReply.self), options: NetworkCallOptions(acceptedStatuses: HTTPStatusPolicy(codes: [503]),
                                                                                retry: .oneRetryForSafeReads))
                #expect(accepted.status.code == 503 && fixture.count("/retry-accepted") == 1)
                _ = try await nativeSend(input, client: client, base: base, path: "retry-redirect",
                                          response: .json(NativeReply.self), options: enabled)
                #expect(fixture.count("/retry-redirect") == 2 && fixture.count("/retry-target") == 2)
                try await nativeFixture { target, other in
                    fixture.redirect(to: other.appendingPathComponent("json"))
                    do {
                        _ = try await nativeSend(input, client: client, base: base, path: "cross", response: .data, options: enabled)
                        Issue.record("Expected denied native redirect")
                    } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 302) }
                    #expect(fixture.count("/cross") == 1 && target.count("/json") == 0)
                }
                #expect(sink.events.count == 8)
                #expect(sink.events.map(\.attemptCount) == [2, 2, 2, 2, 1, 1, 2, 1])
                #expect(fixture.receivedCookies == 0 && fixture.receivedCredentials == 0)
                await client.shutdown()
                if let session {
                    let (_, response) = try await session.data(from: base.appendingPathComponent("empty"))
                    #expect((response as? HTTPURLResponse)?.statusCode == 204)
                }
            } catch { await client.shutdown(); throw error }
            print("NativeLoopback retry \(input.rawValue) \(ownership.rawValue): status/date/redirect counters passed")
        }
    }
}
