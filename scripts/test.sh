#!/usr/bin/env bash
# Regenerates the Xcode project and runs the unit tests. Extra args go to xcodebuild.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
# Same optional signing identity as run.sh; the tests rebuild the app that run.sh launches.
signing=()
if [[ -f .signing-identity ]]; then signing=(CODE_SIGN_IDENTITY="$(cat .signing-identity)"); fi
xcodebuild test -project Notchy.xcodeproj -scheme Notchy -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData -quiet ${signing[@]+"${signing[@]}"} "$@"
