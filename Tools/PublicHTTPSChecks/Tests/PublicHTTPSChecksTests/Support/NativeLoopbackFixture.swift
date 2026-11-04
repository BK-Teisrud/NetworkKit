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

enum NativeFixtureFailure: Error { case startup, malformed, measurement }
struct NativeReply: Decodable, Sendable { let value: String }
struct NativeEndpoint<Value: Sendable>: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Value>
    let options: NetworkCallOptions
}

/// Test-only, credential-free SDK traffic. Required local endpoint prevents LAN exposure.
final class NativeLoopbackFixture: Sendable {
    private struct State {
        var ready = false
        var failed = false
        var stopped = false
        var connections: [UUID: NWConnection] = [:]
        var counts: [String: Int] = [:]
        var cookies = 0
        var credentials = 0
        var redirect: String?
        var downloadWrites = 0
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let listener: NWListener
    private let queue = DispatchQueue(label: "NetworkKit.synthetic.loopback")

    private init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    static func start() async throws -> NativeLoopbackFixture {
        let fixture = try NativeLoopbackFixture()
        fixture.listener.stateUpdateHandler = { [weak fixture] value in
            guard let fixture else { return }
            fixture.state.withLock { state in
                switch value {
                case .ready: state.ready = true
                case .failed: state.failed = true
                case .cancelled: state.stopped = true
                default: break
                }
            }
        }
        fixture.listener.newConnectionHandler = { [weak fixture] connection in
            guard let fixture else { connection.cancel(); return }
            let id = UUID()
            fixture.state.withLock { $0.connections[id] = connection }
            connection.stateUpdateHandler = { [weak fixture] value in
                if case .cancelled = value { fixture?.state.withLock { $0.connections[id] = nil } }
                if case .failed = value { fixture?.state.withLock { $0.connections[id] = nil } }
            }
            connection.start(queue: fixture.queue)
            fixture.read(connection, id: id, previous: Data())
        }
        fixture.listener.start(queue: fixture.queue)
        do {
            for _ in 0..<200 {
                if fixture.state.withLock({ $0.ready }) && fixture.listener.port != nil { return fixture }
                if fixture.state.withLock({ $0.failed }) { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            throw NativeFixtureFailure.startup
        } catch {
            _ = await fixture.stop()
            throw error
        }
    }

    var base: URL {
        get throws {
            guard let port = listener.port,
                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)") else { throw NativeFixtureFailure.startup }
            return url
        }
    }
    func redirect(to url: URL) { state.withLock { $0.redirect = url.absoluteString } }
    func count(_ path: String) -> Int { state.withLock { $0.counts[path, default: 0] } }
    var receivedCookies: Int { state.withLock { $0.cookies } }
    var receivedCredentials: Int { state.withLock { $0.credentials } }
    func contacted(_ path: String, after count: Int) async throws -> Bool {
        for _ in 0..<200 {
            if self.count(path) > count { return true }
            try await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    var downloadWrites: Int { state.withLock { $0.downloadWrites } }
    func wroteDownload(after count: Int) async throws -> Bool {
        for _ in 0..<200 {
            if downloadWrites > count { return true }
            try await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func stop() async -> Bool {
        listener.cancel()
        for connection in state.withLock({ Array($0.connections.values) }) { connection.cancel() }
        // Joined cleanup must remain observable even when the test task was cancelled.
        return await Task.detached { [self] in
            for _ in 0..<200 {
                if state.withLock({ $0.stopped && $0.connections.isEmpty }) { return true }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return false
        }.value
    }

    private func read(_ connection: NWConnection, id: UUID, previous: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            let buffer = previous + (data ?? Data())
            if buffer.count > 16384 { connection.cancel(); return }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)),
               let headers = String(data: buffer[..<end.upperBound], encoding: .utf8),
               let line = headers.components(separatedBy: "\r\n").first {
                let parts = line.split(separator: " ")
                guard parts.count >= 2 else { connection.cancel(); return }
                self.respond(connection, path: String(parts[1]), headers: headers.lowercased())
            } else if complete || error != nil { connection.cancel() }
            else { self.read(connection, id: id, previous: buffer) }
        }
    }

    private func respond(_ connection: NWConnection, path: String, headers: String) {
        let hit = state.withLock {
            $0.counts[path, default: 0] += 1
            if headers.contains("\r\ncookie:") { $0.cookies += 1 }
            if headers.contains("\r\nauthorization:") { $0.credentials += 1 }
            return $0.counts[path, default: 0]
        }
        if path == "/hold" {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in connection.cancel() }
            return
        }
        if path == "/download-hold" {
            var bytes = Data("HTTP/1.1 200 Fixture\r\nContent-Length: 1048576\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
            bytes.append(Data(repeating: 120, count: 1024))
            connection.send(content: bytes, completion: .contentProcessed { [weak self] error in
                if error == nil { self?.state.withLock { $0.downloadWrites += 1 } }
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in connection.cancel() }
            })
            return
        }
        var status = 200
        var extra = "Cache-Control: no-store\r\n"
        var body = Data(#"{"value":"synthetic"}"#.utf8)
        switch path {
        case "/retry-429", "/retry-503", "/retry-target", "/retry-date":
            if hit == 1 {
                status = path == "/retry-429" ? 429 : 503
                body = Data("invalid-json".utf8)
                if path == "/retry-date" {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
                    extra += "Retry-After: \(formatter.string(from: Date().addingTimeInterval(2)))\r\n"
                } else { extra += "Retry-After: 0\r\n" }
            }
        case "/retry-terminal", "/retry-disabled", "/retry-accepted": status = 503; extra += "Retry-After: 0\r\n"
        case "/retry-redirect": status = 302; extra += "Location: /retry-target\r\n"; body = Data()
        case "/download-empty": body = Data()
        case "/download-unknown": body = Data(repeating: 120, count: 65536)
        case "/download-partial": status = 206; extra += "Content-Range: bytes 0-7/16\r\n"; body = Data(repeating: 120, count: 8)
        case "/download-redirect": status = 302; extra += "Location: /payload\r\n"; body = Data()
        case "/empty": status = 204; body = Data()
        case "/status": status = 503; body = Data("invalid-json".utf8)
        case "/bad-json": body = Data("invalid-json".utf8)
        case "/payload": body = Data(repeating: 120, count: 65536)
        case "/large": body = Data(repeating: 120, count: 1048576)
        case "/redirect": status = 302; extra += "Location: /json\r\n"; body = Data()
        case "/cross": status = 302; extra += "Location: \(state.withLock { $0.redirect } ?? "/json")\r\n"; body = Data()
        case "/loop-a": status = 302; extra += "Location: /loop-b\r\n"; body = Data()
        case "/loop-b": status = 302; extra += "Location: /loop-a\r\n"; body = Data()
        case "/cookie": extra += "Set-Cookie: snk_fixture=synthetic; Path=/; Max-Age=3600\r\n"
        case "/cache": extra = "Cache-Control: public, max-age=3600\r\nETag: \"synthetic\"\r\n"
        case "/challenge":
            if !headers.contains("authorization: basic zml4dhvyztpzew50agv0awm=") {
                status = 401; extra += "WWW-Authenticate: Basic realm=\"NetworkKit-synthetic\"\r\n"
            }
        default: break
        }
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX"); date.timeZone = TimeZone(secondsFromGMT: 0)
        date.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let length = path == "/download-unknown" ? "" : "Content-Length: \(body.count)\r\n"
        var bytes = Data("HTTP/1.1 \(status) Fixture\r\nDate: \(date.string(from: Date()))\r\nContent-Type: application/json\r\n\(extra)\(length)Connection: close\r\n\r\n".utf8)
        bytes.append(body)
        connection.send(content: bytes, completion: .contentProcessed { _ in connection.cancel() })
    }
}

func nativeFixture(_ body: (NativeLoopbackFixture, URL) async throws -> Void) async throws {
    let fixture = try await NativeLoopbackFixture.start()
    do {
        try await body(fixture, fixture.base)
        #expect(await fixture.stop(), "Native fixture failed bounded listener/connection cleanup")
    } catch {
        #expect(await fixture.stop(), "Native fixture failed cleanup after error")
        throw error
    }
}

func nativeClient(_ base: URL, session: URLSession? = nil, diagnostics: (any NetworkDiagnosticSink)? = nil) throws -> APIClient {
    let config = NetworkConfiguration(baseURL: base, timeouts: try .init(inactivity: 2, total: 4),
                                      security: .init(allowInsecureLoopback: true), diagnostics: diagnostics)
    if let session { return try APIClient(configuration: config, session: session) }
    return try APIClient(configuration: config)
}

func nativeSend<Value: Sendable>(_ input: Input, client: APIClient, base: URL, path: String,
    response: ResponseStrategy<Value>, options: NetworkCallOptions = .default) async throws -> NetworkResponse<Value> {
    if input == .typed {
        return try await client.send(NativeEndpoint(path: .init(segments: [path]), responseStrategy: response, options: options))
    }
    return try await client.send(URLRequest(url: base.appendingPathComponent(path)), response: response, options: options)
}

final class NativeRetryEvents: NetworkDiagnosticSink {
    private let state = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    var events: [NetworkDiagnosticEvent] { state.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) { state.withLock { $0.append(event) } }
}

func downloadSession(_ ownership: Ownership) -> URLSession? {
    guard ownership == .borrowed else { return nil }
    let settings = URLSessionConfiguration.ephemeral
    settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
    settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil; settings.urlCache = nil
    settings.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: settings)
}
