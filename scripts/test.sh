#!/usr/bin/env bash
# Regenerates the Xcode project and runs the unit tests. Extra args go to xcodebuild.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild test -project Notchy.xcodeproj -scheme Notchy -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData -quiet "$@"
