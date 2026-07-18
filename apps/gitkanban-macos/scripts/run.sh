#!/usr/bin/env bash
# Build GitKanban (unsigned) and launch it. Usage: npm run gitkanban:run
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild \
  -project GitKanban.xcodeproj \
  -scheme GitKanban \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="build/Build/Products/Debug/GitKanban.app"
echo "Launching $APP"
open "$APP"
