#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# build-release-macos.sh
# Builds Conlang Workbench for macOS in release mode, ad-hoc signs it, and
# produces a distributable zip archive suitable for GitHub Releases.
#
# Usage: bash scripts/build-release-macos.sh [version]
#   version  Optional. Overrides the version in pubspec.yaml (e.g. 1.0.3).
#            If omitted, the pubspec.yaml version is used.
# Output: Conlang-Workbench-{version}-macos.zip at the project root
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

APP_NAME="Conlang Workbench"

# Use provided version or fall back to pubspec.yaml
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  # Update pubspec.yaml version (preserve build number as +1)
  sed -i '' "s/^version: .*/version: ${VERSION}+1/" pubspec.yaml
  echo "Version set to ${VERSION}"
else
  VERSION=$(grep '^version:' pubspec.yaml | head -1 | sed 's/version: //' | sed 's/+.*//' | tr -d ' ')
fi

echo "Building ${APP_NAME} v${VERSION} for macOS..."

flutter build macos --release

APP_DIR="build/macos/Build/Products/Release"
ZIP_NAME="Conlang-Workbench-${VERSION}-macos.zip"

echo "Ad-hoc signing ${APP_NAME}.app..."
codesign --deep --force --sign - "${APP_DIR}/${APP_NAME}.app"
codesign --verify --deep --strict "${APP_DIR}/${APP_NAME}.app"
echo "Signature OK"

echo "Creating release archive: ${ZIP_NAME}"
(cd "${APP_DIR}" && ditto -c -k --keepParent "${APP_NAME}.app" "${PROJECT_ROOT}/${ZIP_NAME}")

ZIP_SIZE=$(du -sh "${PROJECT_ROOT}/${ZIP_NAME}" | cut -f1)

echo ""
echo "Release zip created successfully."
echo "  Path: ${PROJECT_ROOT}/${ZIP_NAME}"
echo "  Size: ${ZIP_SIZE}"
