#if os(macOS)
import Foundation
import NetworkKit
import Synchronization
import Testing

/// Separate Mac-only authority required: eight native controls + eight SDK connections.
@Suite(.serialized, .timeLimit(.minutes(3)), .enabled(if: ProcessInfo.processInfo.environment["NETWORKKIT_F5_RESOURCE_PROFILE"] == "separately-approved-sixteen"))
struct WebSocketResourceChecks {
    @Test func finiteNativeControlAndSDKProfile() async throws {
        let before = try nativeResidentBytes()
        let observation = Mutex((done: false, peak: before, samples: 0, errors: 0))
        let sampler = Task.detached {
            while !observation.withLock({ $0.done }) {
                do {
                    let value = try nativeResidentBytes()
                    observation.withLock { $0.peak = max($0.peak, value); $0.samples += 1 }
                } catch { observation.withLock { $0.errors += 1 } }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        do {
            try await pass(library: false)
            try await Task.sleep(for: .seconds(8))
            let nativeSettled = try nativeResidentBytes()
            try await pass(library: true)
            let sdkImmediate = try nativeResidentBytes()
            try await Task.sleep(for: .seconds(8))
            let sdkEightSeconds = try nativeResidentBytes()
            try await Task.sleep(for: .seconds(53))
            let sdkSixtyOneSeconds = try nativeResidentBytes()
            observation.withLock { $0.done = true }
            await sampler.value
            let summary = observation.withLock { $0 }
            #expect(summary.samples > 0 && summary.errors == 0)
            print("F5 RSS bytes before=\(before) nativeAfter8s=\(nativeSettled) sdkImmediate=\(sdkImmediate) sdkAfter8s=\(sdkEightSeconds) sdkAfter61s=\(sdkSixtyOneSeconds) peak=\(summary.peak) samples=\(summary.samples)")
        } catch {
            observation.withLock { $0.done = true }
            await sampler.value
            throw error
        }
    }
    private func pass(library: Bool) async throws {
        let payload = Data(repeating: 97, count: 4096)
        for _ in 0..<8 {
            let fixture = try await WebSocketLoopbackFixture.start(mode: .echo)
            do {
                if library {
                    let configuration = try WebSocketConfiguration(endpoint: fixture.endpoint, maximumMessageBytes: 4096,
                        timeouts: .init(connect: 3, send: 3, close: 0.5), allowInsecureLoopback: true)
                    let connection = try await WebSocketConnection.connect(configuration: configuration)
                    do {
                        for _ in 0..<16 {
                            try await connection.send(.binary(payload))
                            #expect(try await connection.receive() == .binary(payload))
                        }
                        try await connection.close()
                    } catch {
                        await Task.detached { try? await connection.close() }.value
                        throw error
                    }
                } else {
                    try await nativeControl(fixture, payload: payload)
                }
                #expect(fixture.accepted == 1 && fixture.messages == 16)
            } catch { #expect(await fixture.stop()); throw error }
            #expect(await fixture.stop())
        }
    }
    private func nativeControl(_ fixture: WebSocketLoopbackFixture, payload: Data) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        let task = session.webSocketTask(with: try fixture.endpoint)
        task.maximumMessageSize = 4096
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil); session.invalidateAndCancel() }
        try await withTaskCancellationHandler {
            for _ in 0..<16 {
                try await task.send(.data(payload))
                let message = try await task.receive()
                switch message {
                case .data(let data): #expect(data == payload)
                default: Issue.record("Native control changed binary message type")
                }
            }
        } onCancel: { task.cancel(); session.invalidateAndCancel() }
    }
}
#endif
