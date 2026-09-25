#!/usr/bin/env python3
"""Package App Intents metadata emitted by Xcode's SwiftPM build system."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
bundle = pathlib.Path(sys.argv[1]).resolve()
matches = list((root / '.build').glob('**/Release/Paper-p.build/**/*.swiftconstvalues'))
if not matches:
    raise SystemExit('App Intents compiler metadata missing. Build with Xcode 27 or later using its default SwiftPM build system.')
directory = max(matches, key=lambda path: path.stat().st_mtime).parent
stage = root / 'dist' / 'intent-metadata'
stage.mkdir(parents=True, exist_ok=True)
sources = stage / 'sources.txt'
constants = stage / 'constants.txt'
sources.write_text('\n'.join(str(p) for p in sorted((root / 'Sources/Paper').rglob('*.swift'))) + '\n')
constants.write_text('\n'.join(str(p) for p in sorted(directory.glob('*.swiftconstvalues'))) + '\n')

def output(*args):
    return subprocess.check_output(args, text=True).strip()

toolchain = pathlib.Path(output('xcrun', '--find', 'swiftc')).resolve().parents[2]
subprocess.run(['xcrun', 'appintentsmetadataprocessor', '--output', str(bundle / 'Contents/Resources'),
    '--toolchain-dir', str(toolchain), '--module-name', 'Paper', '--sdk-root', output('xcrun', '--show-sdk-path'),
    '--xcode-version', output('xcodebuild', '-version').splitlines()[-1].split()[-1],
    '--platform-family', 'macOS', '--deployment-target', '13.0', '--target-triple', 'arm64-apple-macosx13.0',
    '--source-file-list', str(sources), '--swift-const-vals-list', str(constants)], check=True)
if not (bundle / 'Contents/Resources/Metadata.appintents/extract.actionsdata').is_file():
    raise SystemExit('App Intents extraction produced no actions. Refusing to package an undiscoverable app.')
