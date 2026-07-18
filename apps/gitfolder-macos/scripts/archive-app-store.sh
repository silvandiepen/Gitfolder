#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ROOT_DIR}/build/GitFolder.xcarchive"
EXPORT_PATH="${ROOT_DIR}/build/AppStore"

cd "${ROOT_DIR}"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

echo "Archiving GitFolder for Mac App Store..."
xcodebuild \
  -project GitFolder.xcodeproj \
  -scheme GitFolder \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  archive

echo "Exporting App Store package..."
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist AppStoreExportOptions.plist \
  -allowProvisioningUpdates

echo "Export complete: ${EXPORT_PATH}"
