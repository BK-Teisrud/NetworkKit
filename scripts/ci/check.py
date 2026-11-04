#!/usr/bin/env python3
"""Dependency-free CI driver. Missing tools, destinations, tests, or docs fail closed."""
import json
import hashlib
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
KINDS = ["source-integrity", "macos-core", "ios-core", "watchos-core", "tvos-core", "documentation"]
WORKSPACE = ROOT / ".swiftpm/xcode/package.xcworkspace"
OUTPUT = ROOT / ".build/ci"


def run(*args, capture=False):
    print("+", " ".join(str(a) for a in args), flush=True)
    result = subprocess.run([str(a) for a in args], cwd=ROOT, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def preflight():
    version = run("xcodebuild", "-version", capture=True).strip()
    require(version == "Xcode 26.3\nBuild version 17C529", "Required Xcode 26.3 / 17C529 missing")
    swift = run("xcrun", "swift", "--version", capture=True).strip()
    require("Swift version 6.2.4" in swift, "Expected Swift 6.2.4 missing")
    if os.environ.get("GITHUB_ACTIONS") == "true":
        require(platform.machine() == "arm64", "Expected standard macos-15 arm64 runner")
        require(os.environ.get("DEVELOPER_DIR") == "/Applications/Xcode_26.3.app/Contents/Developer",
                "Explicit Xcode selection missing")
    print(json.dumps({"image": os.environ.get("ImageVersion", "local"),
                      "host": platform.mac_ver()[0], "architecture": platform.machine(),
                      "xcode": version, "swift": swift}), flush=True)
    sdk_versions = {}
    for sdk in ["macosx", "iphoneos", "iphonesimulator", "watchos", "watchsimulator", "appletvos", "appletvsimulator"]:
        sdk_versions[sdk] = run("xcrun", "--sdk", sdk, "--show-sdk-version", capture=True).strip()
        require(sdk_versions[sdk] == "26.2", f"Required {sdk} SDK 26.2 missing")
    print("Verified SDK versions:", json.dumps(sdk_versions, sort_keys=True), flush=True)


def validate_documented_examples(source, guide):
    """Require every published Swift example to be the exact compiled consumer source."""
    compiled = re.findall(r"^// DOC-EXAMPLE: ([a-z]+) BEGIN\n(.*?)^// DOC-EXAMPLE: \1 END$", source, re.M | re.S)
    published = re.findall(r"<!-- DOC-EXAMPLE: ([a-z]+) -->\n```swift\n(.*?)^```$", guide, re.M | re.S)
    require(compiled and published, "Missing compiled or published documentation examples")
    require(len(dict(compiled)) == len(compiled) and len(dict(published)) == len(published),
            "Duplicate documentation example identifier")
    require(dict(compiled) == dict(published), "Published examples differ from compiled consumer source")
    require(len(re.findall(r"^[ \t]*(?:`{3,}|~{3,})[ \t]*swift\b[^\n]*$", guide, re.M | re.I)) == len(published),
            "Untracked or noncanonical Swift documentation fence")


def source_integrity():
    run(sys.executable, ROOT / "scripts/ci/device_host.py")
    manifest = json.loads(run("swift", "package", "dump-package", capture=True))
    require(manifest["name"] == "NetworkKit", "Incorrect package name")
    require(manifest["toolsVersion"]["_version"] == "6.2.0", "Incorrect Swift tools baseline")
    require(manifest["swiftLanguageVersions"] == ["6"], "Swift 6 language mode required")
    require(manifest["dependencies"] == [], "External package dependencies are not authorized")
    require({p["platformName"]: p["version"] for p in manifest["platforms"]}
            == {"ios": "17.0", "macos": "14.0", "watchos": "10.0", "tvos": "17.0"}, "Platform minimums changed")
    require([(t["name"], t["type"]) for t in manifest["targets"]]
            == [("NetworkKit", "regular"), ("NetworkKitTests", "test")], "Unexpected targets/plugins")
    require(manifest["targets"][0].get("resources") == [{"path": "PrivacyInfo.xcprivacy", "rule": {"copy": {}}}],
            "Reviewed privacy manifest must be bundled")
    require(manifest["products"] == [{"name": "NetworkKit", "settings": [], "targets": ["NetworkKit"], "type": {"library": ["automatic"]}}],
            "Unexpected product")
    files = [ROOT / p for p in run("git", "ls-files", capture=True).splitlines()]
    for path in files:
        if path.suffix == ".json":
            json.loads(path.read_text())
        if path.suffix == ".md":
            for target in re.findall(r"\[[^\]]*\]\(([^)\n]+)\)", path.read_text()):
                target = target.strip("<>")
                parts = urlsplit(target)
                if parts.scheme or target.startswith("#"):
                    continue
                require((path.parent / unquote(parts.path)).is_file(), f"Missing local link in {path.relative_to(ROOT)}: {target}")
    for path in (ROOT / "Sources").rglob("*.swift"):
        text = path.read_text()
        require(not re.search(r"\bimport\s+SwiftUI\b", text), "Library SwiftUI import is outside scope")
        require("@unchecked Sendable" not in text, "Unreviewed Sendable exemption")
    require(any("@Test" in p.read_text() for p in (ROOT / "Tests").rglob("*.swift")), "Missing meaningful test declarations")
    workflow = (ROOT / ".github/workflows/ci.yml").read_text()
    match = re.search(r"^        kind: (.+)$", workflow, re.M)
    require(match and json.loads(match[1]) == KINDS, "Mandatory matrix entries missing/reordered")
    for workflow_path in (ROOT / ".github/workflows").glob("*.yml"):
        uses = re.findall(r"uses:\s*(\S+)", workflow_path.read_text())
        require(uses and all(re.fullmatch(r"actions/[\w-]+@[0-9a-f]{40}", use) for use in uses),
                f"Actions must be GitHub-owned and SHA-pinned: {workflow_path.name}")
    validate_documented_examples(
        (ROOT / "Tests/NetworkKitTests/DocumentationExamplesTests.swift").read_text(),
        (ROOT / "Sources/NetworkKit/NetworkKit.docc/IntegrationGuide.md").read_text())
    run("git", "diff", "--check")
    run("python3", "-m", "unittest", "discover", "-s", "scripts/ci", "-p", "test_*.py", "-v")
    print("Manifest, dependencies, source policies, JSON, local file links, workflow matrix/pins, and CI helper tests passed.")


def workspace():
    file = WORKSPACE / "contents.xcworkspacedata"
    if not file.exists():
        WORKSPACE.mkdir(parents=True, exist_ok=True)
        file.write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>')
    schemes = json.loads(run("xcodebuild", "-workspace", WORKSPACE, "-list", "-json", capture=True))
    require("NetworkKit" in schemes["workspace"]["schemes"], "Actual package scheme missing")


def select_device(devices, runtime, prefix):
    candidates = [d for d in devices.get(runtime, []) if d.get("isAvailable") and d["name"].startswith(prefix)]
    require(candidates, f"Missing available {runtime} destination matching {prefix}")
    # Prefer deterministic inventory names; UUIDs are discovered each run, never guessed.
    return sorted(candidates, key=lambda d: (d["name"], d["udid"]))[0]


def validate_summary(summary):
    require(summary["result"] == "Passed", "Test result is not Passed")
    require(summary["totalTestCount"] > 0 and summary["passedTests"] == summary["totalTestCount"], "Missing/empty/incomplete test execution")
    require(summary["failedTests"] == 0 and summary["skippedTests"] == 0 and summary["expectedFailures"] == 0,
            "Failed, skipped, or expected-failure tests are not accepted")


def xcode(*args):
    run("xcodebuild", "-workspace", WORKSPACE, "-scheme", "NetworkKit",
        "-derivedDataPath", OUTPUT / "DerivedData", "-parallel-testing-enabled", "NO",
        "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", *args)


def test_destination(destination, label):
    result = OUTPUT / (label + ".xcresult")
    xcode("-destination", destination, "-destination-timeout", "120", "-resultBundlePath", result, "test")
    summary = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "summary", "--path", result, "--compact", capture=True))
    print(json.dumps(summary, sort_keys=True), flush=True)
    validate_summary(summary)


