#if os(macOS)
import Foundation
import Testing
import NetworkKit
import os

/// Native system-trust rejection only; this fixture never installs a trust anchor.
private final class UntrustedTLSServer {
    private enum CleanupFailure: Error { case terminationFailed }
    private let fixture: BoundedFixtureProcess
    private let directory: URL
    let base: URL

    init() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NetworkKitTLS-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        var started: BoundedFixtureProcess?
        do {
            let fixture = try BoundedFixtureProcess(script: #"""
import http.server, os, pathlib, signal, ssl, subprocess, sys
os.umask(0o077)
root = pathlib.Path(sys.argv[1])
config = root / 'request.cnf'
config.write_text('''[req]
prompt = no
distinguished_name = subject
x509_extensions = server
[subject]
CN = localhost
[server]
subjectAltName = DNS:localhost,IP:127.0.0.1
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
''')
generator = subprocess.Popen(['/usr/bin/openssl', 'req', '-x509', '-newkey', 'rsa:2048',
    '-sha256', '-nodes', '-days', '1', '-config', str(config),
    '-keyout', str(root / 'fixture.key'), '-out', str(root / 'fixture.crt')],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def terminate_generator(signum, frame):
    if generator.poll() is None:
        generator.kill()
        generator.wait(timeout=0.5)
    raise SystemExit(1)
signal.signal(signal.SIGTERM, terminate_generator)
try:
    if generator.wait(timeout=3) != 0:
        raise RuntimeError('Synthetic certificate generation failed')
finally:
    if generator.poll() is None:
        generator.kill()
        generator.wait(timeout=0.5)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(204)
        self.send_header('Content-Length', '0')
        self.end_headers()
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.minimum_version = ssl.TLSVersion.TLSv1_2
context.load_cert_chain(str(root / 'fixture.crt'), str(root / 'fixture.key'))
server.socket = context.wrap_socket(server.socket, server_side=True)
print(server.server_port, flush=True)
server.serve_forever()
"""#, arguments: [directory.path])
            started = fixture
            let line = try fixture.startupLine(milliseconds: 6000)
            guard let port = Int(line), (1...65535).contains(port),
                  let base = URL(string: "https://127.0.0.1:\(port)") else {
                throw URLError(.cannotConnectToHost)
            }
            self.fixture = fixture
            self.directory = directory
            self.base = base
        } catch {
            let stopped = started?.stop() ?? true
            #expect(stopped, "TLS fixture setup cleanup did not terminate")
            if stopped {
                do { try FileManager.default.removeItem(at: directory) }
                catch { Issue.record("TLS fixture setup temporary-file cleanup failed") }
            }
            throw error
        }
    }

    func stop() throws {
        guard fixture.stop() else { throw CleanupFailure.terminationFailed }
        try FileManager.default.removeItem(at: directory)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    deinit {
        if fixture.stop() { try? FileManager.default.removeItem(at: directory) }
    }
}

private struct TLSCall: Endpoint {
    let path: EndpointPath
    let options: NetworkCallOptions
    init(options: NetworkCallOptions = .default) throws {
        path = try EndpointPath(segments: ["fixture"])
        self.options = options
    }
    let responseStrategy: ResponseStrategy<EmptyResponse> = .empty
}

private final class TLSRetrySink: NetworkDiagnosticSink {
    private let state = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    var events: [NetworkDiagnosticEvent] { state.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) { state.withLock { $0.append(event) } }
}

@Suite(.timeLimit(.minutes(1))) struct NativeTLSTests {
    @Test func untrustedCertificateIsRejectedThroughBothPublicInputs() async throws {
        let server = try UntrustedTLSServer()
        defer {
            do {
                try server.stop()
                FileHandle.standardOutput.write(Data("Native TLS: fixture cleaned\n".utf8))
            } catch { Issue.record("TLS fixture process/temporary-file cleanup failed") }
        }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: server.base,
            timeouts: try NetworkTimeouts(inactivity: 3, total: 10)))
        for typed in [true, false] {
            let phase = typed ? "typed" : "raw"
            FileHandle.standardOutput.write(Data("Native TLS \(phase): start\n".utf8))
            do {
                if typed { _ = try await client.send(TLSCall()) }
                else { _ = try await client.send(URLRequest(url: server.base.appendingPathComponent("fixture")), response: .empty) }
                Issue.record("System trust unexpectedly accepted a fresh self-signed fixture certificate")
            } catch let error as NetworkError {
                guard case .transport(let failure) = error else {
                    Issue.record("Expected a certificate-specific transport failure")
                    continue
                }
                #expect(failure.domain == NSURLErrorDomain)
                let certificateRejected = [URLError.serverCertificateUntrusted.rawValue,
                    URLError.serverCertificateHasUnknownRoot.rawValue].contains(failure.code)
                #expect(certificateRejected)
                if failure.domain == NSURLErrorDomain && certificateRejected {
                    FileHandle.standardOutput.write(Data("Native TLS \(phase): certificate rejected (\(failure.code))\n".utf8))
                }
            } catch {
                Issue.record("Expected structured native certificate rejection")
            }
        }
        await client.shutdown()
    }
    @Test(arguments: [false, true]) func optedInReadNeverRetriesUntrustedTLS(raw: Bool) async throws {
        let server = try UntrustedTLSServer()
        defer { do { try server.stop() } catch { Issue.record("TLS retry fixture teardown failed") } }
        let sink = TLSRetrySink()
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: server.base,
            timeouts: NetworkTimeouts(inactivity: 3, total: 10), diagnostics: sink))
        let options = try NetworkCallOptions(retry: .oneRetryForSafeReads)
        do {
            if raw { _ = try await client.send(URLRequest(url: server.base.appendingPathComponent("fixture")), response: .empty, options: options) }
            else { _ = try await client.send(TLSCall(options: options)) }
            Issue.record("Untrusted TLS fixture unexpectedly accepted")
        } catch let error as NetworkError {
            guard case .transport(let identity) = error else { throw error }
            #expect(identity.domain == NSURLErrorDomain)
            #expect([URLError.serverCertificateUntrusted.rawValue, URLError.serverCertificateHasUnknownRoot.rawValue].contains(identity.code))
        }
        #expect(sink.events.count == 1)
        #expect(sink.events.first?.attemptCount == 1)
        #expect(sink.events.first?.status == nil)
        await client.shutdown()
    }

}
#endif
