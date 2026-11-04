#!/usr/bin/env python3
"""Derive explicit Watch/TV test projects from the validated shared iOS host."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from device_host import load_project, validate

ROOT = Path(__file__).resolve().parents[2]
VARIANTS = {
    'tvOS': ('appletvos', 'appletvsimulator', 'TVOS_DEPLOYMENT_TARGET', '18.0', '3'),
    'watchOS': ('watchos', 'watchsimulator', 'WATCHOS_DEPLOYMENT_TARGET', '11.0', '4'),
}


def openstep(value):
    if isinstance(value, dict):
        return '{\n' + ''.join(json.dumps(str(k)) + ' = ' + openstep(v) + ';\n' for k, v in sorted(value.items())) + '}'
    if isinstance(value, list):
        return '(' + ','.join(openstep(v) for v in value) + ')'
    return json.dumps(str(value))


def prepare(platform):
    project = load_project(ROOT)
    validate(ROOT, project)  # Complete current sources, ownership and signing boundaries.
    sdk, simulator, deployment, minimum, family = VARIANTS[platform]
    objects = project['objects']
    host = next(v for v in objects.values() if v.get('isa') == 'PBXNativeTarget'
                and v.get('name') == 'NetworkKitDeviceHost')
    for value in objects.values():
        if value.get('isa') == 'XCBuildConfiguration':
            settings = value['buildSettings']
            settings.pop('IPHONEOS_DEPLOYMENT_TARGET', None)
            settings.update({'SDKROOT': sdk, deployment: minimum, 'TARGETED_DEVICE_FAMILY': family,
                             'SUPPORTED_PLATFORMS': sdk + ' ' + simulator, 'CODE_SIGNING_ALLOWED': 'NO'})
        if value.get('isa') == 'PBXFileReference':
            path = value.get('path', '')
            if path == 'AppDelegate.swift':
                value['path'] = '../../Tools/DeviceTestHost/AppDelegate.swift'
            elif path.startswith('../PublicHTTPSChecks/'):
                value['path'] = '../../Tools/' + path[3:]
    if platform == 'watchOS':
        for reference in objects[host['buildConfigurationList']]['buildConfigurations']:
            settings = objects[reference]['buildSettings']
            for key in list(settings):
                if key.startswith('INFOPLIST_KEY_UI'):
                    del settings[key]
            settings.update({'INFOPLIST_KEY_WKApplication': 'YES', 'INFOPLIST_KEY_WKWatchOnly': 'YES',
                             'INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp': 'YES'})
    output = ROOT / '.build' / ('device-host-' + platform.lower()) / 'NetworkKitDeviceHost.xcodeproj'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + openstep(project) + '\n')
    source = ROOT / 'Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/xcshareddata/xcschemes'
    schemes = output / 'xcshareddata/xcschemes'
    schemes.mkdir(parents=True, exist_ok=True)
    for file in source.glob('*.xcscheme'):
        shutil.copy2(file, schemes / file.name)
    inputs = [ROOT / 'Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj/project.pbxproj',
              ROOT / 'Tools/DeviceTestHost/AppDelegate.swift', Path(__file__).resolve()]
    record = {'platform': platform, 'minimum': minimum, 'unsigned_by_default': True,
              'source_hashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}}
    (output.parent / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Prepared unsigned ' + platform + ' project: ' + str(output.relative_to(ROOT)))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=VARIANTS, required=True)
    prepare(parser.parse_args().platform)
