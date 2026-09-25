#!/usr/bin/env python3
"""Validate Paper's signed release assets without launching or installing them."""
import argparse
import hashlib
import io
import json
import pathlib
import plistlib
import subprocess
import tarfile
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], cwd=ROOT)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def tree(path):
    return {str(p.relative_to(path)): ('link:' + str(p.readlink()) if p.is_symlink() else digest(p))
            for p in path.rglob('*') if p.is_file() or p.is_symlink()}


def archive_files(repository, revision, prefix):
    with tarfile.open(fileobj=io.BytesIO(run('git', '-C', repository, 'archive', revision))) as archive:
        return {prefix + member.name: (member.linkname.encode() if member.issym() else archive.extractfile(member).read())
                for member in archive if member.isfile() or member.issym()}


def verify(directory, evidence, revision):
    expected = plistlib.loads(run('git', 'show', f'{revision}:Configuration/Info.plist'))
    version, build = expected['CFBundleShortVersionString'], expected['CFBundleVersion']
    files = [f'Paper-{version}-{suffix}' for suffix in ('arm64.dmg', 'source.zip', 'update.zip')]
    checksums = (directory / 'SHA256SUMS').read_text().splitlines()
    require(checksums == [f'{digest(directory / name)}  {name}' for name in files], 'Checksum manifest mismatch')
    report = dict(version=version, build=build, sourceCommit=run('git', 'rev-parse', f'{revision}^{{commit}}').decode().strip(),
                  assets={name: digest(directory / name) for name in files})
    dmg, source, update = [directory / name for name in files]
    with tempfile.TemporaryDirectory(prefix='paper-release-') as folder:
        stage = pathlib.Path(folder)
        run('ditto', '-x', '-k', update, stage)
        app = stage / 'Paper.app'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        require(info == expected, 'Packaged Info.plist differs from source')
        binary = app / 'Contents/MacOS/Paper'
        require(run('lipo', '-archs', binary).decode().strip() == 'arm64', 'Expected arm64 only')
        require(info['LSMinimumSystemVersion'] == '13.0', 'Deployment target mismatch')
        run('codesign', '--verify', '--deep', '--strict', app)
        run('spctl', '--assess', '--type', 'execute', app)
        run('xcrun', 'stapler', 'validate', app)
        run('codesign', '--verify', '--strict', dmg)
        run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', dmg)
        run('xcrun', 'stapler', 'validate', dmg)
        report['executableSHA256'] = digest(binary)
        require((app / 'Contents/Resources/Licenses/DustWavePlatform-MIT.txt').is_file(), 'Platform license missing')
        mount = stage / 'mount'
        mount.mkdir()
        run('hdiutil', 'attach', dmg, '-readonly', '-nobrowse', '-mountpoint', mount)
        try:
            require((mount / 'Applications').is_symlink() and (mount / 'Applications').readlink() == pathlib.Path('/Applications'), 'Missing Applications link')
            require(tree(mount / 'Paper.app') == tree(app), 'DMG and update app contents differ')
        finally:
            run('hdiutil', 'detach', mount)
    platform = run('git', 'rev-parse', f'{revision}:shared/dust-wave-platform').decode().strip()
    expected_files = archive_files(ROOT, revision, 'Paper/')
    expected_files.update(archive_files(ROOT / 'shared/dust-wave-platform', platform, 'Paper/shared/dust-wave-platform/'))
    with zipfile.ZipFile(source) as archive:
        actual_files = {name: archive.read(name) for name in archive.namelist() if not name.endswith('/')}
        require(actual_files == expected_files, 'Source ZIP differs from exact committed source and Platform pin')
    namespace = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
    feed = directory / 'appcast.xml'
    items = ET.parse(feed).findall('./channel/item')
    require(len(items) == 1, 'Expected one feed item')
    item = items[0]
    require(item.findtext(namespace + 'version') == build, 'Feed build mismatch')
    require(item.findtext(namespace + 'shortVersionString') == version, 'Feed version mismatch')
    require(item.findtext(namespace + 'hardwareRequirements') == 'arm64', 'Feed architecture mismatch')
    require(item.findtext(namespace + 'minimumSystemVersion') == '13.0', 'Feed OS mismatch')
    enclosure = item.find('enclosure')
    require(enclosure is not None, 'Missing update enclosure')
    require(enclosure.get('url') == f'https://github.com/aindaco1/paper/releases/download/v{version}/{update.name}', 'Feed URL mismatch')
    require(int(enclosure.get('length', '0')) == update.stat().st_size, 'Feed archive length mismatch')
    signature = enclosure.get(namespace + 'edSignature')
    require(bool(signature), 'Missing archive signature')
    signer = ROOT / '.build/artifacts/sparkle/Sparkle/bin/sign_update'
    run(signer, '--account', 'xyz.dustwave.paper', '--verify', feed)
    run(signer, '--account', 'xyz.dustwave.paper', '--verify', update, signature)
    report.update(status='passed', signedFeed=True, signedArchive=True, notarizedAppAndDMG=True,
                  mountedDMGMatchesUpdate=True, exactSourceArchive=True)
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Paper {version} ({build}): signatures, notarization, DMG, source, checksums and feed passed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=pathlib.Path, default=ROOT / 'outputs')
    parser.add_argument('--evidence', type=pathlib.Path, default=ROOT / 'outputs/Paper-release-verification.json')
    parser.add_argument('--ref', default='HEAD', help='Source revision, or the published release tag when rechecking')
    args = parser.parse_args()
    verify(args.directory.resolve(), args.evidence.resolve(), args.ref)
