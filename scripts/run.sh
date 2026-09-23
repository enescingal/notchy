#!/usr/bin/env bash
# Builds a Debug app and (re)launches it.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build -project Notchy.xcodeproj -scheme Notchy -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData -quiet
pkill -x Notchy || true
open build/DerivedData/Build/Products/Debug/Notchy.app
