"""Nested library sources must reach the explicit feasibility compiler."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


class FeasibilitySourceContracts(unittest.TestCase):
    def test_nested_sources_and_empty_library(self):
        root = Path(__file__).resolve().parents[2]
        spec = importlib.util.spec_from_file_location("download_feasibility", root / "Tools/DownloadFeasibility/run.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            checkout = Path(folder)
            with self.assertRaises(RuntimeError):
                module.library_sources(checkout)
            names = ["Client/Entry.swift", "HTTP/Value.swift", "Downloads/Value.swift", "NetworkKit.docc/Example.swift"]
            for name in names:
                path = checkout / "Sources/NetworkKit" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// Synthetic source discovery fixture")
            self.assertEqual([p.relative_to(checkout / "Sources/NetworkKit").as_posix()
                              for p in module.library_sources(checkout)], sorted(names[:-1]))
