#!/bin/bash
# イシューツリー.app を build/ に生成する（Apple Silicon / Intel 両対応）
# 配布用 zip も作る場合: scripts/build-app.sh --zip
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
APP="build/イシューツリー.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release "${ARCHS[@]}" --show-bin-path)/IssueTree" "$APP/Contents/MacOS/IssueTree"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built: $APP"

if [[ "${1:-}" == "--zip" ]]; then
    rm -f build/IssueTree-macOS.zip
    ditto -c -k --keepParent "$APP" build/IssueTree-macOS.zip
    echo "Zipped: build/IssueTree-macOS.zip"
fi