def manual_host_build(family):
    from prepare_manual_host import prepare
    project = prepare(family)
    run("xcodebuild", "-project", project, "-scheme", "NetworkKitManualChecks",
        "-configuration", "Debug",
        "-destination", "generic/platform=" + family, "-derivedDataPath", OUTPUT / "ManualHost",
        "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "SWIFT_SUPPRESS_WARNINGS=NO", "build")
    from prepare_manual_host import PLATFORMS
    products = OUTPUT / "ManualHost/Build/Products"
    directory = "Debug" if family == "macOS" else "Debug-" + PLATFORMS[family][0]
    relative = "Contents/Info.plist" if family == "macOS" else "Info.plist"
    info = plistlib.loads((products / directory / "NetworkKitDeviceHost.app" / relative).read_bytes())
    require(info.get("NetworkKitManualPlatform") == family, "Manual host lacks actual platform metadata")
    require(info.get("NetworkKitVerificationCommit") == run("git", "rev-parse", "HEAD", capture=True).strip(),
            "Manual host lacks the reviewed checkout identity")
    require(info.get("NetworkKitManualSourceSHA256") == hashlib.sha256(
        (ROOT / "Tools/DeviceTestHost/ManualTransitionHost.swift").read_bytes()).hexdigest(),
            "Manual host source identity missing from actual built Info.plist")
    print("Manual host " + family + ": actual built platform/commit/source identity verified", flush=True)


def platform_check(kind):
    workspace()
    if kind == "macos-core":
        manual_host_build("macOS")
        xcode("-destination", "generic/platform=macOS", "build")
        test_destination("platform=macOS,arch=arm64" if platform.machine() == "arm64" else "platform=macOS,arch=x86_64", "macos")
        return
    settings = {
        "ios-core": ("iOS", "iOS", ["iPhone 17", "iPad (A16)"]),
        "watchos-core": ("watchOS", "watchOS", ["Apple Watch Series 11"]),
        "tvos-core": ("tvOS", "tvOS", ["Apple TV 4K (3rd generation)"]),
    }
    family, platform_name, prefixes = settings[kind]
    runtime = "com.apple.CoreSimulator.SimRuntime." + family + "-26-2"
    runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "-j", capture=True))["runtimes"]
    require(any(r["identifier"] == runtime and r.get("isAvailable") for r in runtimes), f"Required {runtime} unavailable")
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j", capture=True))["devices"]
    destinations = [select_device(devices, runtime, prefix) for prefix in prefixes]
    # Compile physical app-host routes without credentials, deployment or public traffic.
    host_project = ROOT / "Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj"
    if family != "iOS":
        from prepare_device_host import prepare
        host_project = prepare(family)
    for scheme in ["NetworkKitDeviceHost", "PublicHTTPSChecks"]:
        run("xcodebuild", "-project", host_project, "-scheme", scheme,
            "-destination", "generic/platform=" + family,
            "-derivedDataPath", OUTPUT / "DeviceHost", "CODE_SIGNING_ALLOWED=NO", "build-for-testing")
    manual_host_build(family)
    if family == "watchOS":
        phone = select_device(devices, "com.apple.CoreSimulator.SimRuntime.iOS-26-2", "iPhone 17")
        pairs = json.loads(run("xcrun", "simctl", "list", "pairs", "-j", capture=True))["pairs"]
        existing = [p for p in pairs.values() if p.get("watch", {}).get("udid") == destinations[0]["udid"]]
        if existing:
            companions = [d for d in devices.get("com.apple.CoreSimulator.SimRuntime.iOS-26-2", [])
                          if d.get("isAvailable") and d["udid"] == existing[0]["phone"]["udid"]]
            require(companions, "Existing watch pairing lacks an available iOS 26.2 companion")
            phone = companions[0]
        else:
            run("xcrun", "simctl", "pair", destinations[0]["udid"], phone["udid"])
        print("Actual watch companion:", json.dumps({k: phone[k] for k in ["name", "udid", "deviceTypeIdentifier", "state"]}), flush=True)
    print("Selected runtime/destinations:", runtime,
          json.dumps([{k: d[k] for k in ["name", "udid", "deviceTypeIdentifier", "state"]} for d in destinations]), flush=True)
    xcode("-destination", "generic/platform=" + platform_name, "build")
    for index, device in enumerate(destinations):
        # Xcode starts the simulator; no runtime installation or paid infrastructure.
        test_destination("platform=" + platform_name + " Simulator,id=" + device["udid"], family + str(index))


