#!/usr/bin/env python3
"""Finite opt-in local probe. No builds, retries, public services or SDK imports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

HERE = Path(__file__).resolve().parent
SCENARIOS = ['exchange', 'size-65535', 'size-65536', 'size-65537',
             'cancel', 'shutdown', 'peer-close', 'withheld']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True,
                        help='New private output directory; refuses overwrite')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    binary = HERE / '.build/debug/WebSocketFeasibility'
    if not binary.is_file():
        parser.error('Build the isolated tool first; runner never builds implicitly')
    hashes = {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [HERE / 'Package.swift', Path(__file__),
                        *sorted((HERE / 'Sources').rglob('*.swift'))]}
    rows = []
    for candidate in ['network', 'session']:
        for scenario in SCENARIOS:
            name = f'{candidate}-{scenario}'
            command = ['/usr/bin/time', '-l', str(binary), candidate, scenario]
            process = subprocess.Popen(command, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, start_new_session=True)
            timed_out = False
            try:
                stdout, stderr = process.communicate(timeout=20)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    stdout, stderr = process.communicate(timeout=1)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    stdout, stderr = process.communicate()
            (args.output / f'{name}.stdout').write_bytes(stdout)
            (args.output / f'{name}.stderr').write_bytes(stderr)
            row = {'candidate': candidate, 'scenario': scenario,
                   'returncode': process.returncode, 'harness_timeout': timed_out,
                   'stdout_sha256': hashlib.sha256(stdout).hexdigest(),
                   'stderr_sha256': hashlib.sha256(stderr).hexdigest()}
            try:
                row['observation'] = json.loads(stdout)
            except (ValueError, UnicodeDecodeError):
                row['observation'] = None
            rss = re.search(rb'(\d+)\s+maximum resident set size', stderr)
            row['whole_process_max_rss_bytes'] = int(rss[1]) if rss else None
            row['passed'] = (not timed_out and process.returncode == 0
                             and bool(row['observation'])
                             and row['observation'].get('passed') is True)
            rows.append(row)
            print(name, 'PASS' if row['passed'] else 'FAIL', flush=True)
            (args.output / 'results.json').write_text(json.dumps({
                'source_hashes': hashes, 'rows': rows,
                'scope': 'Native tool mechanics on local cleartext loopback; no SDK/TLS/physical proof',
                'automatic_reruns': False,
            }, indent=2) + '\n')
    return 0 if all(r['passed'] for r in rows) else 1


if __name__ == '__main__':
    sys.exit(main())
