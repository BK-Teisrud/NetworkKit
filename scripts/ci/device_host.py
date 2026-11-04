#!/usr/bin/env python3
"""Validate the checked-in app-host wiring and complete shared test-source membership."""
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

PROJECT = "Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/project.pbxproj"


def load_project(root):
    return json.loads(subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(root / PROJECT)],
        check=True, text=True, capture_output=True).stdout)


def shared_source_paths(directory):
    """Use paths relative to the source group, never flattened basenames."""
    paths = sorted(p.relative_to(directory).as_posix() for p in directory.rglob("*.swift") if p.is_file())
    if not paths:
        raise RuntimeError("Missing shared Swift sources")
    return paths


def validate_membership(actual, expected):
    if sorted(actual) != sorted(expected) or len(set(actual)) != len(actual):
        raise RuntimeError("Host omits or duplicates shared test sources")


def validate(root, project):
    def require(condition, message):
        if not condition:
            raise RuntimeError(message)

    objects = project["objects"]
    targets = {o["name"]: o for o in objects.values() if o["isa"] == "PBXNativeTarget"}
    require(set(targets) == {"NetworkKitDeviceHost", "NetworkKitDeviceTests", "NetworkKitPublicHTTPSChecks"}, "Unexpected host targets")
    host, tests = targets["NetworkKitDeviceHost"], targets["NetworkKitDeviceTests"]
    require(host["productType"] == "com.apple.product-type.application", "Missing app host")
    require(tests["productType"] == "com.apple.product-type.bundle.unit-test", "Missing unit-test bundle")
    test_phases = [objects[p] for p in tests["buildPhases"] if objects[p]["isa"] == "PBXSourcesBuildPhase"]
    require(len(test_phases) == 1, "Missing or duplicate test source phase")
    references = [objects[objects[b]["fileRef"]] for b in test_phases[0]["files"]]
    require(all(r.get("sourceTree") == "<group>" for r in references), "Shared test reference changes directory")
    actual = [r["path"] for r in references]
    expected = shared_source_paths(root / "Tests/NetworkKitTests")
    validate_membership(actual, expected)
    groups = [g for g in objects.values() if g["isa"] == "PBXGroup" and g.get("path") == "../../Tests/NetworkKitTests"]
    require(len(groups) == 1, "Missing shared test directory")
    require(set(groups[0]["children"]) == {objects[b]["fileRef"] for b in test_phases[0]["files"]}, "Test group/source membership differs")
    packages = [p for p in objects.values() if p["isa"] in {"XCLocalSwiftPackageReference", "XCRemoteSwiftPackageReference"}]
    require(len(packages) == 1 and packages[0]["isa"] == "XCLocalSwiftPackageReference"
            and packages[0]["relativePath"] == "../..", "Host must use this local package only")
    dependencies = [objects[p] for p in tests["packageProductDependencies"]]
    require(len(dependencies) == 1 and dependencies[0]["productName"] == "NetworkKit", "Wrong test package product")
    require(any(objects[d].get("target") in objects and objects[objects[d]["target"]] is host
                for d in tests["dependencies"]), "Tests do not build their app host")
    for c in objects[tests["buildConfigurationList"]]["buildConfigurations"]:
        b = objects[c]["buildSettings"]
        require(b.get("TEST_HOST") == "$(BUILT_PRODUCTS_DIR)/NetworkKitDeviceHost.app/NetworkKitDeviceHost"
                and b.get("BUNDLE_LOADER") == "$(TEST_HOST)", "Tests are not app-hosted")
    project_settings = objects[project["rootObject"]]
    for c in objects[project_settings["buildConfigurationList"]]["buildConfigurations"]:
        b = objects[c]["buildSettings"]
        require(b.get("IPHONEOS_DEPLOYMENT_TARGET") == "17.0" and b.get("SWIFT_VERSION") == "6.0",
                "Host deployment/language differs from approved baseline")
    forbidden = {"DEVELOPMENT_TEAM", "CODE_SIGN_IDENTITY", "PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER", "CODE_SIGN_ENTITLEMENTS"}
    for o in objects.values():
        settings = dict(o.get("buildSettings", {}))
        if settings.get("PROVISIONING_PROFILE_SPECIFIER") == "$(NETWORKKIT_DEVICE_PROFILE)":
            del settings["PROVISIONING_PROFILE_SPECIFIER"]
        require(not forbidden.intersection(settings), "Private signing/entitlement settings in project")
    scheme = ET.parse(root / "Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/xcshareddata/xcschemes/NetworkKitDeviceHost.xcscheme")
    testables = scheme.findall("./TestAction/Testables/TestableReference")
    require(len(testables) == 1 and testables[0].get("skipped") == "NO", "Missing/skipped host tests")
    reference = testables[0].find("BuildableReference")
    require(reference is not None and objects.get(reference.get("BlueprintIdentifier")) is tests,
            "Scheme does not test the shared test target")
    require(not any(scheme.findall(".//" + tag) for tag in ["SkippedTests", "SelectedTests", "TestPlans"]),
            "Host scheme must not silently filter shared tests")
    public = targets["NetworkKitPublicHTTPSChecks"]
    public_sources = [objects[p] for p in public["buildPhases"] if objects[p]["isa"] == "PBXSourcesBuildPhase"]
    require(len(public_sources) == 1, "Unexpected public probe source phases")
    public_paths = [objects[objects[item]["fileRef"]]["path"] for item in public_sources[0]["files"]]
    source_root = root / "Tools/PublicHTTPSChecks/Tests/PublicHTTPSChecksTests"
    expected_public = sorted("../PublicHTTPSChecks/Tests/PublicHTTPSChecksTests/" + str(p.relative_to(source_root))
                             for p in source_root.rglob("*.swift") if p.is_file())
    require(sorted(public_paths) == expected_public and len(set(public_paths)) == len(public_paths),
            "Opt-in probe omits or duplicates shared native sources")
    public_scheme = ET.parse(root / "Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/xcshareddata/xcschemes/PublicHTTPSChecks.xcscheme")
    refs = public_scheme.findall("./TestAction/Testables/TestableReference")
    require(len(refs) == 1 and refs[0].get("skipped") == "NO"
            and objects.get(refs[0].find("BuildableReference").get("BlueprintIdentifier")) is public,
            "Public probe must use its own explicit scheme")
    for c in objects[public["buildConfigurationList"]]["buildConfigurations"]:
        require(objects[c]["buildSettings"].get("TEST_HOST") == "$(BUILT_PRODUCTS_DIR)/NetworkKitDeviceHost.app/NetworkKitDeviceHost",
                "Public probe is not app-hosted")
    print(f"Device host: {len(actual)} shared test/helper files; local package and app-host wiring verified")


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    validate(root, load_project(root))
