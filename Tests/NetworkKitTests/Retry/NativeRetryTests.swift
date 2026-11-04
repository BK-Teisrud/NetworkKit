#if os(macOS)
import Foundation
import Testing
import os
import NetworkKit

private final class NativeRetrySink: NetworkDiagnosticSink {
    private let lock = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    var events: [NetworkDiagnosticEvent] { lock.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) { lock.withLock { $0.append(event) } }
}
private struct NativeRetryRecord: Decodable, Sendable {
    let path: String
    let time: Double
    let credential: Bool
}
private struct NativeRetryReply: Decodable, Sendable { let hit: Int }
private struct NativeRetryCall: Endpoint {
    let path: EndpointPath
    let responseStrategy = ResponseStrategy<NativeRetryReply>.json()
    let options: NetworkCallOptions
}
private final class NativeRetryServer {
    let fixture: BoundedFixtureProcess
    let base: URL
    init(redirect: String = "") throws {
        fixture = try BoundedFixtureProcess(script: #"""
import http.server, json, threading, time, sys
records = []
lock = threading.Lock()
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/records':
            with lock: body = json.dumps(records).encode()
            self.send_response(200)
        else:
            with lock:
                records.append({'path': self.path, 'time': time.monotonic(),
                    'credential': bool(self.headers.get('Authorization') or self.headers.get('Cookie'))})
                hit = sum(r['path'] == self.path for r in records)
            if self.path in ['/redirect', '/foreign']:
                body = b''
                self.send_response(302)
                self.send_header('Location', sys.argv[1] if self.path == '/foreign' else '/target')
            else:
                terminal = self.path in ['/terminal', '/duplicate', '/invalid', '/cap', '/accepted']
                failed = terminal or hit == 1
                status = 429 if self.path == '/429' else 503
                self.send_response(status if failed else 200)
                body = json.dumps({'hit': hit}).encode()
                if self.path == '/duplicate':
                    self.send_header('Retry-After', '0')
                    self.send_header('Retry-After', '0')
                elif self.path == '/invalid': self.send_header('Retry-After', '1, 2')
                elif self.path == '/cap': self.send_header('Retry-After', '31')
                else: self.send_header('Retry-After', '1' if self.path == '/wait' else '0')
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
print(server.server_port, flush=True)
server.serve_forever()
"""#, arguments: [redirect])
        guard let port = Int(try fixture.startupLine()) else { throw URLError(.cannotConnectToHost) }
        base = URL(string: "http://127.0.0.1:\(port)")!
    }
    func stop() { #expect(fixture.stop(), "Native retry fixture failed bounded teardown") }
}

/// Actual native macOS loopback evidence, not a fallback result on other platforms.
@Suite(.serialized, .timeLimit(.minutes(1))) struct NativeRetryTests {
    private func configuration(_ base: URL, sink: NativeRetrySink) throws -> NetworkConfiguration {
        NetworkConfiguration(baseURL: base, timeouts: try NetworkTimeouts(inactivity: 3, total: 8),
            security: NetworkSecurityPolicy(allowInsecureLoopback: true), diagnostics: sink)
    }
    private func records(_ server: NativeRetryServer) async throws -> [NativeRetryRecord] {
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.urlCache = nil; settings.urlCredentialStorage = nil
        let control = URLSession(configuration: settings)
        defer { control.invalidateAndCancel() }
        let (data, _) = try await control.data(from: server.base.appendingPathComponent("records"))
        return try JSONDecoder().decode([NativeRetryRecord].self, from: data)
    }
    private func call(_ client: APIClient, base: URL, path: String, raw: Bool,
                      options: NetworkCallOptions) async throws -> NetworkResponse<NativeRetryReply> {
        if raw { return try await client.send(URLRequest(url: base.appendingPathComponent(path)),
            response: .json(NativeRetryReply.self), options: options) }
        return try await client.send(NativeRetryCall(path: EndpointPath(segments: [path]), options: options))
    }

    @Test(arguments: ["owned", "borrowedStrict", "borrowedAppManaged"], [false, true])
    func native429And503RespectOwnershipAndTypedRaw(profile: String, raw: Bool) async throws {
        let server = try NativeRetryServer(); defer { server.stop() }
        let sink = NativeRetrySink()
        // Store-free app-managed is a supported subset, not active HTTPS store evidence.
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false; settings.httpCookieAcceptPolicy = .never
        settings.urlCache = nil; settings.urlCredentialStorage = nil; settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        let borrowed = profile == "owned" ? nil : URLSession(configuration: settings)
        defer { borrowed?.invalidateAndCancel() }
        let config = try configuration(server.base, sink: sink)
        let client: APIClient
        if let borrowed { client = try APIClient(configuration: config, session: borrowed,
            storage: profile == "borrowedStrict" ? .strict : .appManaged) }
        else { client = try APIClient(configuration: config) }
        for path in ["429", "503"] {
            let result = try await call(client, base: server.base, path: path, raw: raw,
                                        options: NetworkCallOptions(retry: .oneRetryForSafeReads))
            #expect(result.value.hit == 2)
        }
        let contacts = try await records(server)
        #expect(contacts.count == 4 && contacts.allSatisfy { !$0.credential })
        #expect(sink.events.count == 2 && sink.events.allSatisfy { $0.attemptCount == 2 && $0.outcome == .success })
        await client.shutdown()
        if let borrowed {
            // Owner's session remains usable after client shutdown.
            let (_, response) = try await borrowed.data(from: server.base.appendingPathComponent("records"))
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
        }
    }

    @Test func originalTargetIsRevisitedAfterSameOriginRedirect() async throws {
        let server = try NativeRetryServer(); defer { server.stop() }
        let sink = NativeRetrySink(), client = try APIClient(configuration: configuration(server.base, sink: sink))
        let result = try await call(client, base: server.base, path: "redirect", raw: false,
                                    options: NetworkCallOptions(retry: .oneRetryForSafeReads))
        #expect(result.value.hit == 2)
        #expect(try await records(server).map(\.path) == ["/redirect", "/target", "/redirect", "/target"])
        #expect(sink.events.count == 1 && sink.events.first?.attemptCount == 2)
        await client.shutdown()
    }

    @Test(arguments: ["terminal", "duplicate", "invalid", "cap", "disabled", "accepted"])
    func terminalAndDisabledPoliciesHaveBoundedWireContacts(mode: String) async throws {
        let server = try NativeRetryServer(); defer { server.stop() }
        let sink = NativeRetrySink(), client = try APIClient(configuration: configuration(server.base, sink: sink))
        let options = try NetworkCallOptions(acceptedStatuses: mode == "accepted" ? HTTPStatusPolicy(codes: [503]) : .successful,
                                            retry: mode == "disabled" ? .disabled : .oneRetryForSafeReads)
        let path = mode == "disabled" ? "503" : mode
        if mode == "accepted" {
            #expect(try await call(client, base: server.base, path: path, raw: true, options: options).value.hit == 1)
        } else {
            do { _ = try await call(client, base: server.base, path: path, raw: true, options: options); Issue.record("Expected terminal HTTP failure") }
            catch let failure as NetworkError { guard case .httpStatus = failure else { throw failure } }
        }
        let expected = mode == "terminal" ? 2 : 1
        #expect(try await records(server).count == expected)
        #expect(sink.events.count == 1 && sink.events.first?.attemptCount == expected)
        await client.shutdown()
    }

    @Test func serverMinimumDelayIsNotShortened() async throws {
        let server = try NativeRetryServer(); defer { server.stop() }
        let sink = NativeRetrySink(), client = try APIClient(configuration: configuration(server.base, sink: sink))
        _ = try await call(client, base: server.base, path: "wait", raw: true,
                           options: NetworkCallOptions(retry: .oneRetryForSafeReads))
        let contacts = try await records(server)
        #expect(contacts.count == 2)
        if contacts.count == 2 { #expect(contacts[1].time - contacts[0].time >= 1) }
        #expect(sink.events.first?.attemptCount == 2)
        await client.shutdown()
    }
    @Test func deniedOriginIsNotFollowedOrRetried() async throws {
        let target = try NativeRetryServer(); defer { target.stop() }
        let source = try NativeRetryServer(redirect: target.base.appendingPathComponent("target").absoluteString)
        defer { source.stop() }
        let sink = NativeRetrySink(), client = try APIClient(configuration: configuration(source.base, sink: sink))
        do {
            _ = try await call(client, base: source.base, path: "foreign", raw: true,
                               options: NetworkCallOptions(retry: .oneRetryForSafeReads))
            Issue.record("Denied-origin redirect unexpectedly accepted")
        } catch let failure as NetworkError {
            guard case .httpStatus(let status, _) = failure else { throw failure }
            #expect(status.code == 302)
        }
        #expect(try await records(source).map(\.path) == ["/foreign"])
        #expect(try await records(target).isEmpty)
        #expect(sink.events.first?.attemptCount == 1)
        await client.shutdown()
    }

}
#endif
