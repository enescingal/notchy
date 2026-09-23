#!/usr/bin/env bash
# Builds ungive/mediaremote-adapter (BSD-3) and copies what Notchy bundles into Vendor/.
set -euo pipefail
cd "$(dirname "$0")/.."
COMMIT="${1:-73f14ab1568371e6e3c44063f21c34c5e2712c4d}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --quiet https://github.com/ungive/mediaremote-adapter.git "$WORK/src"
git -C "$WORK/src" checkout --quiet "$COMMIT"
# Note: upstream's CMakeLists.txt hard-codes
#   set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64")
# as a plain (non-cache) set(), which always wins over a -D-seeded cache value, so passing
# -DCMAKE_OSX_ARCHITECTURES here has no effect on the build. We thin the resulting fat binary
# down to arm64 below instead (every notched Mac is Apple Silicon).
cmake -S "$WORK/src" -B "$WORK/build" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 >/dev/null
cmake --build "$WORK/build" >/dev/null

DEST=Vendor/MediaRemoteAdapter
rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$WORK/build/MediaRemoteAdapter.framework" "$DEST/"
cp "$WORK/src/bin/mediaremote-adapter.pl" "$DEST/"
cp "$WORK/src/LICENSE" "$DEST/LICENSE"
echo "$COMMIT" > "$DEST/COMMIT"

BINARY="$DEST/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter"
lipo -thin arm64 "$BINARY" -output "$BINARY.thin"
mv "$BINARY.thin" "$BINARY"
codesign --force --sign - "$DEST/MediaRemoteAdapter.framework"
echo "MediaRemoteAdapter @ $COMMIT -> $DEST"
