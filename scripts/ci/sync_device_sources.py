#!/usr/bin/env python3
"""Explicitly refresh shared source membership; validation in CI never repairs drift."""
import hashlib
from pathlib import Path

from device_host import PROJECT, load_project, shared_source_paths, validate
from prepare_device_host import openstep

ROOT = Path(__file__).resolve().parents[2]


def sync_sources(root, project):
    objects = project['objects']
    for target_name, source, prefix in [
        ('NetworkKitDeviceTests', 'Tests/NetworkKitTests', ''),
        ('NetworkKitPublicHTTPSChecks', 'Tools/PublicHTTPSChecks/Tests/PublicHTTPSChecksTests',
         '../PublicHTTPSChecks/Tests/PublicHTTPSChecksTests/'),
    ]:
        target = next(v for v in objects.values() if v.get('isa') == 'PBXNativeTarget' and v.get('name') == target_name)
        phase = next(objects[p] for p in target['buildPhases'] if objects[p]['isa'] == 'PBXSourcesBuildPhase')
        old = {objects[objects[b]['fileRef']]['path']: (b, objects[b]['fileRef']) for b in phase['files']}
        refs = {r for _, r in old.values()}
        groups = [g for g in objects.values() if g.get('isa') == 'PBXGroup' and refs.intersection(g.get('children', []))]
        if len(groups) != 1 or not refs.issubset(groups[0]['children']):
            raise RuntimeError('Shared source references must have one unambiguous source group')
        group = groups[0]
        retained = [c for c in group['children'] if c not in refs]
        files, children = [], []
        for relative in shared_source_paths(root / source):
            path = prefix + relative
            if path in old:
                build, reference = old.pop(path)
            else:
                def identifier(kind):
                    value = hashlib.sha256((target_name + ':' + path + ':' + kind).encode()).hexdigest()[:24].upper()
                    if value in objects:
                        raise RuntimeError('Source identifier collision')
                    return value
                reference, build = identifier('reference'), identifier('build')
                objects[reference] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift',
                                      'path': path, 'sourceTree': '<group>'}
                objects[build] = {'isa': 'PBXBuildFile', 'fileRef': reference}
            files.append(build)
            children.append(reference)
        for build, reference in old.values():
            del objects[build]
            del objects[reference]
        phase['files'] = files
        group['children'] = retained + children
    validate(root, project)


if __name__ == '__main__':
    project = load_project(ROOT)
    sync_sources(ROOT, project)
    (ROOT / PROJECT).write_text('// !$*UTF8*$!\n' + openstep(project) + '\n')
