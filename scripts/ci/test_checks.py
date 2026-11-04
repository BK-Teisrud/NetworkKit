"""Regression tests for fail-closed CI infrastructure, not product behavior."""
import unittest
import json
import tempfile
from pathlib import Path
from check import select_device, validate_summary, validate_documented_examples, copy_library_symbol_graphs


class CheckContracts(unittest.TestCase):
    def test_library_docs_exclude_renamed_test_runner_and_stale_graphs(self):
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / "source", Path(folder) / "output"
            source.mkdir()
            output.mkdir()
            for name in ["NetworkKit", "NetworkKitPackageTests"]:
                (source / (name + ".symbols.json")).write_text(
                    json.dumps({"module": {"name": name}}))
            (output / "NetworkKitPackageTests.symbols.json").write_text("stale")
            copy_library_symbol_graphs(source, output)
            self.assertEqual([p.name for p in output.iterdir()], ["NetworkKit.symbols.json"])
            (source / "NetworkKit.symbols.json").unlink()
            with self.assertRaises(RuntimeError):
                copy_library_symbol_graphs(source, output)

    def test_documentation_drift_and_missing_or_duplicate_blocks_fail(self):
        source = "// DOC-EXAMPLE: demo BEGIN\nlet value = 1\n// DOC-EXAMPLE: demo END\n"
        guide = "<!-- DOC-EXAMPLE: demo -->\n```swift\nlet value = 1\n```\n"
        validate_documented_examples(source, guide)
        for changed in [guide.replace("value = 1", "value = 2"), "", guide + guide,
                        guide + "```swift\nlet hidden = 3\n```\n"]:
            with self.subTest(guide=changed), self.assertRaises(RuntimeError):
                validate_documented_examples(source, changed)
        for fence in ["```swift title=extra", "~~~swift", "````swift", "  ```swift", "```Swift"]:
            with self.subTest(fence=fence), self.assertRaises(RuntimeError):
                validate_documented_examples(source, guide + fence + "\nlet unchecked = 2\n```\n")
        with self.assertRaises(RuntimeError):
            validate_documented_examples(source + source, guide)

    def test_missing_runtime_and_unavailable_device_fail(self):
        for devices in [{}, {"runtime": [{"name": "iPhone 17", "udid": "x", "isAvailable": False}]}]:
            with self.assertRaises(RuntimeError):
                select_device(devices, "runtime", "iPhone")

    def test_selected_device_is_available_and_exact_runtime(self):
        devices = {"old": [{"name": "iPhone 17", "udid": "old", "isAvailable": True}],
                   "runtime": [{"name": "iPad", "udid": "pad", "isAvailable": True},
                               {"name": "iPhone 17", "udid": "phone", "isAvailable": True}]}
        self.assertEqual(select_device(devices, "runtime", "iPhone")["udid"], "phone")

    def test_empty_failed_and_skipped_runs_fail(self):
        good = dict(result="Passed", totalTestCount=2, passedTests=2, failedTests=0, skippedTests=0, expectedFailures=0)
        validate_summary(good)
        for change in [dict(totalTestCount=0, passedTests=0), dict(result="Failed"), dict(failedTests=1),
                       dict(skippedTests=1), dict(expectedFailures=1), dict(passedTests=1)]:
            with self.assertRaises(RuntimeError):
                validate_summary(dict(good, **change))


if __name__ == "__main__":
    unittest.main()
