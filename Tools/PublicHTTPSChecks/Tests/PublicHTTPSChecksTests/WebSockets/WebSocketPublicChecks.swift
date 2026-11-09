#if !os(watchOS)
import Foundation
import NetworkKit
import Testing

private enum WebSocketProbeFailure: Error { case receiveDeadline }

/// Opt-in only: one explicit invocation authorizes at most three SDK connect calls.
/// No retries, credentials, arbitrary URLs or automatic CI inclusion.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["NETWORKKIT_F5_PUBLIC_WSS"] == "approved-mac-three"))
struct WebSocketPublicChecks {
    private func receive(_ connection: WebSocketConnection) async throws -> WebSocketMessage? {
        try await withThrowingTaskGroup(of: WebSocketMessage?.self) { group in
            group.addTask { try await connection.receive() }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw WebSocketProbeFailure.receiveDeadline
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    @Test func textAndBinaryEcho() async throws {
        let endpoint = try #require(URL(string: "wss://echo.websocket.org/"))
        let configuration = try WebSocketConfiguration(endpoint: endpoint, maximumMessageBytes: 4096,
            headers: HTTPHeaders(["X-Send-Server-Hostname": "false"]))
        let connection = try await WebSocketConnection.connect(configuration: configuration)
        do {
            // The documented provider implementation emits one initial text frame;
            // suppressing hostname information leaves an empty frame, not no frame.
            #expect(try await receive(connection) == .text(""))
            let text = WebSocketMessage.text("networkkit-f5-synthetic")
            try await connection.send(text)
            #expect(try await receive(connection) == text)
            let binary = WebSocketMessage.binary(Data([0, 1, 127, 128, 255]))
            try await connection.send(binary)
            #expect(try await receive(connection) == binary)
            try await connection.close()
        } catch {
            await Task.detached { try? await connection.close() }.value
            throw error
        }
    }

    @Test func selfSignedCertificateRejected() async throws {
        try await rejectedTLS("wss://self-signed.badssl.com/")
    }
    @Test func wrongHostnameRejected() async throws {
        try await rejectedTLS("wss://wrong.host.badssl.com/")
    }
    private func rejectedTLS(_ address: String) async throws {
        let configuration = try WebSocketConfiguration(endpoint: #require(URL(string: address)), maximumMessageBytes: 4096)
        do {
            let unexpected = try await WebSocketConnection.connect(configuration: configuration)
            try? await unexpected.close()
            Issue.record("Invalid TLS endpoint unexpectedly opened")
        } catch WebSocketError.transport(let failure) {
            // TLS-layer rejection only: -1200 does not identify the exact certificate defect.
            // Timeout/DNS/generic upgrade errors are not accepted.
            #expect(failure.domain == NSURLErrorDomain)
            print("F5 negative TLS domain=\(failure.domain) code=\(failure.code)")
            #expect([-1200, -1201, -1202, -1203, -1204].contains(failure.code))
        }
    }
}
#endif
