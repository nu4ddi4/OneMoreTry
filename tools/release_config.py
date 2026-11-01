"""Plan branch-specific immutable releases and stamp the exported runtime version."""
import argparse
import json
import re
from pathlib import Path

CORE = r'(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})'


def plan(project: str, presets: str, branch: str, sha: str) -> dict:
    if branch not in ('main', 'beta'):
        raise ValueError('Release branch must be main or beta')
    match = re.search(r'^config/version="(' + CORE + r')"$', project, re.M)
    if not match:
        raise ValueError('Source version must be MAJOR.MINOR.PATCH')
    base = match[1]
    for field in ('file_version', 'product_version'):
        if f'application/{field}="{base}.0"' not in presets:
            raise ValueError('Windows file and product versions must match the source version')
    version = base + ('-beta' if branch == 'beta' else '')
    return dict(schema=1, base_version=base, version=version, tag='v' + version,
                channel='beta' if branch == 'beta' else 'stable',
                prerelease=branch == 'beta', source_sha=sha)


def verify(info: dict, expected: dict, source_sha: str) -> None:
    for field in ('schema', 'base_version', 'version', 'tag', 'channel', 'prerelease'):
        if info.get(field) != expected[field]:
            raise ValueError(f'Artifact release identity mismatch: {field}')
    if info.get('source_sha') != source_sha:
        raise ValueError('Artifact does not belong to the verified source commit')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--branch', required=True, choices=['main', 'beta'])
    parser.add_argument('--sha', required=True)
    parser.add_argument('--stamp', action='store_true')
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--artifact-sha')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    path = Path('project.godot')
    source = path.read_text()
    info = plan(source, Path('export_presets.cfg').read_text(), args.branch, args.sha)
    if args.verify:
        verify(json.loads(args.verify.read_text()), info, args.artifact_sha or args.sha)
    if args.stamp:
        source = re.sub(r'^config/version="[^"]+"$', f'config/version="{info["version"]}"', source, flags=re.M)
        source = re.sub(r'^config/release_channel="[^"]+"$', f'config/release_channel="{info["channel"]}"', source, flags=re.M)
        path.write_text(source)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(info, indent=2) + '\n')
    print(json.dumps(info))


if __name__ == '__main__':
    main()
