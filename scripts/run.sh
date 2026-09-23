#!/usr/bin/env bash
# Builds a Debug app and (re)launches it.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
# Optional and gitignored: a stable signing identity, so macOS keeps the Accessibility grant
# across rebuilds (an ad-hoc build loses it whenever the binary changes).
signing=()
if [[ -f .signing-identity ]]; then signing=(CODE_SIGN_IDENTITY="$(cat .signing-identity)"); fi
xcodebuild build -project Notchy.xcodeproj -scheme Notchy -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData -quiet ${signing[@]+"${signing[@]}"}
pkill -x Notchy || true
open build/DerivedData/Build/Products/Debug/Notchy.app
