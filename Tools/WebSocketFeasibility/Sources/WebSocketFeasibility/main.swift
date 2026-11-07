import Foundation
import Network
import Synchronization

// Blocking waits are only for this standalone finite probe, never an SDK design.
final class Event<Value: Sendable>: Sendable {
    private let value = Mutex<Value?>(nil)
    private let semaphore = DispatchSemaphore(value: 0)
    func resolve(_ newValue: Value) {
        let first = value.withLock { stored in
            guard stored == nil else { return false }
            stored = newValue
            return true
        }
        if first { semaphore.signal() }
    }
    func wait(_ seconds: Double) -> Value? {
        if let ready = value.withLock({ $0 }) { return ready }
        guard semaphore.wait(timeout: .now() + seconds) == .success else { return nil }
        return value.withLock { $0 }
    }
}

struct Observation: Codable, Sendable {
    var candidate: String
    var scenario: String
    var passed = false
    var connections = 0
    var handshakes = 0
    var receivedMessages = 0
    var sentBytes = 0
    var receivedBytes = 0
    var headerMatched = false
    var protocolMatched = false
    var terminalObserved = false
    var fixtureStopped = false
    var detail = ""
}

struct FixtureState: Sendable {
    var connections: [NWConnection] = []
    var handshakes = 0
    var received = 0
    var sentBytes = 0
    var headerMatched = false
    var protocolMatched = false
}

final class Ledger: Sendable {
    let value = Mutex(FixtureState())
}

final class Fixture: Sendable {
    let listener: NWListener
    let state = Ledger()
    let ready = Event<Bool>()
    let accepted = Event<Bool>()
    let stopped = Event<Bool>()
    let connectionsFinished = DispatchGroup()
    let queue = DispatchQueue(label: "networkkit.feasibility.fixture")
    let mode: String

    init(mode: String) throws {
        self.mode = mode
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        if mode != "withheld" {
            let websocket = NWProtocolWebSocket.Options()
            websocket.maximumMessageSize = 128 * 1024
            websocket.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
            // Native handshake parsing/framing; no custom HTTP/WebSocket implementation.
            websocket.setClientRequestHandler(queue) { [state] protocols, headers in
                state.value.withLock { s in
                    s.handshakes += 1
                    s.protocolMatched = protocols.contains("networkkit.synthetic.v1")
                    s.headerMatched = headers.contains {
                        $0.name.lowercased() == "x-networkkit-synthetic" && $0.value == "fixture-A"
                    }
                }
                return .init(status: .accept, subprotocol: protocols.contains("networkkit.synthetic.v1") ? "networkkit.synthetic.v1" : nil)
            }
        }
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [ready, stopped] state in
            switch state {
            case .ready: ready.resolve(true)
            case .failed: ready.resolve(false)
            case .cancelled: stopped.resolve(true)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
    }

    func accept(_ connection: NWConnection) {
        state.value.withLock { $0.connections.append(connection) }
        connectionsFinished.enter()
        let finished = Mutex(false)
        connection.stateUpdateHandler = { [connectionsFinished, accepted, mode] state in
            switch state {
            case .ready:
                accepted.resolve(true)
                if mode == "drop" { connection.cancel() }
            case .cancelled:
                let first = finished.withLock { value in
                    if value { return false }; value = true; return true
                }
                if first { connectionsFinished.leave() }
            default: break
            }
        }
        connection.start(queue: queue)
        if mode == "withheld" {
            // Consume a bounded handshake prefix without answering or parsing it.
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in }
        } else {
            receive(connection)
        }
    }

    func receive(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self, error == nil else { return }
            guard let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else { return }
            if metadata.opcode == .close {
                self.send(connection, data: Data(), opcode: .close)
                return
            }
            guard metadata.opcode == .text || metadata.opcode == .binary else {
                self.receive(connection); return
            }
            self.state.value.withLock { $0.received += 1 }
            if self.mode == "peer-close" {
                self.send(connection, data: Data(), opcode: .close)
            } else if self.mode.hasPrefix("size-") {
                let size = Int(self.mode.dropFirst(5)) ?? 0
                self.send(connection, data: Data(repeating: 0x61, count: size), opcode: .binary)
            } else {
                self.send(connection, data: data ?? Data(), opcode: metadata.opcode)
            }
            self.receive(connection)
        }
    }

    func send(_ connection: NWConnection, data: Data, opcode: NWProtocolWebSocket.Opcode) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        if opcode == .close { metadata.closeCode = .protocolCode(.normalClosure) }
        let context = NWConnection.ContentContext(identifier: "synthetic", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [state] error in
            if error == nil { state.value.withLock { $0.sentBytes += data.count } }
        })
    }

    func stop() -> Bool {
        listener.cancel()
        // Listener cancellation stops new admissions on its serial queue before snapshotting.
        let listenerStopped = stopped.wait(2) == true
        let snapshot = state.value.withLock { $0.connections }
        snapshot.forEach { $0.cancel() }
        let joined = connectionsFinished.wait(timeout: .now() + 2) == .success
        return listenerStopped && joined
    }
}

