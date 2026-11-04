#!/usr/bin/env python3
"""Execute only the bounded native download CI selection; public/resource probes stay opt-in."""
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NAMES = ('nativeLoopbackDownloadFiles', 'nativeLoopbackDownloadRedirects',
         'nativeLoopbackDownloadCancellation', 'nativeLoopbackDownloadKnownFileCleanup')
PREFIX = 'PublicHTTPSChecksTests.PublicHTTPSTests/'
IDENTIFIERS = {PREFIX + name + '(ownership:)' for name in NAMES}
# SwiftPM discovery and Swift Testing execution use different suite separators.
FILTER = r'PublicHTTPSTests[./](' + '|'.join(NAMES) + ')'
MARKERS = ('download files', 'download redirects', 'download lifecycle', 'download known-file cleanup')


def validate_discovery(output):
    selected = [line for line in output.splitlines() if re.search(FILTER, line)]
    if set(selected) != IDENTIFIERS or len(selected) != len(IDENTIFIERS):
        raise RuntimeError('Native loopback selection is missing or duplicates required tests')


def validate_result(xml, output):
    root = ET.fromstring(xml)
    suites = list(root.iter('testsuite'))
    cases = list(root.iter('testcase'))
    expected = {name + '(ownership:)' for name in NAMES}
    if (len(cases) != 4 or {c.get('name') for c in cases} != expected
            or any(c.get('classname') != 'PublicHTTPSChecksTests.PublicHTTPSTests' for c in cases)
            or any(s.get('errors', '0') != '0' or s.get('failures', '0') != '0'
                   or s.get('skipped', '0') != '0' for s in suites)
            or any(list(c) for c in cases)):
        raise RuntimeError('Native loopback execution is empty, incomplete, failed, skipped or unexpected')
    for marker in MARKERS:
        for ownership in ('owned', 'borrowed'):
            if output.count('NativeLoopback ' + marker + ' ' + ownership + ':') != 1:
                raise RuntimeError('Missing or duplicate native ownership-case evidence')


def main():
    package = str(ROOT / 'Tools/PublicHTTPSChecks')
    discovery = subprocess.run(['swift', 'test', '--package-path', package, 'list', '--skip-build'],
                               text=True, capture_output=True, check=True, timeout=60)
    validate_discovery(discovery.stdout)
    report = ROOT / '.build/ci/native-loopback.xml'
    report.parent.mkdir(parents=True, exist_ok=True)
    report.unlink(missing_ok=True)
    result = subprocess.run(['swift', 'test', '--package-path', package, '--skip-build',
                             '--disable-xctest', '--filter', FILTER, '--xunit-output', str(report)],
                            text=True, capture_output=True, timeout=180)
    print(result.stdout, end='', flush=True)
    print(result.stderr, end='', flush=True)
    result.check_returncode()
    validate_result(report.read_text(), result.stdout + result.stderr)
    print(json.dumps({'native_loopback_declarations': 4, 'ownership_cases': 8,
                      'public_service_selection': False, 'resource_benchmarks': False}))


if __name__ == '__main__':
    main()
