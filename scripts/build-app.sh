#!/bin/bash
# IssueTree.app を build/ に生成する
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="build/イシューツリー.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/IssueTree" "$APP/Contents/MacOS/IssueTree"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built: $APP"