struct Received: Sendable {
    var data: Data?
    var closed = false
    var failed = false
}

protocol ProbeClient: AnyObject {
    func open() -> Bool
    func send(_ data: Data, text: Bool) -> Bool
    func receive() -> Event<Received>
    func stop() -> Bool
    func peerClosedNormally() -> Bool
}

final class NetworkClient: ProbeClient, Sendable {
    let connection: NWConnection
    let ready = Event<Bool>()
    let terminal = Event<Bool>()
    let normalClose = Event<Bool>()
    let queue = DispatchQueue(label: "networkkit.feasibility.network-client")

    init(url: URL) {
        let parameters = NWParameters.tcp
        let websocket = NWProtocolWebSocket.Options()
        websocket.maximumMessageSize = 64 * 1024
        websocket.autoReplyPing = true
        websocket.setSubprotocols(["networkkit.synthetic.v1"])
        websocket.setAdditionalHeaders([("X-NetworkKit-Synthetic", "fixture-A")])
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
        connection = NWConnection(to: .url(url), using: parameters)
        connection.stateUpdateHandler = { [ready, terminal] state in
            switch state {
            case .ready: ready.resolve(true)
            case .failed: ready.resolve(false); terminal.resolve(true)
            case .cancelled: ready.resolve(false); terminal.resolve(true)
            default: break
            }
        }
        connection.start(queue: queue)
    }
    func open() -> Bool { ready.wait(10) == true }
    func send(_ data: Data, text: Bool) -> Bool {
        let completed = Event<Bool>()
        let metadata = NWProtocolWebSocket.Metadata(opcode: text ? .text : .binary)
        connection.send(content: data, contentContext: .init(identifier: "synthetic", metadata: [metadata]), isComplete: true, completion: .contentProcessed { error in completed.resolve(error == nil) })
        return completed.wait(2) == true
    }
    func receive() -> Event<Received> {
        let event = Event<Received>()
        connection.receiveMessage { [normalClose] data, context, _, error in
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            if metadata?.opcode == .close { normalClose.resolve(metadata?.closeCode == .protocolCode(.normalClosure)) }
            event.resolve(.init(data: data, closed: metadata?.opcode == .close, failed: error != nil))
        }
        return event
    }
    func stop() -> Bool { connection.cancel(); return terminal.wait(2) == true }
    func peerClosedNormally() -> Bool { normalClose.wait(1) == true }
}

final class SessionObserver: NSObject, URLSessionWebSocketDelegate, Sendable {
    let ready = Event<Bool>()
    let closed = Event<Bool>()
    let normalClose = Event<Bool>()
    let invalidated = Event<Bool>()
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        ready.resolve(`protocol` == "networkkit.synthetic.v1")
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) { normalClose.resolve(closeCode == .normalClosure); closed.resolve(true) }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) { ready.resolve(false); closed.resolve(true) }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) { invalidated.resolve(true) }
}

