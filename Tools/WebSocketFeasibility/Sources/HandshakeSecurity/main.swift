import Foundation
import Network
import Security
import Synchronization

final class Event<T: Sendable>: Sendable {
    let value = Mutex<T?>(nil)
    let semaphore = DispatchSemaphore(value: 0)
    func set(_ next: T) {
        let first = value.withLock { v in
            guard v == nil else { return false }; v = next; return true
        }
        if first { semaphore.signal() }
    }
    func wait(_ seconds: Double) -> T? {
        if let v = value.withLock({ $0 }) { return v }
        guard semaphore.wait(timeout: .now() + seconds) == .success else { return nil }
        return value.withLock { $0 }
    }
}

struct State: Sendable, Codable {
    var candidate = ""
    var scenario = ""
    var opened = false
    var openWaitExpired = false
    var selectedProtocol: String?
    var nativeErrorDomain: String?
    var nativeErrorCode: Int?
    var trustEvaluation: Bool?
    var negotiatedTLSVersion: UInt16?
    var redirectCallbacks = 0
    var echoText = false
    var echoBinary = false
    var stopped = false
    var terminalSeenBeforeCleanup = false
    var localConnections = 0
    var redirectTargetConnections = 0
    var requestTargetMatched = false
    var hostMatched = false
    var syntheticHeaderMatched = false
    var clientOfferedProtocol = false
    var fixtureStopped = false
    var policySatisfied: Bool?
    var outcome = "inconclusive"
}

final class Store: Sendable { let value = Mutex(State()) }
let referenceProtocol = "networkkit.synthetic.v1"

final class Fixture: Sendable {
    let listener: NWListener
    let queue = DispatchQueue(label: "networkkit.security.fixture")
    let ready = Event<Bool>()
    let cancelled = Event<Bool>()
    let connected = Event<Bool>()
    let connections = Mutex<[NWConnection]>([])
    let finished = DispatchGroup()
    let mode: String
    let store: Store
    let targetPort: UInt16?

    init(mode: String, store: Store, targetPort: UInt16? = nil) throws {
        self.mode = mode; self.store = store; self.targetPort = targetPort
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        if ["matched", "missing", "mismatched"].contains(mode) {
            let websocket = NWProtocolWebSocket.Options()
            websocket.maximumMessageSize = 65536
            websocket.setClientRequestHandler(queue) { protocols, headers in
                store.value.withLock {
                    $0.clientOfferedProtocol = protocols.contains(referenceProtocol)
                    $0.syntheticHeaderMatched = headers.contains { $0.name.lowercased() == "x-networkkit-synthetic" && $0.value == "fixture-A" }
                }
                let selected: String? = mode == "missing" ? nil : (mode == "mismatched" ? "unoffered.synthetic.v1" : referenceProtocol)
                return .init(status: .accept, subprotocol: selected)
            }
            parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
        }
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [ready, cancelled] state in
            switch state {
            case .ready: ready.set(true)
            case .failed: ready.set(false)
            case .cancelled: cancelled.set(true)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
    }

    func accept(_ connection: NWConnection) {
        connections.withLock { $0.append(connection) }
        store.value.withLock { state in
            if mode == "target" { state.redirectTargetConnections += 1 }
            else { state.localConnections += 1 }
        }
        connected.set(true)
        finished.enter()
        let left = Mutex(false)
        connection.stateUpdateHandler = { [finished] state in
            if case .cancelled = state {
                let first = left.withLock { v in if v { return false }; v = true; return true }
                if first { finished.leave() }
            }
        }
        connection.start(queue: queue)
        if !["matched", "missing", "mismatched"].contains(mode) {
            readHeader(connection, prefix: Data())
        }
    }

    func readHeader(_ connection: NWConnection, prefix: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384 - prefix.count) { [weak self] data, _, complete, error in
            guard let self, error == nil, let data else { return }
            var bytes = prefix; bytes.append(data)
            if bytes.range(of: Data([13, 10, 13, 10])) != nil {
                // Observation of a bounded synthetic request, not a general HTTP parser.
                let lines = String(decoding: bytes, as: UTF8.self).components(separatedBy: "\r\n")
                let port = self.listener.port!.rawValue
                self.store.value.withLock { s in
                    if self.mode != "target" {
                        s.requestTargetMatched = lines.first == "GET /synthetic/path?item=alpha%20beta&n=7 HTTP/1.1"
                        s.hostMatched = lines.contains { $0.lowercased() == "host: 127.0.0.1:\(port)" }
                        s.syntheticHeaderMatched = lines.contains { $0.lowercased() == "x-networkkit-synthetic: fixture-a" }
                    }
                }
                if self.mode == "cancel-opening" { return }
                let response: String
                if self.mode == "redirect", let target = self.targetPort {
                    response = "HTTP/1.1 302 Found\r\nLocation: ws://127.0.0.1:\(target)/denied\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                } else {
                    response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                }
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            } else if !complete && bytes.count < 16384 {
                self.readHeader(connection, prefix: bytes)
            } else { connection.cancel() }
        }
    }

