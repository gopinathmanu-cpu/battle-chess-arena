#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Preserve installed package notices; run after flutter pub get and npm ci.

This collects evidence, not an automatic legal compatibility decision.
"""
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs' / 'licenses'
DEST.mkdir(exist_ok=True)
rows = []
config = json.loads((ROOT / '.dart_tool/package_config.json').read_text())
for package in config['packages']:
    name = package['name']
    if name == 'battle_chess_arena':
        continue
    folder = Path(unquote(urlparse(package['rootUri']).path))
    if not folder.is_absolute():
        folder = (ROOT / '.dart_tool' / folder).resolve()
    license_path = folder / 'LICENSE'
    if name in ('flutter_test', 'flutter_web_plugins'):
        license_path = folder.parent.parent / 'LICENSE'
    data = license_path.read_bytes()  # Missing notices fail the collector.
    text = data.decode('utf-8')
    pubspec = (folder / 'pubspec.yaml').read_text()
    version = re.search(r'^version:\s*[\'"]?([^\s\'"]+)', pubspec, re.M)
    source = re.search(r'^(?:repository|homepage):\s*[\'"]?(https?://[^\s\'"]+)', pubspec, re.M)
    if name == 'sky_engine':
        license_id = 'Flutter engine aggregate; see full notices'
    elif 'GNU GENERAL PUBLIC LICENSE' in text:
        license_id = 'GPL-3.0'
    elif 'Permission is hereby granted, free of charge' in text and 'THE SOFTWARE IS PROVIDED' in text:
        license_id = 'MIT'
    elif 'Apache License' in text:
        license_id = 'Apache-2.0'
    elif 'Neither the name' in text or 'neither the name' in text:
        license_id = 'BSD-3-Clause'
    else:
        raise RuntimeError(f'Review license of {name}')
    source_url = source.group(1) if source else 'https://github.com/flutter/flutter'
    filename = f'{name}.txt'
    (DEST / filename).write_bytes(data)
    rows.append((name, version.group(1) if version else 'Flutter SDK', license_id, source_url, filename, hashlib.sha256(data).hexdigest()))
for name in ['chess.js', 'ws']:
    folder = ROOT / 'server/node_modules' / name
    metadata = json.loads((folder / 'package.json').read_text())
    data = (folder / 'LICENSE').read_bytes()
    filename = f'{name}.txt'
    (DEST / filename).write_bytes(data)
    repo = metadata['repository']
    source_url = repo['url'] if isinstance(repo, dict) else repo
    rows.append((name, metadata['version'], metadata['license'], source_url.replace('git+', ''), filename, hashlib.sha256(data).hexdigest()))
header = '''# Installed dependency licence inventory

Collected from the resolved packages for Milestone 4 on 2026-09-05.
Full upstream copyright and licence texts are preserved in `licenses/`.
Regenerate with `python3 tool/collect_licenses.py` after installing dependencies.
The collector identifies common licence text; human review remains required.
`sky_engine` contains the engine's consolidated third-party notices and is not
accurately described by one SPDX identifier. Review the actual native binary's
notice/source bundle before distribution. No native release is certified here.

| Package | Version | Licence | Source | Full notice |
| --- | --- | --- | --- | --- |
'''
lines = [f'| {name} | {version} | {license_id} | [Upstream]({source}) | [{filename}](licenses/{filename}) |'
         for name, version, license_id, source, filename, _ in rows]
(ROOT / 'docs/DEPENDENCY_LICENSES.md').write_text(header + '\n'.join(lines) + '\n')
(DEST / 'SHA256SUMS').write_text(''.join(f'{digest}  {filename}\n' for *_, filename, digest in rows))
print(f'Preserved {len(rows)} dependency notice files.')
