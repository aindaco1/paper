#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit tracked changes before creating a source package." >&2
    exit 1
fi
./script/build_and_run.sh --build-only
mkdir -p work outputs
stage="$(mktemp -d "$task_root/work/paper-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/dmg" "$stage/source/Paper/shared/dust-wave-platform"
ditto dist/Paper.app "$stage/dmg/Paper.app"
ln -s /Applications "$stage/dmg/Applications"
hdiutil create -volname Paper -srcfolder "$stage/dmg" -ov -format UDZO outputs/Paper-0.1.0-arm64.dmg
git archive HEAD | tar -x -C "$stage/source/Paper"
platform_commit="$(git rev-parse HEAD:shared/dust-wave-platform)"
git -C shared/dust-wave-platform archive "$platform_commit" | tar -x -C "$stage/source/Paper/shared/dust-wave-platform"
ditto -c -k --keepParent "$stage/source/Paper" outputs/Paper-0.1.0-source.zip
ditto dist/Paper.app outputs/Paper.app
node --input-type=module <<'JS'
import { writeFileSync } from 'node:fs';
import { sha256File } from './shared/dust-wave-platform/packages/release-core/src/file-integrity.js';
const files = ['Paper-0.1.0-arm64.dmg', 'Paper-0.1.0-source.zip'];
writeFileSync('outputs/SHA256SUMS', files.map(file => `${sha256File(`outputs/${file}`)}  ${file}\n`).join(''));
JS
