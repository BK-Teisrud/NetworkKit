#!/usr/bin/env python3
"""Prepare an unsigned, explicit manual-transition app from validated shared host metadata."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import subprocess

from device_host import load_project, validate
from prepare_device_host import openstep

ROOT = Path(__file__).resolve().parents[2]
PLATFORMS = {
    'iOS': ('iphoneos', 'iphoneos iphonesimulator', 'IPHONEOS_DEPLOYMENT_TARGET', '18.0', '1,2'),
    'macOS': ('macosx', 'macosx', 'MACOSX_DEPLOYMENT_TARGET', '15.0', None),
    'watchOS': ('watchos', 'watchos watchsimulator', 'WATCHOS_DEPLOYMENT_TARGET', '11.0', '4'),
    'tvOS': ('appletvos', 'appletvos appletvsimulator', 'TVOS_DEPLOYMENT_TARGET', '18.0', '3'),
}


def validate_groups(objects, root, ancestors=frozenset()):
    if root in ancestors:
        raise RuntimeError('Manual host group cycle; Xcode project not written')
    group = objects[root]
    if group.get('isa') == 'PBXGroup':
        for child in group.get('children', []):
            validate_groups(objects, child, ancestors | {root})


def prepare(platform):
    project = load_project(ROOT)
    validate(ROOT, project)
    objects = project['objects']
    settings = objects[project['rootObject']]
    host_id, host = next((k, v) for k, v in objects.items()
                         if v.get('isa') == 'PBXNativeTarget' and v.get('name') == 'NetworkKitDeviceHost')
    source_id, source = next((k, v) for k, v in objects.items()
                             if v.get('isa') == 'PBXFileReference' and v.get('path') == 'AppDelegate.swift')
    source['path'] = str(ROOT / 'Tools/DeviceTestHost/ManualTransitionHost.swift')
    source_group = next(k for k, v in objects.items()
                        if v.get('isa') == 'PBXGroup' and source_id in v.get('children', []))
    product = next(k for k, v in objects.items()
                   if v.get('isa') == 'XCSwiftPackageProductDependency' and v.get('productName') == 'NetworkKit')
    link = next(k for k, v in objects.items() if v.get('isa') == 'PBXBuildFile' and v.get('productRef') == product)
    host['packageProductDependencies'] = [product]
    for phase in host['buildPhases']:
        if objects[phase]['isa'] == 'PBXFrameworksBuildPhase':
            objects[phase]['files'] = [link]
    settings['targets'] = [host_id]
    settings['attributes'] = {'LastUpgradeCheck': '2630'}
    # The base host may place its source directly in the main group.
    source_entry = source_id if source_group == settings['mainGroup'] else source_group
    objects[settings['mainGroup']]['children'] = [source_entry, settings['productRefGroup']]
    objects[settings['productRefGroup']]['children'] = [host['productReference']]
    sdk, supported, deployment, minimum, family = PLATFORMS[platform]
    inputs = [ROOT / 'Tools/DeviceTestHost/ManualTransitionHost.swift',
              ROOT / 'Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/project.pbxproj', Path(__file__).resolve()]
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    for value in objects.values():
        if value.get('isa') != 'XCBuildConfiguration':
            continue
        build = value['buildSettings']
        for key in ['IPHONEOS_DEPLOYMENT_TARGET', 'TARGETED_DEVICE_FAMILY']:
            build.pop(key, None)
        for key in list(build):
            if key.startswith('INFOPLIST_KEY_'):
                del build[key]
        build.update({'SDKROOT': sdk, 'SUPPORTED_PLATFORMS': supported, deployment: minimum,
                      'CODE_SIGNING_ALLOWED': 'NO', 'GENERATE_INFOPLIST_FILE': 'NO',
                      'INFOPLIST_FILE': 'Info.plist'})
        if family:
            build['TARGETED_DEVICE_FAMILY'] = family
    seen = set()
    def visit(value):
        if isinstance(value, str) and value in objects and value not in seen:
            seen.add(value)
            visit(objects[value])
        elif isinstance(value, dict):
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    visit(project['rootObject'])
    project['objects'] = {k: v for k, v in objects.items() if k in seen}
    validate_groups(project['objects'], settings['mainGroup'])
    output = ROOT / '.build' / ('manual-host-' + platform.lower()) / 'NetworkKitManualChecks.xcodeproj'
    output.mkdir(parents=True, exist_ok=True)
    info = {'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleExecutable': '$(EXECUTABLE_NAME)',
            'CFBundleName': '$(PRODUCT_NAME)', 'CFBundleDisplayName': 'NetworkKit manual checks',
            'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1',
            'NetworkKitManualPlatform': platform, 'NetworkKitVerificationCommit': commit,
            'NetworkKitManualSourceSHA256': hashes['Tools/DeviceTestHost/ManualTransitionHost.swift']}
    if platform == 'macOS':
        info.update({'NSPrincipalClass': 'NSApplication', 'LSMinimumSystemVersion': minimum})
    elif platform == 'watchOS':
        info.update({'WKApplication': True, 'WKWatchOnly': True, 'WKRunsIndependentlyOfCompanionApp': True})
    else:
        info.update({'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False,
                                                    'UISceneConfigurations': {}}, 'UILaunchScreen': {}})
    (output.parent / 'Info.plist').write_bytes(plistlib.dumps(info))
    (output / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + openstep(project) + '\n')
    schemes = output / 'xcshareddata/xcschemes'
    schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{host_id}" BuildableName="NetworkKitDeviceHost.app" BlueprintName="NetworkKitDeviceHost" ReferencedContainer="container:NetworkKitManualChecks.xcodeproj"/>'
    (schemes / 'NetworkKitManualChecks.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="NO" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction></Scheme>''')
    (output.parent / 'provenance.json').write_text(json.dumps({'platform': platform, 'minimum': minimum,
        'source_commit': commit, 'source_hashes': hashes, 'unsigned_by_default': True,
        'manual_requests_only': True, 'app_id': 'no.teisruddevelopment.NetworkKitDeviceHost'}, indent=2) + '\n')
    print('Prepared unsigned manual transition app: ' + str(output.relative_to(ROOT)))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=PLATFORMS, required=True)
    prepare(parser.parse_args().platform)
