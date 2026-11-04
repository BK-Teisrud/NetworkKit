import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import macos14


class PrebuiltConsumerContracts(unittest.TestCase):
    def test_finder_metadata_does_not_hide_real_source_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            names = ['Package.swift', 'scripts/benchmarks/Probe.swift', 'scripts/benchmarks/run.py',
                     'scripts/ci/macos14.py', 'scripts/verification/NativeHTTPSProbe.swift',
                     'Sources/NetworkKit/Client/APIClient.swift']
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('reviewed source')
            with patch.object(macos14, 'ROOT', root):
                baseline = macos14.sources()
                (root / 'Sources/.DS_Store').write_bytes(b'Finder metadata')
                self.assertEqual(macos14.sources(), baseline)
                (root / names[-1]).write_text('changed source')
                self.assertNotEqual(macos14.sources(), baseline)

    def payload(self, folder):
        (folder / 'ResourceProbe').write_bytes(b'synthetic executable control')
        manifest = {'source_commit': 'a' * 40, 'source_hashes': {'source': 'reviewed'},
                    'target': 'arm64-apple-macosx14.0',
                    'files': {'ResourceProbe': hashlib.sha256((folder / 'ResourceProbe').read_bytes()).hexdigest()}}
        (folder / 'manifest.json').write_text(json.dumps(manifest))
        return manifest

    def test_tampered_executable_or_wrong_commit_cannot_pass_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with patch.object(macos14, 'command', return_value='a' * 40), patch.object(macos14, 'sources', return_value={'source': 'reviewed'}):
                self.payload(folder)
                macos14.verify_payload(folder)
                (folder / 'ResourceProbe').write_bytes(b'tampered executable')
                with self.assertRaises(ValueError):
                    macos14.verify_payload(folder)
                manifest = self.payload(folder)
                manifest['source_commit'] = 'b' * 40
                (folder / 'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(ValueError):
                    macos14.verify_payload(folder)

    def test_unexpected_payload_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            self.payload(folder)
            (folder / 'unexpected').write_bytes(b'not reviewed')
            with patch.object(macos14, 'command', return_value='a' * 40), patch.object(macos14, 'sources', return_value={'source': 'reviewed'}):
                with self.assertRaises(ValueError):
                    macos14.verify_payload(folder)

    def test_wrong_os_never_starts_a_probe(self):
        with patch.object(macos14.platform, 'system', return_value='Darwin'), patch.object(macos14.platform, 'mac_ver', return_value=('15.8.1', (), '')), patch.object(macos14, 'command') as command:
            with self.assertRaises(RuntimeError):
                macos14.run(Path('/unused'), Path('/unused'))
            command.assert_not_called()

    def test_wrong_architecture_never_starts_a_probe(self):
        with patch.object(macos14.platform, 'system', return_value='Darwin'), patch.object(macos14.platform, 'mac_ver', return_value=('14.8.9', (), '')), patch.object(macos14.platform, 'machine', return_value='x86_64'), patch.object(macos14, 'command') as command:
            with self.assertRaises(RuntimeError):
                macos14.run(Path('/unused'), Path('/unused'))
            command.assert_not_called()

    def test_https_request_without_reviewed_https_payload_never_starts_a_probe(self):
        with patch.object(macos14.platform, 'system', return_value='Darwin'), \
             patch.object(macos14.platform, 'mac_ver', return_value=('14.8.9', (), '')), \
             patch.object(macos14.platform, 'machine', return_value='arm64'), \
             patch.object(macos14, 'verify_payload', return_value={'files': {'ResourceProbe': 'verified'}}), \
             patch.object(macos14, 'command') as command:
            with self.assertRaisesRegex(ValueError, 'verified HTTPS payload'):
                macos14.run(Path('/unused'), Path('/unused'), https=True)
            command.assert_not_called()

    def test_read_retry_without_https_opt_in_never_starts_a_probe(self):
        with patch.object(macos14, 'command') as command:
            with self.assertRaisesRegex(ValueError, 'explicit public HTTPS opt-in'):
                macos14.run(Path('/unused'), Path('/unused'), retry=True)
            command.assert_not_called()

    def test_retry_probe_missing_duplicate_and_wrong_attempt_cases_fail(self):
        cases = [{'case': mode + '-' + suffix, 'result': 'passed',
                  'attempt_count': '2' if suffix == 'retry-enabled' else '1', 'transport_code': '-1202'}
                 for mode in ['typed', 'raw'] for suffix in ['retry-disabled', 'retry-enabled', 'retry-tls']]
        good = {'result': 'passed', 'cases': cases}
        macos14.validate_https_observation(good, retry=True)
        for changed in [cases[:-1], cases[:-1] + [cases[0]],
                        [dict(case, attempt_count='0') for case in cases],
                        [dict(case, result='skipped') for case in cases]]:
            with self.subTest(cases=changed), self.assertRaises(RuntimeError):
                macos14.validate_https_observation({'result': 'passed', 'cases': changed}, retry=True)

    def test_original_https_case_set_remains_valid_and_complete(self):
        cases = [{'case': mode + '-' + suffix, 'result': 'passed'}
                 for mode in ['typed', 'raw'] for suffix in ['json', 'empty', 'valid-certificate', 'self-signed', 'wrong-host']]
        macos14.validate_https_observation({'result': 'passed', 'cases': cases})
        with self.assertRaises(RuntimeError):
            macos14.validate_https_observation({'result': 'passed', 'cases': cases[:-1] + [cases[0]]})
