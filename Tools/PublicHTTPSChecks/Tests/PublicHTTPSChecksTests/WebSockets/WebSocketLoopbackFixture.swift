#if !os(watchOS)
import Foundation
import Network
import Synchronization

/// Verification only. Native framing, IPv4 loopback binding, bounded messages and joined stop.
final class WebSocketLoopbackFixture: Sendable {
    enum Mode: Sendable { case echo, oversize, normalClose, applicationClose, withheld, drop, missingProtocol }
    private struct State: Sendable {
        var ready = false
        var failed = false
        var stopped = false
        var connections: [UUID: NWConnection] = [:]
        var accepted = 0
        var messages = 0
    }
    private let state = Mutex(State())
    private let listener: NWListener
    private let queue = DispatchQueue(label: "NetworkKit.WebSocket.loopback")
    private let mode: Mode

    private init(mode: Mode) throws {
        self.mode = mode
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        if mode != .withheld {
            let options = NWProtocolWebSocket.Options()
            options.maximumMessageSize = 8192
            options.autoReplyPing = true
            options.setClientRequestHandler(queue) { protocols, _ in
                .init(status: .accept, subprotocol: mode == .missingProtocol ? nil : protocols.first)
            }
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        }
        listener = try NWListener(using: parameters)
    }
    static func start(mode: Mode) async throws -> WebSocketLoopbackFixture {
        let fixture = try WebSocketLoopbackFixture(mode: mode)
        fixture.listener.stateUpdateHandler = { [weak fixture] status in
            fixture?.state.withLock { s in
                switch status {
                case .ready: s.ready = true
                case .failed: s.failed = true
                case .cancelled: s.stopped = true
                default: break
                }
            }
        }
        fixture.listener.newConnectionHandler = { [weak fixture] connection in
            guard let fixture else { connection.cancel(); return }
            fixture.accept(connection)
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
            guard let port = listener.port,
                  let url = URL(string: "ws://127.0.0.1:\(port.rawValue)/synthetic") else { throw NativeFixtureFailure.startup }
            return url
        }
    }
    var accepted: Int { state.withLock { $0.accepted } }
    var messages: Int { state.withLock { $0.messages } }
    func waitForAdmission() async throws {
        for _ in 0..<200 {
            if accepted > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw NativeFixtureFailure.startup
    }
    private func accept(_ connection: NWConnection) {
        let id = UUID()
        state.withLock { $0.connections[id] = connection; $0.accepted += 1 }
        connection.stateUpdateHandler = { [weak self] status in
            switch status {
            case .cancelled, .failed: self?.state.withLock { $0.connections[id] = nil }
            default: break
            }
        }
        connection.start(queue: queue)
        if mode == .withheld {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in }
        } else { read(connection) }
    }
    private func read(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self, error == nil,
                  let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else { return }
            if metadata.opcode == .close {
                self.write(connection, bytes: Data(), opcode: .close, closeCode: .protocolCode(.normalClosure))
                return
            }
            guard metadata.opcode == .text || metadata.opcode == .binary else { self.read(connection); return }
            let count = self.state.withLock { $0.messages += 1; return $0.messages }
            guard count <= 32, (data?.count ?? 0) <= 8192 else { connection.cancel(); return }
            switch self.mode {
            case .drop:
                connection.cancel(); return
            case .normalClose:
                self.write(connection, bytes: Data("synthetic-close".utf8), opcode: .close, closeCode: .protocolCode(.normalClosure))
            case .applicationClose:
                self.write(connection, bytes: Data("synthetic-close".utf8), opcode: .close, closeCode: .applicationCode(3001))
            case .oversize:
                self.write(connection, bytes: Data(repeating: 97, count: 4097), opcode: .binary)
            default: self.write(connection, bytes: data ?? Data(), opcode: metadata.opcode)
            }
            self.read(connection)
        }
    }
    private func write(_ connection: NWConnection, bytes: Data, opcode: NWProtocolWebSocket.Opcode,
                       closeCode: NWProtocolWebSocket.CloseCode? = nil) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        if let closeCode { metadata.closeCode = closeCode }
        let context = NWConnection.ContentContext(identifier: "synthetic", metadata: [metadata])
        connection.send(content: bytes, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
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