    func stop() -> Bool {
        listener.cancel()
        let stopped = cancelled.wait(2) == true
        connections.withLock { $0 }.forEach { $0.cancel() }
        return stopped && finished.wait(timeout: .now() + 2) == .success
    }
}

struct Message: Sendable { var data: Data?; var text: Bool; var failed: Bool }
protocol Client: AnyObject {
    func open(_ seconds: Double) -> Bool
    func echo(_ data: Data, text: Bool) -> Bool
    func stop() -> Bool
}

final class NetworkProbe: Client, Sendable {
    let connection: NWConnection
    let store: Store
    let ready = Event<Bool>()
    let terminal = Event<Bool>()
    let queue = DispatchQueue(label: "networkkit.security.network")

    init(url: URL, offerProtocol: Bool, syntheticHeader: Bool, store: Store) {
        self.store = store
        let parameters = url.scheme == "wss" ? NWParameters.tls : NWParameters.tcp
        let websocket = NWProtocolWebSocket.Options()
        websocket.maximumMessageSize = 65536
        websocket.autoReplyPing = true
        if offerProtocol { websocket.setSubprotocols([referenceProtocol]) }
        if syntheticHeader { websocket.setAdditionalHeaders([("X-NetworkKit-Synthetic", "fixture-A")]) }
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
        connection = NWConnection(to: .url(url), using: parameters)
        connection.stateUpdateHandler = { [weak self, ready, terminal, store] state in
            if let metadata = self?.connection.metadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                store.value.withLock { $0.selectedProtocol = metadata.selectedSubprotocol }
            }
            if let metadata = self?.connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata {
                let version = sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata.securityProtocolMetadata)
                if version.rawValue != 0 { store.value.withLock { $0.negotiatedTLSVersion = version.rawValue } }
            }
            switch state {
            case .ready: store.value.withLock { $0.opened = true }; ready.set(true)
            case .failed(let error):
                store.value.withLock {
                    switch error {
                    case .tls(let code): $0.nativeErrorDomain = "NWError.tls"; $0.nativeErrorCode = Int(code)
                    case .posix(let code): $0.nativeErrorDomain = "NWError.posix"; $0.nativeErrorCode = Int(code.rawValue)
                    case .dns(let code): $0.nativeErrorDomain = "NWError.dns"; $0.nativeErrorCode = Int(code)
                    default: $0.nativeErrorDomain = "NWError.other"
                    }
                }
                ready.set(false); terminal.set(true)
            case .cancelled: ready.set(false); terminal.set(true)
            default: break
            }
        }
        connection.start(queue: queue)
    }
    func open(_ seconds: Double) -> Bool {
        let result = ready.wait(seconds)
        if result == nil { store.value.withLock { $0.openWaitExpired = true } }
        return result == true
    }
    func echo(_ data: Data, text: Bool) -> Bool {
        let received = Event<Message>()
        connection.receiveMessage { bytes, context, _, error in
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            received.set(.init(data: bytes, text: metadata?.opcode == .text, failed: error != nil))
        }
        let sent = Event<Bool>()
        let context = NWConnection.ContentContext(identifier: "synthetic", metadata: [NWProtocolWebSocket.Metadata(opcode: text ? .text : .binary)])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { sent.set($0 == nil) })
        guard sent.wait(2) == true, let message = received.wait(2) else { return false }
        return !message.failed && message.text == text && message.data == data
    }
    func stop() -> Bool { connection.cancel(); return terminal.wait(2) == true }
}

