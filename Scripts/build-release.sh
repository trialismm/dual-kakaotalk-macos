#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-release"
DIST="$ROOT/dist/Dual-KakaoTalk-for-macOS"
rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/x86_64" "$BUILD/arm64" "$DIST/bin" "$DIST/Compatibility"

swift build -c release --arch x86_64 --scratch-path "$BUILD/x86_64"
swift build -c release --arch arm64 --scratch-path "$BUILD/arm64"
lipo -create \
  "$BUILD/x86_64/x86_64-apple-macosx/release/dual-kakaotalk-tool" \
  "$BUILD/arm64/arm64-apple-macosx/release/dual-kakaotalk-tool" \
  -output "$DIST/bin/dual-kakaotalk-tool"
chmod +x "$DIST/bin/dual-kakaotalk-tool"
cp "$ROOT/Install.command" "$DIST/Install.command"
chmod +x "$DIST/Install.command"
cp "$ROOT/Compatibility/asset-sha256.txt" "$DIST/Compatibility/asset-sha256.txt"
cp "$ROOT/README.md" "$DIST/README.txt"
cp "$ROOT/LICENSE" "$DIST/LICENSE.txt"

codesign --force --sign - "$DIST/bin/dual-kakaotalk-tool"
codesign --verify --strict "$DIST/bin/dual-kakaotalk-tool"
mkdir -p "$ROOT/dist"
ditto -c -k --keepParent "$DIST" "$ROOT/dist/Dual-KakaoTalk-for-macOS-v0.1.0-beta.1.zip"
lipo -archs "$DIST/bin/dual-kakaotalk-tool"
shasum -a 256 "$ROOT/dist/Dual-KakaoTalk-for-macOS-v0.1.0-beta.1.zip"
