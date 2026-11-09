#if !os(watchOS)
import Foundation
import NetworkKit
import Testing

/// Compile-only until explicit scope approval. Exactly 18 SDK connects across eleven tests.
@Suite(.serialized, .timeLimit(.minutes(1)), .enabled(if: ProcessInfo.processInfo.environment["NETWORKKIT_F5_LOCAL_WS"] == "approved-mac-eighteen"))
struct WebSocketNativeChecks {
    private func configuration(_ fixture: WebSocketLoopbackFixture, protocols: [String] = [],
                               connect: TimeInterval = 3) throws -> WebSocketConfiguration {
        try .init(endpoint: fixture.endpoint, maximumMessageBytes: 4096, subprotocols: protocols,
            timeouts: .init(connect: connect, send: 3, close: 0.5), allowInsecureLoopback: true)
    }
    private func run(_ mode: WebSocketLoopbackFixture.Mode,
                     body: (WebSocketLoopbackFixture) async throws -> Void) async throws {
        let fixture = try await WebSocketLoopbackFixture.start(mode: mode)
        do { try await body(fixture) }
        catch { #expect(await fixture.stop()); throw error }
        #expect(await fixture.stop())
    }
    private func withConnection(_ fixture: WebSocketLoopbackFixture, protocols: [String] = [],
                                body: (WebSocketConnection) async throws -> Void) async throws {
        let connection = try await WebSocketConnection.connect(configuration: configuration(fixture, protocols: protocols))
        do { try await body(connection); try await connection.close() }
        catch {
            if case WebSocketError.transport(let failure) = error {
                print("F5 safe native transport: domain=\(failure.domain) code=\(failure.code)")
            }
            await Task.detached { try? await connection.close() }.value
            throw error
        }
    }
    @Test func echoTypesEmptyUnicodeAndExactLimit() async throws {
        try await run(.echo) { fixture in
            try await withConnection(fixture, protocols: ["networkkit.synthetic.v1"]) { connection in
                #expect(await connection.selectedSubprotocol == "networkkit.synthetic.v1")
                for message in [WebSocketMessage.text(""), .text("status-æ🙂"), .binary(Data()), .binary(Data(repeating: 97, count: 4096))] {
                    try await connection.send(message)
                    #expect(try await connection.receive() == message)
                }
            }
            #expect(fixture.accepted == 1 && fixture.messages == 4)
        }
    }
    @Test func oversizedIncomingTerminates() async throws {
        try await run(.oversize) { fixture in
            try await withConnection(fixture) { connection in
                try await connection.send(.text("trigger"))
                do { _ = try await connection.receive(); Issue.record("Oversize message accepted") }
                catch WebSocketError.messageTooLarge {}
            }
        }
    }
    @Test func normalPeerCloseEndsRepeatedReceives() async throws {
        try await run(.normalClose) { fixture in
            try await withConnection(fixture) { connection in
                try await connection.send(.text("trigger"))
                #expect(try await connection.receive() == nil)
                #expect(try await connection.receive() == nil)
                let info = await connection.closeInfo
                #expect(info?.code == 1000 && info?.reason == "synthetic-close")
            }
        }
    }
    @Test func applicationPeerCloseIsStructured() async throws {
        try await run(.applicationClose) { fixture in
            try await withConnection(fixture) { connection in
                try await connection.send(.text("trigger"))
                do { _ = try await connection.receive(); Issue.record("Application close treated as normal") }
                catch WebSocketError.peerClosed(let code) { #expect(code == 3001) }
            }
        }
    }
    @Test func withheldHandshakeUsesConnectBudget() async throws {
        try await run(.withheld) { fixture in
            do {
                let unexpected = try await WebSocketConnection.connect(configuration: configuration(fixture, connect: 0.2))
                try? await unexpected.close(); Issue.record("Withheld handshake opened")
            } catch WebSocketError.timeout(.connect) {}
            #expect(fixture.accepted == 1)
        }
    }
    @Test func activeReceiveCancellationTerminates() async throws {
        try await run(.echo) { fixture in
            try await withConnection(fixture) { connection in
                let receive = Task { try await connection.receive() }
                // Native admission is intentionally observed after a finite scheduling interval;
                // deterministic actor-admission races have separate latch-based coverage.
                try await Task.sleep(for: .milliseconds(100))
                receive.cancel()
                do { _ = try await receive.value; Issue.record("Cancelled receive succeeded") } catch is CancellationError {}
                do { try await connection.send(.text("late")); Issue.record("Cancelled connection remained open") } catch is CancellationError {}
            }
        }
    }
    @Test func admittedConnectCancellationTerminates() async throws {
        try await run(.withheld) { fixture in
            let configuration = try configuration(fixture)
            let connect = Task { try await WebSocketConnection.connect(configuration: configuration) }
            do { try await fixture.waitForAdmission() }
            catch { connect.cancel(); _ = try? await connect.value; throw error }
            connect.cancel()
            do { let unexpected = try await connect.value; try? await unexpected.close(); Issue.record("Cancelled connect opened") }
            catch is CancellationError {}
        }
    }
    @Test func abruptNativeEndFails() async throws {
        try await run(.drop) { fixture in
            do {
                try await withConnection(fixture) { connection in
                    try await connection.send(.text("trigger"))
                    _ = try await connection.receive()
                    Issue.record("Abrupt end became successful receive")
                }
            } catch WebSocketError.transport {} // No assertion about platform-specific safe code.
        }
    }
    @Test func missingSelectedProtocolIsRejected() async throws {
        try await run(.missingProtocol) { fixture in
            do {
                try await withConnection(fixture, protocols: ["networkkit.synthetic.v1"]) { _ in
                    Issue.record("Missing selected protocol accepted")
                }
            } catch WebSocketError.subprotocolMismatch {}
        }
    }
    @Test func eightSequentialLifetimesReleaseFixtureConnections() async throws {
        try await run(.echo) { fixture in
            for _ in 0..<8 {
                try await withConnection(fixture) { connection in
                    try await connection.send(.binary(Data([1, 2, 3])))
                    #expect(try await connection.receive() == .binary(Data([1, 2, 3])))
                }
            }
            #expect(fixture.accepted == 8 && fixture.messages == 8)
        }
    }
    @Test func finiteSlowConsumerPreservesSixteenMessages() async throws {
        try await run(.echo) { fixture in
            try await withConnection(fixture) { connection in
                for index in 0..<16 { try await connection.send(.text("synthetic-\(index)")) }
                try await Task.sleep(for: .milliseconds(200))
                for index in 0..<16 { #expect(try await connection.receive() == .text("synthetic-\(index)")) }
            }
            #expect(fixture.messages == 16)
        }
    }
}
#endif
