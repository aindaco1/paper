#!/usr/bin/env python3
"""Generate an Ed25519-signed feed using Paper's Keychain key; no key export."""
import pathlib, plistlib, shutil, subprocess, tempfile, sys, xml.etree.ElementTree as ET
root = pathlib.Path(__file__).resolve().parents[1]
info = plistlib.loads((root / 'outputs/Paper.app/Contents/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
archive = root / f'outputs/Paper-{version}-update.zip'
notes = root / f'docs/releases/{version}.md'
if not archive.is_file() or not notes.is_file(): raise SystemExit('Package the app and write its release notes first.')
with tempfile.TemporaryDirectory(prefix='paper-appcast-') as folder:
    stage = pathlib.Path(folder)
    shutil.copy2(archive, stage / archive.name)
    shutil.copy2(notes, stage / f'{archive.stem}.md')
    subprocess.run([str(root / '.build/artifacts/sparkle/Sparkle/bin/generate_appcast'),
        '--account', 'xyz.dustwave.paper', '--download-url-prefix', f'https://github.com/aindaco1/paper/releases/download/v{version}/',
        '--embed-release-notes', '--link', 'https://github.com/aindaco1/paper', '--maximum-deltas', '0',
        '-o', str(stage / 'appcast.xml'), str(stage)], check=True)
    tree = ET.parse(stage / 'appcast.xml')
    items = tree.findall('./channel/item')
    if len(items) != 1: raise SystemExit('Expected exactly one release in the generated feed.')
    enclosure = items[0].find('enclosure')
    namespace = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
    if enclosure is None or not enclosure.get(namespace + 'edSignature'): raise SystemExit('Unsigned update archive.')
    if items[0].findtext(namespace + 'shortVersionString') != version: raise SystemExit('Feed version mismatch.')
    shutil.copy2(stage / 'appcast.xml', root / 'outputs/appcast.xml')
print('Signed Paper appcast generated.')
