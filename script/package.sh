#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit tracked changes before creating a source package." >&2
    exit 1
fi
./script/build_and_run.sh --build-only
app_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/Paper.app/Contents/Info.plist)"
mkdir -p work outputs
stage="$(mktemp -d "$task_root/work/paper-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/dmg" "$stage/source/Paper/shared/dust-wave-platform"
ditto dist/Paper.app "$stage/dmg/Paper.app"
ln -s /Applications "$stage/dmg/Applications"
hdiutil create -volname Paper -srcfolder "$stage/dmg" -ov -format UDZO "outputs/Paper-$app_version-arm64.dmg"
git archive HEAD | tar -x -C "$stage/source/Paper"
platform_commit="$(git rev-parse HEAD:shared/dust-wave-platform)"
git -C shared/dust-wave-platform archive "$platform_commit" | tar -x -C "$stage/source/Paper/shared/dust-wave-platform"
ditto -c -k --keepParent "$stage/source/Paper" "outputs/Paper-$app_version-source.zip"
ditto dist/Paper.app outputs/Paper.app
node --input-type=module - "$app_version" <<'JS'
import { writeFileSync } from 'node:fs';
import { sha256File } from './shared/dust-wave-platform/packages/release-core/src/file-integrity.js';
const version = process.argv[2];
const files = [`Paper-${version}-arm64.dmg`, `Paper-${version}-source.zip`];
writeFileSync('outputs/SHA256SUMS', files.map(file => `${sha256File(`outputs/${file}`)}  ${file}\n`).join(''));
JS
