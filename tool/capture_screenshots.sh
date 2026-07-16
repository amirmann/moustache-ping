#!/usr/bin/env bash
# Capture light + dark README screenshots (fictional demo data only).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p docs/screenshots/light docs/screenshots/dark

flutter test test/screenshot_capture_test.dart --update-goldens

# Flutter may write goldens under test/; relocate if needed.
if [[ -d test/docs/screenshots ]]; then
  cp -r test/docs/screenshots/. docs/screenshots/
fi

echo "Screenshots written to docs/screenshots/{light,dark}/"
find docs/screenshots -name '*.png' | sort
