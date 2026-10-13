#!/bin/bash
set -euo pipefail
JUMP_REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JUMP_DIST="$JUMP_REPO_ROOT/dist"
JUMP_BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$JUMP_BUILD_TMP"' EXIT
JUMP_SDK="$(xcrun --show-sdk-path)"
mkdir -p "$JUMP_DIST/JumpInputGuard.app/Contents/MacOS"
for JUMP_ARCH in arm64 x86_64; do
  swiftc -O -target "$JUMP_ARCH-apple-macos13.0" -sdk "$JUMP_SDK" \
    "$JUMP_REPO_ROOT/macos/InputPin.swift" \
    "$JUMP_REPO_ROOT/macos/SessionDetector.swift" \
    "$JUMP_REPO_ROOT/macos/RemoteInputController.swift" \
    "$JUMP_REPO_ROOT/macos/JumpInputGuard.swift" \
    -framework AppKit -framework Carbon -framework ServiceManagement \
    -o "$JUMP_BUILD_TMP/JumpInputGuard-$JUMP_ARCH"
done
lipo -create "$JUMP_BUILD_TMP/JumpInputGuard-arm64" "$JUMP_BUILD_TMP/JumpInputGuard-x86_64" \
  -output "$JUMP_DIST/JumpInputGuard.app/Contents/MacOS/JumpInputGuard"
cat > "$JUMP_DIST/JumpInputGuard.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>JumpInputGuard</string>
<key>CFBundleIdentifier</key><string>local.JumpInputGuard</string>
<key>CFBundleName</key><string>JumpInputGuard</string>
<key>CFBundleDisplayName</key><string>Jump 입력 보조</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>203</string>
<key>CFBundleShortVersionString</key><string>2.0.3</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$JUMP_DIST/JumpInputGuard.app"
codesign --verify --deep --strict "$JUMP_DIST/JumpInputGuard.app"
ditto -c -k --sequesterRsrc --keepParent "$JUMP_DIST/JumpInputGuard.app" \
  "$JUMP_DIST/JumpInputGuard-2.0.3-macos-universal.zip"
echo "Built: $JUMP_DIST/JumpInputGuard.app"
