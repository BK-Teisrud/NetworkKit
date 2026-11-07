#!/usr/bin/env python3
"""#168 opt-in bounded local/public observations. No automatic retry or build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
LOCAL = ['target-observer', 'matched', 'missing', 'mismatched', 'reject',
         'redirect', 'cancel-opening']
EXTERNAL = ['echo', 'tls-valid', 'tls-self-signed', 'tls-wrong-host']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ledger', type=Path, required=True,
                        help='New private budget ledger; refuses any existing file')
    parser.add_argument('--external-approved', action='store_true', required=True)
    args = parser.parse_args()
    if not args.binary.is_file():
        parser.error('Build the isolated product first; runner never builds')
    # Exclusive creation stops accidental repetition using the same authorization ledger.
    ledger = args.ledger.open('x')
    args.output.mkdir(parents=True, exist_ok=False)
    sources = [HERE / 'Package.swift', Path(__file__),
               *sorted((HERE / 'Sources/HandshakeSecurity').rglob('*.swift'))]
    state = {'source_hashes': {str(p.relative_to(HERE)): digest(p) for p in sources},
             'binary_sha256': digest(args.binary), 'rows': [],
             'application_initiated_local_limit_per_candidate': 7,
             'application_initiated_external_limit_total': 8,
             'native_internal_wire_attempt_count': 'not observable/enforced by this harness',
             'automatic_reruns': False,
             'public_data': 'Fixed synthetic text/binary only; no private headers/query/data'}
    for external, scenarios in [(False, LOCAL), (True, EXTERNAL)]:
        for candidate in ['network', 'session']:
            for scenario in scenarios:
                name = f'{candidate}-{scenario}'
                row = {'candidate': candidate, 'scenario': scenario,
                       'external': external, 'started': True}
                state['rows'].append(row)
                ledger.seek(0); ledger.truncate()
                json.dump(state, ledger, indent=2); ledger.flush(); os.fsync(ledger.fileno())
                start = time.monotonic()
                process = subprocess.Popen([str(args.binary), candidate, scenario],
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                           start_new_session=True)
                expired = False
                try:
                    stdout, stderr = process.communicate(timeout=20)
                except subprocess.TimeoutExpired:
                    expired = True
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        stdout, stderr = process.communicate(timeout=1)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        stdout, stderr = process.communicate()
                row.update({'elapsed_seconds': round(time.monotonic() - start, 3),
                            'returncode': process.returncode, 'harness_timeout': expired,
                            'stdout_sha256': hashlib.sha256(stdout).hexdigest(),
                            'stderr_sha256': hashlib.sha256(stderr).hexdigest()})
                (args.output / f'{name}.stdout').write_bytes(stdout)
                (args.output / f'{name}.stderr').write_bytes(stderr)
                try:
                    row['observation'] = json.loads(stdout)
                except (ValueError, UnicodeDecodeError):
                    row['observation'] = None
                row['harness_completed'] = (not expired and process.returncode == 0
                                            and bool(row['observation']))
                row['policy_satisfied'] = (row['observation'] or {}).get('policySatisfied')
                ledger.seek(0); ledger.truncate()
                json.dump(state, ledger, indent=2); ledger.flush(); os.fsync(ledger.fileno())
                (args.output / 'results.json').write_text(json.dumps(state, indent=2) + '\n')
                print(name, 'recorded' if row['harness_completed'] else 'HARNESS FAILURE',
                      'policy=', row['policy_satisfied'], flush=True)
    ledger.close()
    # Completion is distinct from a passed product/security policy.
    return 0 if all(r['harness_completed'] for r in state['rows']) else 1


if __name__ == '__main__':
    sys.exit(main())
