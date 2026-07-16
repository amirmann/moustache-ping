#!/usr/bin/env bash
# Capture light + dark README screenshots (fictional demo data only).
# Requires fonts under assets/fonts/ (Roboto + MaterialIcons) so text renders.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p docs/screenshots/light docs/screenshots/dark

if [[ ! -f assets/fonts/Roboto-Regular.ttf || ! -f assets/fonts/MaterialIcons-Regular.otf ]]; then
  echo "Missing assets/fonts — copy Roboto + MaterialIcons into test/fonts/ first." >&2
  exit 1
fi

flutter test test/screenshot_capture_test.dart --update-goldens

if [[ -d test/docs/screenshots ]]; then
  cp -r test/docs/screenshots/. docs/screenshots/
fi

echo "Screenshots written to docs/screenshots/{light,dark}/"
find docs/screenshots -name '*.png' | sort
