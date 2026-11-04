#!/usr/bin/env python3
"""Explicit opt-in I28 probe. Loopback only, bounded fixture, no SDK target changes."""
import argparse
import gzip
import hashlib
import platform
import http.server
import json
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]


def library_sources(root):
    """Match recursive library source discovery while excluding documentation assets."""
    directory = root / 'Sources/NetworkKit'
    sources = sorted(p for p in directory.rglob('*.swift')
                     if p.is_file() and not any(part.endswith('.docc') for part in p.relative_to(directory).parts))
    if not sources:
        raise RuntimeError('Missing NetworkKit library sources')
    return sources


def run_handoff(output):
    """No network. Exercise candidate ownership around existing terminal arbitration."""
    probe = Path(__file__).with_name('HandoffProbe.swift')
    sources = library_sources(ROOT)
    with tempfile.TemporaryDirectory(prefix='snk-i28-handoff-') as tmp:
        work = Path(tmp)
        binary, result = work / 'probe', work / 'result.json'
        subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-warnings-as-errors',
                        '-parse-as-library', *map(str, sources), str(probe),
                        '-o', str(binary)], check=True, timeout=120)
        subprocess.run([str(binary), str(work / 'files'), str(result)], check=True, timeout=20)
        observations = json.loads(result.read_text())
        assert len(observations) == 7 and len(set(observations)) == 7, observations
        report = {
            'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'host': {'macOS': platform.mac_ver()[0], 'architecture': platform.machine()},
            'probe_sha256': hashlib.sha256(probe.read_bytes()).hexdigest(),
            'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'sdk_source_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
            'scope': 'I28 non-shipping operation-scoped ownership protocol only',
            'observations': observations,
            'limits': ['No network in handoff experiment',
                       'Synthetic finish-time clock, not inactivity watchdog proof',
                       'Injected filesystem failures, not real disk exhaustion',
                       'Foundation-owned partial files remain unobserved',
                       'No APIClient download integration or public API authorization']}
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--handoff-only', action='store_true', help='No-network ownership/terminal-arbitration experiment')
    args = parser.parse_args()
    if args.handoff_only:
        run_handoff(args.output)
        return
    counts = {}
    lock = threading.Lock()

    class Fixture(http.server.BaseHTTPRequestHandler):
        def log_message(self, *unused):
            pass

        def do_GET(self):
            with lock:
                counts[self.path] = counts.get(self.path, 0) + 1
            try:
                body = b'A' * (8192 if self.path == '/oversized' else 4096)
                status = 200
                headers = {}
                if self.path == '/empty':
                    body = b''
                elif self.path == '/encoded':
                    body = gzip.compress(body)
                    headers['Content-Encoding'] = 'gzip'
                elif self.path == '/partial':
                    status = 206
                    headers['Content-Range'] = 'bytes 0-4095/8192'
                elif self.path == '/status':
                    status = 503
                elif self.path in ['/redirect', '/denied']:
                    status = 302
                    headers['Location'] = '/normal' if self.path == '/redirect' else foreign_url
                    body = b''
                self.send_response(status)
                for k, v in headers.items():
                    self.send_header(k, v)
                if self.path != '/unknown':
                    self.send_header('Content-Length', str(65536 if self.path in ['/slow', '/interrupted'] else len(body)))
                self.send_header('Connection', 'close')
                self.end_headers()
                if self.path == '/slow':
                    self.wfile.write(b'A' * 1024)
                    self.wfile.flush()
                    time.sleep(1)
                    return
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    with tempfile.TemporaryDirectory(prefix='snk-i28-') as tmp:
        work = Path(tmp)
        cert, key = work / 'cert.pem', work / 'key.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-keyout', str(key), '-out', str(cert), '-days', '1',
                        '-subj', '/CN=localhost'], check=True, capture_output=True)
        os.chmod(key, 0o600)
        servers = [http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture) for _ in range(3)]
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        servers[2].socket = context.wrap_socket(servers[2].socket, server_side=True)
        foreign_url = f'http://127.0.0.1:{servers[1].server_port}/foreign-target'
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            binary = work / 'probe'
            sources = library_sources(ROOT)
            subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library',
                            *map(str, sources), str(Path(__file__).with_name('Probe.swift')),
                            '-o', str(binary)], check=True, timeout=120)
            result = work / 'result.json'
            subprocess.run([str(binary), f'http://127.0.0.1:{servers[0].server_port}',
                            f'https://127.0.0.1:{servers[2].server_port}/normal',
                            str(work / 'preserved'), str(result)], check=True, timeout=60)
            observations = json.loads(result.read_text())
            assert len(observations) == 28, len(observations)
            assert counts.get('/foreign-target', 0) == 0, counts
            assert counts.get('/slow', 0) == 3, counts
            assert all(x['outcome'] == 'passed' for x in observations)
            report = {'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                      'host': {'macOS': platform.mac_ver()[0], 'architecture': platform.machine()},
                      'probe_sha256': hashlib.sha256(Path(__file__).with_name('Probe.swift').read_bytes()).hexdigest(),
                      'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      'sdk_source_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                      'scope': 'I28 non-shipping local feasibility only',
                      'observations': observations, 'server_contacts': counts,
                      'limits': ['No APIClient download integration or race proof',
                                 'No hard transient disk bound',
                                 'Foundation-owned partial file cleanup not observed',
                                 'No trusted HTTPS success or full-platform runtime proof',
                                 'No disk-error injection or crash-leftover recovery proof']}
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2) + '\n')
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()


if __name__ == '__main__':
    main()