final class SessionObserver: NSObject, URLSessionWebSocketDelegate, Sendable {
    let store: Store
    let ready = Event<Bool>()
    let invalidated = Event<Bool>()
    init(store: Store) { self.store = store }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        store.value.withLock { $0.opened = true; $0.selectedProtocol = `protocol` }; ready.set(true)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        store.value.withLock { $0.redirectCallbacks += 1 }; completionHandler(nil)
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            // Diagnostic only: preserve native default handling, do not accept a credential.
            let trusted = SecTrustEvaluateWithError(trust, nil)
            store.value.withLock { $0.trustEvaluation = trusted }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            let native = error as NSError
            store.value.withLock { $0.nativeErrorDomain = native.domain; $0.nativeErrorCode = native.code }
        }
        ready.set(false)
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) { invalidated.set(true) }
}

final class SessionProbe: Client {
    let observer: SessionObserver
    let task: URLSessionWebSocketTask
    let session: URLSession
    init(url: URL, offerProtocol: Bool, syntheticHeader: Bool, store: Store) {
        observer = SessionObserver(store: store)
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        session = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        var request = URLRequest(url: url)
        if offerProtocol { request.setValue(referenceProtocol, forHTTPHeaderField: "Sec-WebSocket-Protocol") }
        if syntheticHeader { request.setValue("fixture-A", forHTTPHeaderField: "X-NetworkKit-Synthetic") }
        task = session.webSocketTask(with: request)
        task.maximumMessageSize = 65536
        task.resume()
    }
    func open(_ seconds: Double) -> Bool {
        let value = observer.ready.wait(seconds)
        if value == nil { observer.store.value.withLock { $0.openWaitExpired = true } }
        return value == true
    }
    func echo(_ data: Data, text: Bool) -> Bool {
        let received = Event<Message>()
        task.receive { result in
            switch result {
            case .success(.string(let string)): received.set(.init(data: Data(string.utf8), text: true, failed: false))
            case .success(.data(let bytes)): received.set(.init(data: bytes, text: false, failed: false))
            default: received.set(.init(data: nil, text: false, failed: true))
            }
        }
        let sent = Event<Bool>()
        task.send(text ? .string(String(decoding: data, as: UTF8.self)) : .data(data)) { sent.set($0 == nil) }
        guard sent.wait(2) == true, let message = received.wait(2) else { return false }
        return !message.failed && message.text == text && message.data == data
    }
    func stop() -> Bool {
        task.cancel(with: .normalClosure, reason: nil); session.invalidateAndCancel()
        return observer.invalidated.wait(2) == true
    }
}

