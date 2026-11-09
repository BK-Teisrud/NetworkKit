#if !os(watchOS)
import CryptoKit
import Foundation
import Network
import Synchronization

/// Test-only fixed responses, not a reusable server or production transport.
/// Exactly one accepted TCP connection, a 4096-byte handshake cap, no LAN exposure.
final class WebSocketFrameFixture: Sendable {
    enum Scenario: String, CaseIterable, Sendable {
        case fragmentedText, fragmentedBinary, fragmentedOversize, invalidUTF8
        case emptyClose, invalidCloseCode, invalidCloseReason, redirect
    }
    private struct State: Sendable {
        var ready = false
        var stopped = false
        var failed = false
        var accepted = 0
        var offeredExtensions: [String] = []
        var connections: [UUID: NWConnection] = [:]
    }
    private let state = Mutex(State())
    private let listener: NWListener
    private let queue = DispatchQueue(label: "NetworkKit.fixed-frame.fixture")
    private let scenario: Scenario
    private init(_ scenario: Scenario) throws {
        self.scenario = scenario
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }
    static func start(_ scenario: Scenario) async throws -> WebSocketFrameFixture {
        let fixture = try WebSocketFrameFixture(scenario)
        fixture.listener.stateUpdateHandler = { [weak fixture] value in
            fixture?.state.withLock { s in
                switch value {
                case .ready: s.ready = true
                case .failed: s.failed = true
                case .cancelled: s.stopped = true
                default: break
                }
            }
        }
        fixture.listener.newConnectionHandler = { [weak fixture] connection in
            guard let fixture else { connection.cancel(); return }
            let id = UUID()
            let allowed = fixture.state.withLock { s in
                s.accepted += 1
                guard s.accepted == 1 else { return false }
                s.connections[id] = connection; return true
            }
            guard allowed else { connection.cancel(); return }
            connection.stateUpdateHandler = { [weak fixture] value in
                switch value {
                case .cancelled, .failed: fixture?.state.withLock { $0.connections[id] = nil }
                default: break
                }
            }
            connection.start(queue: fixture.queue)
            fixture.read(connection, previous: Data())
        }
        fixture.listener.start(queue: fixture.queue)
        do {
            for _ in 0..<200 {
                if fixture.state.withLock({ $0.ready }), fixture.listener.port != nil { return fixture }
                if fixture.state.withLock({ $0.failed }) { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            throw NativeFixtureFailure.startup
        } catch { _ = await fixture.stop(); throw error }
    }
    var endpoint: URL {
        get throws {
            guard let port = listener.port, let url = URL(string: "ws://127.0.0.1:\(port.rawValue)/fixed") else {
                throw NativeFixtureFailure.startup
            }
            return url
        }
    }
    var accepted: Int { state.withLock { $0.accepted } }
    var offeredExtensions: [String] { state.withLock { $0.offeredExtensions } }
    private func read(_ connection: NWConnection, previous: Data) {
        guard previous.count < 4096 else { connection.cancel(); return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096 - previous.count) { [weak self] bytes, _, ended, error in
            guard let self, error == nil else { connection.cancel(); return }
            var buffer = previous
            if let bytes { buffer.append(bytes) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                self.respond(connection, header: Data(buffer[..<end.upperBound]))
            } else if !ended { self.read(connection, previous: buffer) }
            else { connection.cancel() }
        }
    }
    private func respond(_ connection: NWConnection, header: Data) {
        guard let text = String(data: header, encoding: .utf8), text.hasPrefix("GET /fixed HTTP/1.1\r\n"),
              let line = text.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("sec-websocket-key:") }),
              let value = line.split(separator: ":", maxSplits: 1).last else { connection.cancel(); return }
        let extensionLine = text.components(separatedBy: "\r\n").first {
            $0.lowercased().hasPrefix("sec-websocket-extensions:")
        }
        let extensionValue = extensionLine?.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
        let names = extensionValue.split(separator: ",").compactMap { part -> String? in
            guard let name = part.split(separator: ";").first else { return nil }
            let token = name.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty, token.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
            }) else { return nil }
            return token
        }
        state.withLock { $0.offeredExtensions = names }
        let key = value.trimmingCharacters(in: .whitespaces)
        guard Data(base64Encoded: key)?.count == 16 else { connection.cancel(); return }
        if scenario == .redirect {
            guard let port = listener.port else { connection.cancel(); return }
            let reply = Data("HTTP/1.1 302 Found\r\nLocation: ws://127.0.0.1:\(port.rawValue)/forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
            connection.send(content: reply, contentContext: .finalMessage, isComplete: true,
                completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
        let accept = Data(digest).base64EncodedString()
        var reply = Data("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n".utf8)
        reply.append(Self.frames(scenario))
        connection.send(content: reply, completion: .contentProcessed { _ in })
    }
    static func frames(_ scenario: Scenario) -> Data {
        switch scenario {
        case .fragmentedText:
            let bytes = Data("synthetic-🙂".utf8), cut = bytes.count - 2
            return frame(1, Data(bytes.prefix(cut)), final: false) + frame(0, Data(bytes.suffix(2)))
        case .fragmentedBinary: return frame(2, Data(repeating: 97, count: 2048), final: false) + frame(0, Data(repeating: 97, count: 2048))
        case .fragmentedOversize: return frame(2, Data(repeating: 97, count: 2048), final: false) + frame(0, Data(repeating: 97, count: 2049))
        case .invalidUTF8: return frame(1, Data([255]))
        case .emptyClose: return frame(8, Data())
        case .invalidCloseCode: return frame(8, Data([3, 237])) // Forbidden wire status 1005.
        case .invalidCloseReason: return frame(8, Data([3, 232, 255])) // 1000 plus invalid UTF-8.
        case .redirect: return Data()
        }
    }
    private static func frame(_ opcode: UInt8, _ bytes: Data, final: Bool = true) -> Data {
        precondition(bytes.count <= 4097)
        var result = Data([(final ? 128 : 0) | opcode])
        if bytes.count < 126 { result.append(UInt8(bytes.count)) }
        else { result.append(contentsOf: [126, UInt8(bytes.count >> 8), UInt8(bytes.count & 255)]) }
        result.append(bytes); return result
    }
    func stop() async -> Bool {
        listener.cancel()
        return await Task.detached { [self] in
            for _ in 0..<200 {
                let snapshot = state.withLock { ($0.stopped, Array($0.connections.values)) }
                snapshot.1.forEach { $0.cancel() }
                if snapshot.0 && snapshot.1.isEmpty { return true }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return false
        }.value
    }
}
#endif
