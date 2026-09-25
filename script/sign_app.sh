#!/usr/bin/env bash
# Sparkle inside-out signing adapted from Record (MIT).
set -euo pipefail
app="$1"
identity="${PAPER_SIGNING_IDENTITY:--}"
flags=(--force --sign "$identity")
if [[ "$identity" == - ]]; then
    flags+=(--timestamp=none --options 0)
else
    flags+=(--timestamp --options runtime)
fi
framework="$app/Contents/Frameworks/Sparkle.framework"
current="$framework/Versions/Current"
xattr -cr "$app"
codesign "${flags[@]}" "$current/XPCServices/Installer.xpc"
codesign "${flags[@]}" --preserve-metadata=entitlements "$current/XPCServices/Downloader.xpc"
codesign "${flags[@]}" "$current/Autoupdate"
codesign "${flags[@]}" "$current/Updater.app"
codesign "${flags[@]}" "$framework"
codesign "${flags[@]}" "$app"
codesign --verify --deep --strict "$app"
