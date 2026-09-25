#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
mode="${1:---local}"
case "$mode" in --local|--notarize) ;; *) echo "usage: $0 [--local|--notarize]" >&2; exit 2;; esac
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit tracked changes before creating a source package." >&2
    exit 1
fi
if [[ "$mode" == "--notarize" ]]; then
    PAPER_SIGNING_IDENTITY="$(python3 script/notarize.py identity)"
    export PAPER_SIGNING_IDENTITY
fi
./script/build_and_run.sh --build-only
if [[ "$mode" == "--notarize" ]]; then
    python3 script/notarize.py dist/Paper.app
fi
app_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Paper.app/Contents/Info.plist)"
mkdir -p work outputs
stage="$(mktemp -d "$task_root/work/paper-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/dmg" "$stage/source/Paper/shared/dust-wave-platform"
ditto dist/Paper.app "$stage/dmg/Paper.app"
ln -s /Applications "$stage/dmg/Applications"
hdiutil create -volname Paper -srcfolder "$stage/dmg" -ov -format UDZO "outputs/Paper-$app_version-arm64.dmg"
# Recent DiskImages versions may leave the newly created image attached briefly.
# Detach only this exact output before signing or verifying it.
python3 - "outputs/Paper-$app_version-arm64.dmg" <<'PY'
import pathlib, plistlib, re, subprocess, sys
path = str(pathlib.Path(sys.argv[1]).resolve())
info = plistlib.loads(subprocess.check_output(['hdiutil', 'info', '-plist']))
for image in info.get('images', []):
    if image.get('image-path') == path:
        device = next((entry['dev-entry'] for entry in image.get('system-entities', [])
                       if re.fullmatch(r'/dev/disk\d+', entry.get('dev-entry', ''))), None)
        if device:
            subprocess.run(['hdiutil', 'detach', device], check=True)
PY
if [[ "$mode" == "--notarize" ]]; then
    codesign --force --sign "$PAPER_SIGNING_IDENTITY" --timestamp "outputs/Paper-$app_version-arm64.dmg"
    python3 script/notarize.py "outputs/Paper-$app_version-arm64.dmg"
    cp dist/Paper.app.notary.json outputs/Paper.app.notary.json
fi
git archive HEAD | tar -x -C "$stage/source/Paper"
platform_commit="$(git rev-parse HEAD:shared/dust-wave-platform)"
git -C shared/dust-wave-platform archive "$platform_commit" | tar -x -C "$stage/source/Paper/shared/dust-wave-platform"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$stage/source/Paper" "outputs/Paper-$app_version-source.zip"
ditto dist/Paper.app outputs/Paper.app
ditto -c -k --sequesterRsrc --keepParent dist/Paper.app "outputs/Paper-$app_version-update.zip"
node --input-type=module - "$app_version" <<'JS'
import { writeFileSync } from 'node:fs';
import { sha256File } from './shared/dust-wave-platform/packages/release-core/src/file-integrity.js';
const version = process.argv[2];
const files = [`Paper-${version}-arm64.dmg`, `Paper-${version}-source.zip`, `Paper-${version}-update.zip`];
writeFileSync('outputs/SHA256SUMS', files.map(file => `${sha256File(`outputs/${file}`)}  ${file}\n`).join(''));
JS
