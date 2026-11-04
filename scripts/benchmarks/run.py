#!/usr/bin/env python3
"""Opt-in macOS release probe. Synthetic loopback only; no external dependencies/service.
Not a CI timing gate, memory-leak detector, TLS proof, or production target workload.
"""
import argparse
import http.server
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
import threading
import urllib.parse


class Fixture(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self):
        self.lock = threading.Lock()
        self.connections = 0
        self.connection_ids = {}
        self.payload_connections = set()
        self.payload_requests = 0
        self.slow_started = 0
        self.retry_hits = {}
        self.retry_replied = 0
        self.stop_event = threading.Event()
        super().__init__(("127.0.0.1", 0), Handler)

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(5)
        with self.lock:
            self.connections += 1
            self.connection_ids[id(connection)] = self.connections
        return connection, address

    def snapshot(self):
        with self.lock:
            return {"payload_requests": self.payload_requests,
                    "payload_connections": len(self.payload_connections), "slow_started": self.slow_started,
                    "retry_replied": self.retry_replied}

    def handle_error(self, request, client_address):
        # Only expected cancellation disconnects are silent; surface other fixture failures.
        if not isinstance(sys.exc_info()[1], (BrokenPipeError, ConnectionResetError)):
            super().handle_error(request, client_address)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        status = 200
        if parsed.path == "/stats":
            body = json.dumps(self.server.snapshot()).encode()
        elif parsed.path in ("/payload", "/slow", "/retry", "/retry-wait"):
            size = int(urllib.parse.parse_qs(parsed.query)["bytes"][0])
            if not 0 < size <= 1_048_576:
                self.send_error(400)
                return
            with self.server.lock:
                if parsed.path == "/slow":
                    self.server.slow_started += 1
                else:
                    self.server.payload_requests += 1
                    self.server.payload_connections.add(self.server.connection_ids[id(self.connection)])
                if parsed.path in ("/retry", "/retry-wait"):
                    key = urllib.parse.parse_qs(parsed.query)["call"][0]
                    self.server.retry_hits[key] = self.server.retry_hits.get(key, 0) + 1
                    status = 503 if self.server.retry_hits[key] == 1 else 200
            if parsed.path == "/slow":
                self.server.stop_event.wait(5)
            body = b"x" * size
        else:
            self.send_error(404)
            return
        self.send_response(status)
        if status == 503:
            self.send_header("Retry-After", "3" if parsed.path == "/retry-wait" else "0")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
            if parsed.path == "/retry-wait":
                with self.server.lock: self.server.retry_replied += 1
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True

    def log_message(self, *args):
        pass


def command(*args, **kwargs):
    try:
        return subprocess.run(args, check=True, text=True, capture_output=True, timeout=kwargs.pop("timeout", 180), **kwargs).stdout.strip()
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"Command failed: {args[0]}\n{error.stdout}\n{error.stderr}") from error