func probe(candidate: String, scenario: String) throws -> State {
    let store = Store()
    store.value.withLock { $0.candidate = candidate; $0.scenario = scenario }
    let external = ["echo", "tls-valid", "tls-self-signed", "tls-wrong-host"].contains(scenario)
    var fixture: Fixture?
    var target: Fixture?
    let url: URL
    if external {
        let addresses = ["echo": "wss://ws.postman-echo.com/raw", "tls-valid": "wss://sha256.badssl.com/", "tls-self-signed": "wss://self-signed.badssl.com/", "tls-wrong-host": "wss://wrong.host.badssl.com/"]
        url = URL(string: addresses[scenario]!)!
    } else {
        if scenario == "redirect" {
            target = try Fixture(mode: "target", store: store)
            guard target?.ready.wait(2) == true else { throw ProbeFailure.fixture }
        }
        fixture = try Fixture(mode: scenario, store: store, targetPort: target?.listener.port?.rawValue)
        guard fixture?.ready.wait(2) == true, let port = fixture?.listener.port else { throw ProbeFailure.fixture }
        url = URL(string: "ws://127.0.0.1:\(port.rawValue)/synthetic/path?item=alpha%20beta&n=7")!
    }
    let client: any Client = candidate == "network" ? NetworkProbe(url: url, offerProtocol: !external, syntheticHeader: !external, store: store) : SessionProbe(url: url, offerProtocol: !external, syntheticHeader: !external, store: store)
    if scenario == "cancel-opening" {
        let connected = fixture?.connected.wait(2) == true
        let firstStop = client.stop()
        let lateOpen = client.open(0.25)
        store.value.withLock { $0.policySatisfied = connected && firstStop && !lateOpen && !$0.opened; $0.outcome = "opening-cancelled-no-late-open-in-bounded-window" }
    } else {
        let opened = client.open(10)
        if scenario == "echo" && opened {
            let text = client.echo(Data("networkkit-synthetic".utf8), text: true)
            let binary = client.echo(Data([1, 2, 3, 4]), text: false)
            store.value.withLock { $0.echoText = text; $0.echoBinary = binary; $0.outcome = text && binary ? "wss-echo-exact" : "wss-open-echo-incomplete" }
        }
        if !external {
            // Bounded observation window for unexpected native redirect target contact.
            if scenario == "redirect" { Thread.sleep(forTimeInterval: 0.25) }
            store.value.withLock { s in
                switch scenario {
                case "target-observer": s.policySatisfied = !opened && s.requestTargetMatched && s.hostMatched && s.syntheticHeaderMatched; s.outcome = "observed-request-fixed-rejection"
                case "matched": s.policySatisfied = opened && s.selectedProtocol == referenceProtocol && s.clientOfferedProtocol && s.syntheticHeaderMatched; s.outcome = "matched-protocol-observation"
                case "missing", "mismatched": s.policySatisfied = !opened && !s.openWaitExpired && s.clientOfferedProtocol && s.syntheticHeaderMatched && s.nativeErrorDomain != nil; s.outcome = opened ? "native-open-without-required-matching-protocol" : "native-rejected-protocol-case"
                case "reject": s.policySatisfied = !opened && s.requestTargetMatched; s.outcome = "fixed-handshake-rejected"
                case "redirect": s.policySatisfied = !opened && s.redirectTargetConnections == 0; s.outcome = s.redirectTargetConnections == 0 ? "no-redirect-target-contact" : "unexpected-redirect-target-contact"
                default: break
                }
            }
        }
    }
    // Snapshot native termination before our mandatory cleanup to distinguish own cancel.
    store.value.withLock { $0.terminalSeenBeforeCleanup = $0.nativeErrorDomain != nil }
    let stopped = client.stop()
    let fixtureStopped = fixture?.stop() ?? true
    let targetStopped = target?.stop() ?? true
    store.value.withLock { s in
        s.stopped = stopped; s.fixtureStopped = fixtureStopped && targetStopped
        if scenario == "echo" { s.policySatisfied = s.opened && s.echoText && s.echoBinary; if !s.opened { s.outcome = "wss-open-failed-or-timeout" } }
        if scenario.hasPrefix("tls-") {
            // Never label a generic failed upgrade a certificate proof.
            if s.trustEvaluation == true || (s.negotiatedTLSVersion ?? 0) != 0 { s.outcome = "tls-observed-upgrade-not-proven" }
            else if s.trustEvaluation == false || s.nativeErrorDomain == "NWError.tls" { s.outcome = "native-trust-or-tls-rejection-observed" }
            else { s.outcome = "tls-attribution-inconclusive" }
            s.policySatisfied = nil
        }
    }
    return store.value.withLock { $0 }
}
enum ProbeFailure: Error { case fixture }
let args = CommandLine.arguments
let allowed = ["target-observer", "matched", "missing", "mismatched", "reject", "redirect", "cancel-opening", "echo", "tls-valid", "tls-self-signed", "tls-wrong-host"]
guard args.count == 3, ["network", "session"].contains(args[1]), allowed.contains(args[2]) else {
    fputs("usage: HandshakeSecurity network|session approved-scenario\n", stderr); exit(2)
}
do {
    let result = try probe(candidate: args[1], scenario: args[2])
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(result), as: UTF8.self))
    // A recorded negative/incomplete feasibility result is not a harness crash.
    exit(result.stopped && result.fixtureStopped ? 0 : 1)
} catch {
    fputs("fixture-construction-failed\n", stderr); exit(1)
}
