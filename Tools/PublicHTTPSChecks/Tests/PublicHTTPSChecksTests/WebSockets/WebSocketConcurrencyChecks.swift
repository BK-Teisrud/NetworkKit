#if !os(watchOS)
import Foundation
import NetworkKit
import Testing

/// One separately authorized connection; public API only, no timing-based admission guess.
@Suite(.serialized, .timeLimit(.minutes(1)), .enabled(if: ProcessInfo.processInfo.environment["NETWORKKIT_F5_NATIVE_OVERLAP"] == "separately-approved-one"))
struct WebSocketConcurrencyChecks {
    private enum Observation: Sendable, Equatable { case conflict, message(WebSocketMessage?) }
    @Test func pendingReceiveOverlapsNativeSend() async throws {
        let fixture = try await WebSocketLoopbackFixture.start(mode: .echo)
        do {
            let configuration = try WebSocketConfiguration(endpoint: fixture.endpoint, maximumMessageBytes: 4096,
                timeouts: .init(connect: 3, send: 3, close: 0.5), allowInsecureLoopback: true)
            let connection = try await WebSocketConnection.connect(configuration: configuration)
            do {
                try await withThrowingTaskGroup(of: Observation.self) { group in
                    for _ in 0..<2 {
                        group.addTask {
                            do { return .message(try await connection.receive()) }
                            catch WebSocketError.operationConflict(.receive) { return .conflict }
                        }
                    }
                    defer { group.cancelAll() }
                    // The first completion must be the duplicate rejection. Therefore a
                    // real receive is admitted and waiting before this test calls send.
                    guard try await group.next() == .conflict else { throw NativeFixtureFailure.malformed }
                    try await connection.send(.text("synthetic-overlap"))
                    #expect(try await group.next() == .message(.text("synthetic-overlap")))
                }
                try await connection.close()
            } catch {
                await Task.detached { try? await connection.close() }.value
                throw error
            }
            #expect(fixture.accepted == 1 && fixture.messages == 1)
        } catch { #expect(await fixture.stop()); throw error }
        #expect(await fixture.stop())
    }
}
#endif