def run(package, output, repetitions, smoke, post_budget, post_budget_cycles, executable=None, retry=False):
    if platform.system() != "Darwin":
        raise SystemExit("This opt-in resource probe requires macOS; no other platform result is implied.")
    package = package.resolve()
    results = []
    with tempfile.TemporaryDirectory(prefix="networkkit-resource-") as folder:
        root = Path(folder)
        (root / "Sources" / "ResourceProbe").mkdir(parents=True)
        (root / "Sources" / "ResourceProbe" / "Probe.swift").write_bytes(Path(__file__).with_name("Probe.swift").read_bytes())
        (root / "Package.swift").write_text('''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "ResourceProbe", platforms: [.macOS(.v14)],
    dependencies: [.package(name: "NetworkKit", path: %s)], targets: [.executableTarget(name: "ResourceProbe",
    dependencies: [.product(name: "NetworkKit", package: "NetworkKit")])], swiftLanguageModes: [.v6])
''' % json.dumps(str(package)))
        if executable is None:
            print("Building standalone public consumer in release mode…", flush=True)
            command("swift", "build", "--package-path", str(root), "-c", "release", "-Xswiftc", "-warnings-as-errors", timeout=300)
            binary = Path(command("swift", "build", "--package-path", str(root), "-c", "release", "--show-bin-path")) / "ResourceProbe"
        else:
            binary = executable.resolve(strict=True)
            if not binary.is_file():
                raise RuntimeError("Prebuilt consumer is not a regular file")
        cases = [("reuse", 1, 65536, 32, 3), ("fresh", 1, 65536, 32, 3),
                 ("reuse", 8, 65536, 32, 3), ("reuse", 32, 65536, 64, 3),
                 ("reuse", 8, 1048576, 32, 3), ("cancel", 8, 65536, 8, 0),
                 ("reuse", 32, 65536, 64, 100), ("direct", 32, 65536, 64, 100)]
        if smoke:
            cases = [("reuse", 1, 65536, 4, 1), ("cancel", 8, 65536, 8, 0)]
        if post_budget:
            cases = [("reuse", 32, 65536, 64, post_budget_cycles), ("direct", 32, 65536, 64, post_budget_cycles)]
        if retry:
            cases = [("reuse", 8, 65536, 32, 3), ("retry", 8, 65536, 32, 3),
                     ("retry", 8, 1048576, 32, 3), ("retry-cancel", 8, 65536, 8, 0)]
        for mode, concurrency, size, calls, cycles in cases:
            for repetition in range(repetitions):
                server = Fixture()
                worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True)
                worker.start()
                try:
                    timing = root / "time.txt"
                    raw = command("/usr/bin/time", "-l", "-o", str(timing), str(binary),
                                  f"http://127.0.0.1:{server.server_port}", mode, str(concurrency), str(size), str(calls), str(cycles), "post-budget" if post_budget or retry else "default", timeout=120 if cycles > 100 else 45)
                    result = json.loads(raw)
                    peak = re.search(r"(\d+)\s+maximum resident set size", timing.read_text())
                    if not peak:
                        raise RuntimeError("Missing macOS maximum RSS measurement")
                    result.update(server.snapshot())
                    result.update(repetition=repetition + 1, peak_rss_bytes=int(peak[1]))
                    expected = 1 if mode == "cancel" else 1 + concurrency if mode == "retry-cancel" else 1 + calls * cycles * (2 if mode == "retry" else 1)
                    if result["payload_requests"] != expected:
                        raise RuntimeError(f"Unexpected payload request count: {result}")
                    if mode in ("reuse", "direct") and result["payload_connections"] >= result["payload_requests"]:
                        raise RuntimeError("No native connection reuse was observed")
                    if mode == "fresh" and result["payload_connections"] != expected:
                        raise RuntimeError("Fresh-client control did not create distinct native connections")
                    if mode in ("cancel", "retry-cancel") and ((result["slow_started"] < 1 if mode == "cancel" else result["retry_replied"] != concurrency) or result["cancelled_calls"] != concurrency):
                        raise RuntimeError("Cancellation did not join all calls after native contact")
                    results.append(result)
                    print(f"Completed {mode}, concurrency={concurrency}, bytes={size}, cycles={cycles}, repetition={repetition + 1}", flush=True)
                finally:
                    server.stop_event.set()
                    server.shutdown()
                    server.server_close()
                    worker.join(timeout=1)
                    if worker.is_alive():
                        raise RuntimeError("Fixture accept loop failed bounded teardown")
    metadata = {"product_commit": command("git", "-C", str(package), "rev-parse", "HEAD"),
                "tracked_checkout_clean": not bool(command("git", "-C", str(package), "status", "--porcelain", "--untracked-files=no")),
                "probe_sha256": hashlib.sha256(Path(__file__).with_name("Probe.swift").read_bytes()).hexdigest(),
                "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "os": command("sw_vers"), "architecture": platform.machine(),
                "xcode": command("xcodebuild", "-version"), "swift": command("xcrun", "swift", "--version"),
                "sdk": command("xcrun", "--sdk", "macosx", "--show-sdk-version"),
                "python": platform.python_version(), "build": "prebuilt; see verified builder manifest" if executable else "release; Swift 6; warnings-as-errors",
                "repetitions": repetitions, "smoke": smoke, "post_budget": post_budget, "retry": retry,
                "product_sources_sha256": hashlib.sha256(b"".join(p.relative_to(package).as_posix().encode() + b"\0" + p.read_bytes() for p in sorted((package / "Sources").rglob("*")) if p.is_file())).hexdigest(),
                "sampling": "fresh process per repetition; RSS in bytes; " + ("12s" if post_budget or retry else "100ms") + " post-shutdown sample"}
    output.write_text(json.dumps({"environment": metadata, "results": results}, indent=2) + "\n")
    print(f"Wrote {output}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repetitions", type=int, choices=range(1, 6), default=3)
    parser.add_argument("--smoke", action="store_true", help="Compile and exercise only a short reuse/cancellation case; no performance thresholds")
    parser.add_argument("--retry", action="store_true", help="Native bounded retry/disabled/cancellation controls with post-original-budget RSS and malloc samples")
    parser.add_argument("--post-budget", action="store_true", help="Run only long reuse/direct controls with a 12-second post-shutdown sample")
    parser.add_argument("--cycles", type=int, metavar="1..1000", default=100, help="Cycle count for --post-budget only (default 100)")
    parser.add_argument("--executable", type=Path, help="Run an explicitly selected prebuilt consumer; caller must verify its provenance and target")
    args = parser.parse_args()
    if sum([args.smoke, args.post_budget, args.retry]) > 1:
        parser.error("--smoke, --post-budget and --retry are separate workloads")
    if not 1 <= args.cycles <= 1000:
        parser.error("--cycles must be between 1 and 1000")
    if args.cycles != 100 and not args.post_budget:
        parser.error("--cycles requires --post-budget")
    run(args.package, args.output, args.repetitions, args.smoke, args.post_budget, args.cycles, args.executable, args.retry)
