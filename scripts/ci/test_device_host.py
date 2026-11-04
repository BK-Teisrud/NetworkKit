"""Negative controls: missing coverage or broken hosting must fail before a green run."""
import copy
from pathlib import Path
import unittest
import tempfile
from device_host import load_project, validate, shared_source_paths, validate_membership


class DeviceHostContracts(unittest.TestCase):
    def test_nested_shared_paths_preserve_duplicate_basenames(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ["HTTP/Values.swift", "Downloads/Values.swift"]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// Synthetic membership fixture")
            expected = shared_source_paths(root)
            self.assertEqual(expected, ["Downloads/Values.swift", "HTTP/Values.swift"])
            validate_membership(expected, expected)
            for bad in [["Values.swift", "Values.swift"], expected[:1], expected + expected[:1],
                        ["../HTTP/Values.swift", "Downloads/Values.swift"]]:
                with self.subTest(paths=bad), self.assertRaises(RuntimeError):
                    validate_membership(bad, expected)

    def test_explicit_refresh_is_stable_and_preserves_build_settings(self):
        from sync_device_sources import sync_sources
        from prepare_device_host import openstep
        project = copy.deepcopy(self.project)
        before = {k: copy.deepcopy(v['buildSettings']) for k, v in project['objects'].items()
                  if 'buildSettings' in v}
        sync_sources(self.root, project)
        serialized = openstep(project)
        sync_sources(self.root, project)
        self.assertEqual(openstep(project), serialized)
        self.assertEqual(openstep(dict(reversed(list(project.items())))), serialized)
        self.assertEqual({k: v['buildSettings'] for k, v in project['objects'].items()
                          if 'buildSettings' in v}, before)
        target = next(v for v in project['objects'].values()
                      if v.get('isa') == 'PBXNativeTarget' and v.get('name') == 'NetworkKitDeviceTests')
        phase = next(project['objects'][p] for p in target['buildPhases']
                     if project['objects'][p]['isa'] == 'PBXSourcesBuildPhase')
        phase['files'].append(phase['files'][0])
        with self.assertRaisesRegex(RuntimeError, 'Duplicate existing'):
            sync_sources(self.root, project)

    def test_manual_group_cycle_is_rejected_before_xcode(self):
        from prepare_manual_host import validate_groups
        objects = {'root': {'isa': 'PBXGroup', 'children': ['source']},
                   'source': {'isa': 'PBXFileReference'}}
        validate_groups(objects, 'root')
        objects['root']['children'] = ['root']
        with self.assertRaisesRegex(RuntimeError, 'group cycle'):
            validate_groups(objects, 'root')

    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.project = load_project(cls.root)

    def test_current_host_uses_all_shared_sources(self):
        validate(self.root, self.project)

    def test_omitted_test_file_fails(self):
        project = copy.deepcopy(self.project)
        objects = project["objects"]
        target = next(o for o in objects.values() if o.get("name") == "NetworkKitDeviceTests")
        phase = next(objects[p] for p in target["buildPhases"] if objects[p]["isa"] == "PBXSourcesBuildPhase")
        phase["files"].pop()
        with self.assertRaisesRegex(RuntimeError, "omits or duplicates"):
            validate(self.root, project)

    def test_omitted_optional_native_source_fails(self):
        project = copy.deepcopy(self.project)
        objects = project["objects"]
        target = next(o for o in objects.values() if o.get("name") == "NetworkKitPublicHTTPSChecks")
        phase = next(objects[p] for p in target["buildPhases"] if objects[p]["isa"] == "PBXSourcesBuildPhase")
        phase["files"].pop()
        with self.assertRaisesRegex(RuntimeError, "omits or duplicates"):
            validate(self.root, project)

    def test_tool_host_substitution_fails(self):
        project = copy.deepcopy(self.project)
        for o in project["objects"].values():
            if "TEST_HOST" in o.get("buildSettings", {}):
                o["buildSettings"]["TEST_HOST"] = "xctest"
        with self.assertRaisesRegex(RuntimeError, "not app-hosted"):
            validate(self.root, project)

    def test_remote_package_substitution_fails(self):
        project = copy.deepcopy(self.project)
        package = next(o for o in project["objects"].values() if o["isa"] == "XCLocalSwiftPackageReference")
        package["isa"] = "XCRemoteSwiftPackageReference"
        with self.assertRaisesRegex(RuntimeError, "local package only"):
            validate(self.root, project)

    def test_committed_profile_identifier_fails(self):
        project = copy.deepcopy(self.project)
        settings = next(o["buildSettings"] for o in project["objects"].values()
                        if "PROVISIONING_PROFILE_SPECIFIER" in o.get("buildSettings", {}))
        settings["PROVISIONING_PROFILE_SPECIFIER"] = "private-profile-must-not-be-committed"
        with self.assertRaisesRegex(RuntimeError, "Private signing"):
            validate(self.root, project)
