#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
mode="${1:-run}"
case "$mode" in run|--verify|--build-only|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [--verify|--build-only|--debug|--logs|--telemetry]" >&2; exit 2;; esac
app_bundle="$task_root/dist/Paper.app"
# Restrict termination to this project's own app path.
if [[ "$mode" != "--build-only" ]]; then
    python3 - "$app_bundle/Contents/MacOS/Paper" <<'PY'
import os,signal,subprocess,sys
for row in subprocess.check_output(['/bin/ps','-axo','pid=,comm='],text=True).splitlines():
    fields=row.strip().split(None,1)
    if len(fields)==2 and fields[1]==sys.argv[1]:
        try: os.kill(int(fields[0]),signal.SIGTERM)
        except ProcessLookupError: pass
PY
fi
swift build -c release --arch arm64
binary_root="$(swift build -c release --arch arm64 --show-bin-path)"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources/Licenses"
install -m 0755 "$binary_root/Paper" "$app_bundle/Contents/MacOS/Paper"
install -m 0644 Configuration/Info.plist "$app_bundle/Contents/Info.plist"
cp Licenses/*.txt "$app_bundle/Contents/Resources/Licenses/"
cp LICENSE "$app_bundle/Contents/Resources/Licenses/Paper-MIT.txt"
cp THIRD_PARTY_NOTICES.md "$app_bundle/Contents/Resources/"
swift script/generate_icon.swift "$task_root/dist"
iconutil -c icns "$task_root/dist/Paper.iconset" -o "$app_bundle/Contents/Resources/Paper.icns"
# A local development signature. Public distribution needs Developer ID + notarization.
codesign --force --sign - --options runtime "$app_bundle"
codesign --verify --deep --strict "$app_bundle"
plutil -lint "$app_bundle/Contents/Info.plist"
[[ "$(lipo -archs "$app_bundle/Contents/MacOS/Paper")" == "arm64" ]]
case "$mode" in
    --build-only) echo "$app_bundle" ;;
    --debug) lldb -- "$app_bundle/Contents/MacOS/Paper" ;;
    --logs|--telemetry)
        open -n "$app_bundle"
        /usr/bin/log stream --info --style compact --predicate 'process == "Paper"'
        ;;
    --verify)
        open -n "$app_bundle"
        sleep 2
        pgrep -x Paper >/dev/null
        echo "Paper built and launched."
        ;;
    run) open -n "$app_bundle" ;;
esac

