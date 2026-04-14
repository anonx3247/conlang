#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# build-release-macos.sh
# Builds Conlang Workbench for macOS in release mode and produces a
# distributable zip archive suitable for GitHub Releases.
#
# Usage: bash scripts/build-release-macos.sh
# Output: Conlang-Workbench-{version}-macos.zip at the project root
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

APP_NAME="Conlang Workbench"
VERSION=$(grep '^version:' pubspec.yaml | head -1 | sed 's/version: //' | sed 's/+.*//' | tr -d ' ')

echo "Building ${APP_NAME} v${VERSION} for macOS..."

flutter build macos --release

APP_DIR="build/macos/Build/Products/Release"
ZIP_NAME="Conlang-Workbench-${VERSION}-macos.zip"

echo "Creating release archive: ${ZIP_NAME}"

(cd "${APP_DIR}" && zip -r -y "${PROJECT_ROOT}/${ZIP_NAME}" "${APP_NAME}.app")

ZIP_SIZE=$(du -sh "${PROJECT_ROOT}/${ZIP_NAME}" | cut -f1)

echo ""
echo "Release zip created successfully."
echo "  Path: ${PROJECT_ROOT}/${ZIP_NAME}"
echo "  Size: ${ZIP_SIZE}"