final class SessionClient: ProbeClient {
    let observer: SessionObserver
    let session: URLSession
    let task: URLSessionWebSocketTask
    init(url: URL) {
        observer = SessionObserver()
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.setValue("networkkit.synthetic.v1", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.setValue("fixture-A", forHTTPHeaderField: "X-NetworkKit-Synthetic")
        task = session.webSocketTask(with: request)
        task.maximumMessageSize = 64 * 1024
        task.resume()
    }
    func open() -> Bool { observer.ready.wait(10) == true }
    func send(_ data: Data, text: Bool) -> Bool {
        let event = Event<Bool>()
        task.send(text ? .string(String(decoding: data, as: UTF8.self)) : .data(data)) { error in event.resolve(error == nil) }
        return event.wait(2) == true
    }
    func receive() -> Event<Received> {
        let event = Event<Received>()
        task.receive { result in
            switch result {
            case .success(.data(let data)): event.resolve(.init(data: data))
            case .success(.string(let text)): event.resolve(.init(data: Data(text.utf8)))
            case .failure: event.resolve(.init(failed: true))
            @unknown default: event.resolve(.init(failed: true))
            }
        }
        return event
    }
    func peerClosedNormally() -> Bool { observer.normalClose.wait(1) == true }
    func stop() -> Bool {
        task.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
        return observer.closed.wait(2) == true && observer.invalidated.wait(2) == true
    }
}

func probe(candidate: String, scenario: String) throws -> Observation {
    var result = Observation(candidate: candidate, scenario: scenario)
    let mode = scenario.hasPrefix("size-") ? scenario : (scenario == "withheld" || scenario == "peer-close" || scenario == "drop" ? scenario : "echo")
    let fixture = try Fixture(mode: mode)
    guard fixture.ready.wait(2) == true, let port = fixture.listener.port else {
        result.detail = "fixture-not-ready"; result.fixtureStopped = fixture.stop(); return result
    }
    let url = URL(string: "ws://127.0.0.1:\(port.rawValue)/synthetic?value=nonsecret")!
    let client: any ProbeClient = candidate == "network" ? NetworkClient(url: url) : SessionClient(url: url)
    let opened = client.open()
    if scenario == "withheld" {
        result.passed = !opened && fixture.accepted.wait(1) == true
        result.detail = "handshake-withheld; local open wait bounded, not SDK deadline behavior"
    } else if scenario == "drop" {
        result.passed = !opened || client.receive().wait(2)?.failed == true
        result.detail = "peer-cancel; not a TCP reset injection"
    } else if opened {
        if scenario == "cancel" {
            let pending = client.receive()
            result.terminalObserved = client.stop()
            result.passed = pending.wait(2)?.failed == true && result.terminalObserved
            result.detail = "pending-receive-cancelled"
        } else if scenario == "shutdown" {
            result.terminalObserved = client.stop()
            result.passed = result.terminalObserved && client.stop()
            result.detail = "immediate-idempotent-stop; no graceful-peer-ack claim"
        } else {
            let payload = Data(repeating: 0x61, count: 1024)
            let received = client.receive()
            let sent = client.send(payload, text: scenario == "exchange")
            result.sentBytes = sent ? payload.count : 0
            if scenario == "paused-consumer" {
                // No additional receive is admitted; peer/OS buffering is not bounded by this probe.
                Thread.sleep(forTimeInterval: 0.25)
            }
            if let message = received.wait(2) {
                result.receivedBytes = message.data?.count ?? 0
                if scenario == "peer-close" {
                    result.passed = sent && (message.closed || message.failed) && client.peerClosedNormally()
                    result.detail = "native-normal-peer-close-observed"
                } else if scenario == "size-65537" {
                    result.passed = sent && (message.failed || message.closed) && message.data == nil
                    result.detail = "oversized-message-rejected"
                } else {
                    let expected = scenario.hasPrefix("size-") ? Int(scenario.dropFirst(5))! : payload.count
                    result.passed = sent && !message.failed && !message.closed && message.data == Data(repeating: 0x61, count: expected)
                    result.detail = "exact-synthetic-bytes"
                    if scenario == "exchange" && result.passed {
                        // Pause before admitting the second receive, not after its callback.
                        let secondSent = client.send(payload, text: false)
                        Thread.sleep(forTimeInterval: 0.25)
                        let second = client.receive().wait(2)
                        result.passed = secondSent && second?.data == payload && second?.failed == false
                        result.sentBytes += secondSent ? payload.count : 0
                        result.receivedBytes += second?.data?.count ?? 0
                        result.detail = "text-and-binary-exact; one 250ms consumer pause; no buffering-cap claim"
                    }
                }
            } else { result.detail = "receive-harness-timeout" }
        }
    } else { result.detail = "open-failed-or-harness-timeout" }
    if !result.terminalObserved { result.terminalObserved = client.stop() }
    result.fixtureStopped = fixture.stop()
    let snapshot = fixture.state.value.withLock { $0 }
    result.connections = snapshot.connections.count
    result.handshakes = snapshot.handshakes
    result.receivedMessages = snapshot.received
    result.headerMatched = snapshot.headerMatched
    result.protocolMatched = snapshot.protocolMatched
    result.passed = result.passed && result.terminalObserved && result.fixtureStopped && result.connections == 1
    if scenario != "withheld" && scenario != "drop" {
        result.passed = result.passed && result.handshakes == 1 && result.headerMatched && result.protocolMatched
    }
    return result
}

let allowedScenarios = ["exchange", "size-65535", "size-65536", "size-65537", "cancel", "shutdown", "peer-close", "withheld"]
let arguments = CommandLine.arguments
if arguments.count != 3 || !["network", "session"].contains(arguments[1]) || !allowedScenarios.contains(arguments[2]) {
    fputs("usage: WebSocketFeasibility network|session scenario\n", stderr)
    exit(2)
}
do {
    let result = try probe(candidate: arguments[1], scenario: arguments[2])
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(result), as: UTF8.self))
    exit(result.passed ? 0 : 1)
} catch {
    fputs("fixture-construction-failed\n", stderr)
    exit(1)
}