def copy_library_symbol_graphs(source, destination):
    """Keep generated test-runner modules out of the distributed library docs."""
    selected = [p for p in source.glob("NetworkKit*.symbols.json")
                if json.loads(p.read_text())["module"]["name"] == "NetworkKit"]
    require(any(p.name == "NetworkKit.symbols.json" for p in selected),
            "Missing public NetworkKit module graph")
    destination.mkdir(exist_ok=True)
    # This directory is owned by this CI driver; discard stale generated graphs.
    for stale in destination.glob("*.symbols.json"):
        stale.unlink()
    for graph in selected:
        shutil.copyfile(graph, destination / graph.name)


def documentation():
    # SwiftPM also visits its generated test runner module during graph extraction.
    # Build it explicitly so a clean runner has the same modules as a warm checkout.
    run("swift", "build", "--build-tests")
    run("swift", "package", "dump-symbol-graph", "--minimum-access-level", "public")
    graphs = list((ROOT / ".build").glob("*/symbolgraph/NetworkKit.symbols.json"))
    require(len(graphs) == 1, "Missing or ambiguous public NetworkKit symbol graph")
    require(json.loads(graphs[0].read_text())["symbols"], "Empty public API symbol graph")
    public_graphs = OUTPUT / "symbols"
    copy_library_symbol_graphs(graphs[0].parent, public_graphs)
    run("xcrun", "docc", "convert", ROOT / "Sources/NetworkKit/NetworkKit.docc",
        "--additional-symbol-graph-dir", public_graphs, "--output-dir", OUTPUT / "NetworkKit.doccarchive",
        "--warnings-as-errors")
    require((OUTPUT / "NetworkKit.doccarchive/data/documentation/networkkit.json").is_file(), "Missing rendered module documentation")


def main():
    require(len(sys.argv) == 2 and sys.argv[1] in KINDS, "Choose a mandatory CI check kind")
    os.chdir(ROOT)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    preflight()
    kind = sys.argv[1]
    if kind == "source-integrity":
        source_integrity()
    elif kind == "documentation":
        documentation()
    else:
        platform_check(kind)
        if kind == "macos-core":
            # Compile opt-in public-service checks, never execute them in CI.
            run("swift", "build", "--package-path", ROOT / "Tools/PublicHTTPSChecks",
                "--build-tests", "-Xswiftc", "-warnings-as-errors")
            # Compile/exercise the opt-in release harness without volatile timing/RSS thresholds.
            run(sys.executable, ROOT / "scripts/benchmarks/run.py", "--output", OUTPUT / "resource-smoke.json",
                "--repetitions", "1", "--smoke")
            # The allocation inspector remains opt-in; keep its Swift control compiling.
            run("swiftc", "-typecheck", "-parse-as-library", "-swift-version", "6", "-warnings-as-errors",
                ROOT / "scripts/benchmarks/SleepRetentionProbe.swift")


if __name__ == "__main__":
    main()
