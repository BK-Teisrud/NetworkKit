"""Native CI must reject missing tests, broader selection and incomplete ownership cases."""
import unittest
from native_loopback import IDENTIFIERS, NAMES, MARKERS, validate_discovery, validate_result


class NativeLoopbackContracts(unittest.TestCase):
    def fixture(self):
        xml = '<testsuites><testsuite tests="4" errors="0" failures="0" skipped="0">'
        xml += ''.join('<testcase classname="PublicHTTPSChecksTests.PublicHTTPSTests" name="' + n + '(ownership:)" />' for n in NAMES)
        xml += '</testsuite></testsuites>'
        output = '\n'.join('NativeLoopback ' + m + ' ' + o + ': passed' for m in MARKERS for o in ['owned', 'borrowed'])
        return xml, output

    def test_missing_or_duplicate_selected_discovery_fails(self):
        good = '\n'.join(sorted(IDENTIFIERS))
        validate_discovery(good)
        for bad in ['', '\n'.join(sorted(IDENTIFIERS)[:-1]), good + '\n' + sorted(IDENTIFIERS)[0]]:
            with self.assertRaises(RuntimeError):
                validate_discovery(bad)

    def test_failed_empty_skipped_extra_or_missing_cases_fail(self):
        xml, output = self.fixture()
        validate_result(xml, output)
        for bad in ['<testsuites/>', xml.replace('failures="0"', 'failures="1"'),
                    xml.replace('skipped="0"', 'skipped="1"'),
                    xml.replace(NAMES[0], 'publicHTTPSProbe'),
                    xml.replace('/>', '><failure/></testcase>', 1)]:
            with self.assertRaises(RuntimeError):
                validate_result(bad, output)
        for bad in ['', output.replace('owned:', 'missing:'), output + '\n' + output]:
            with self.assertRaises(RuntimeError):
                validate_result(xml, bad)
