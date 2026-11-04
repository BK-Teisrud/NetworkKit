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
    @Test(arguments: Input.allCases)
    func nativeLoopbackResponseParity(input: Input) async throws {
        try await nativeFixture { fixture, base in
            let client = try nativeClient(base)
            do {
                let json = try await nativeSend(input, client: client, base: base, path: "json", response: .json(NativeReply.self))
                #expect(json.value.value == "synthetic" && json.status.code == 200)
                let data = try await nativeSend(input, client: client, base: base, path: "payload", response: .data)
                #expect(data.value.count == 65536 && data.value.allSatisfy { $0 == 120 })
                #expect(try await nativeSend(input, client: client, base: base, path: "empty", response: .empty).status.code == 204)
                do {
                    _ = try await nativeSend(input, client: client, base: base, path: "status", response: .json(NativeReply.self))
                    Issue.record("Expected native HTTP failure before decoding")
                } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 503) }
                #expect(fixture.count("/json") == 1 && fixture.count("/payload") == 1)
                await client.shutdown()
            } catch { await client.shutdown(); throw error }
            print("NativeLoopback response \(input.rawValue): passed")
        }
    }

    @Test(arguments: Input.allCases)
    func nativeLoopbackRedirectCounters(input: Input) async throws {
        try await nativeFixture { fixture, base in
            try await nativeFixture { destination, other in
                fixture.redirect(to: other.appendingPathComponent("json"))
                let client = try nativeClient(base)
                do {
                    let response = try await nativeSend(input, client: client, base: base, path: "redirect", response: .json(NativeReply.self))
                    #expect(response.value.value == "synthetic" && fixture.count("/json") == 1)
                    let denied = try await nativeSend(input, client: client, base: base, path: "cross", response: .data,
                        options: .init(acceptedStatuses: .init(codes: [302])))
                    #expect(denied.status.code == 302 && destination.count("/json") == 0)
                    let control = URLSession(configuration: .ephemeral)
                    defer { control.invalidateAndCancel() }
                    let (_, followed) = try await control.data(from: base.appendingPathComponent("cross"))
                    #expect((followed as? HTTPURLResponse)?.statusCode == 200 && destination.count("/json") == 1)
                    do {
                        _ = try await nativeSend(input, client: client, base: base, path: "loop-a", response: .data)
                        Issue.record("Expected native redirect loop failure")
                    } catch NetworkError.invalidResponse(let reason) { #expect(reason == .redirectLimitExceeded) }
                    #expect(fixture.count("/loop-a") == 1 && fixture.count("/loop-b") == 1)
                    await client.shutdown()
                } catch { await client.shutdown(); throw error }
            }
            print("NativeLoopback redirects \(input.rawValue): counters passed")
        }
    }

    @Test(arguments: Input.allCases)
    func nativeLoopbackObservedCancellationAndShutdown(input: Input) async throws {
        try await nativeFixture { fixture, base in
            for shutdown in [false, true] {
                let client = try nativeClient(base)
                let before = fixture.count("/hold")
                let task = Task { try await nativeSend(input, client: client, base: base, path: "hold", response: .data) }
                do {
                let contacted = try await fixture.contacted("/hold", after: before)
                try #require(contacted)
                if shutdown { await client.shutdown() } else { task.cancel() }
                do { _ = try await task.value; Issue.record("Expected cancellation after actual fixture contact") }
                catch is CancellationError { }
                if !shutdown {
                    #expect(try await nativeSend(input, client: client, base: base, path: "empty", response: .empty).status.code == 204)
                    await client.shutdown()
                } else {
                    do {
                        _ = try await nativeSend(input, client: client, base: base, path: "empty", response: .empty)
                        Issue.record("Expected closed-client admission failure")
                    } catch NetworkError.invalidRequest(let reason) { #expect(reason == .clientClosed) }
                }
                } catch {
                    task.cancel()
                    _ = await task.result
                    await client.shutdown()
                    throw error
                }
            }
            print("NativeLoopback lifecycle \(input.rawValue): contacted, cancelled, joined")
        }
    }

    @Test(arguments: Input.allCases)
    func nativeLoopbackNativeBudgets(input: Input) async throws {
        try await nativeFixture { fixture, base in
            for total in [false, true] {
                let client = try nativeClient(base)
                do {
                    let options = try NetworkCallOptions(inactivityTimeout: total ? 2 : 0.25, totalTimeout: total ? 0.15 : 3)
                    _ = try await nativeSend(input, client: client, base: base, path: "hold", response: .data, options: options)
                    Issue.record("Expected native budget expiration")
                } catch NetworkError.timeout(let reason) { #expect(reason == (total ? .totalBudget : .system)) }
                catch { await client.shutdown(); throw error }
                await client.shutdown()
            }
            #expect(fixture.count("/hold") == 2)
            print("NativeLoopback budgets \(input.rawValue): Foundation request timeout and library total")
        }
    }
}
