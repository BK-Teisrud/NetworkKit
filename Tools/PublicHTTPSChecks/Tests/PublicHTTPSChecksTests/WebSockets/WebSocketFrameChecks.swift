#if !os(watchOS)
import Foundation
import NetworkKit
import Testing

/// Separate authority required; never selected by the approved eighteen-call cohort.
@Suite(.serialized, .timeLimit(.minutes(1)), .enabled(if: ProcessInfo.processInfo.environment["NETWORKKIT_F5_FIXED_FRAMES"] == "separately-approved-eight"))
struct WebSocketFrameChecks {
    @Test(arguments: WebSocketFrameFixture.Scenario.allCases)
    func fixedFrameBoundary(_ scenario: WebSocketFrameFixture.Scenario) async throws {
        let fixture = try await WebSocketFrameFixture.start(scenario)
        do {
            let configuration = try WebSocketConfiguration(endpoint: fixture.endpoint, maximumMessageBytes: 4096,
                timeouts: .init(connect: 3, send: 3, close: 0.5), allowInsecureLoopback: true)
            var connection: WebSocketConnection?
            do {
                let opened = try await WebSocketConnection.connect(configuration: configuration)
                connection = opened
                switch scenario {
                case .fragmentedText: #expect(try await opened.receive() == .text("synthetic-🙂"))
                case .fragmentedBinary: #expect(try await opened.receive() == .binary(Data(repeating: 97, count: 4096)))
                case .fragmentedOversize:
                    do { _ = try await opened.receive(); Issue.record("Fragmented size limit not enforced") }
                    catch WebSocketError.messageTooLarge {}
                case .emptyClose:
                    #expect(try await opened.receive() == nil)
                    #expect(try await opened.receive() == nil)
                    if let info = await opened.closeInfo { #expect(info.code == nil && info.reason == nil) }
                case .invalidUTF8, .invalidCloseCode, .invalidCloseReason:
                    do { _ = try await opened.receive(); Issue.record("Invalid frame accepted") }
                    catch WebSocketError.protocolViolation {}
                case .redirect: Issue.record("Redirect accepted")
                }
                try await opened.close()

            } catch WebSocketError.handshakeRejected where scenario == .redirect {
                // Refused before application connection admission.
            } catch {
                if case WebSocketError.transport(let failure) = error {
                    print("F5 frame scenario=\(scenario.rawValue) domain=\(failure.domain) code=\(failure.code)")
                }
                if let connection { await Task.detached { try? await connection.close() }.value }
                throw error
            }
            #expect(fixture.accepted == 1)
            print("F5 extension offer scenario=\(scenario.rawValue) names=\(fixture.offeredExtensions.joined(separator: ",")) selected=none")
        } catch { #expect(await fixture.stop()); throw error }
        #expect(await fixture.stop())
    }
}
#endif
