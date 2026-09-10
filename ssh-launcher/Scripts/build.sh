#!/bin/bash
# Builds SSHLauncher.app without Xcode/SwiftPM (this Mac only has Command Line
# Tools, whose SwiftPM manifest compiler is broken). Compiles every source file
# directly with swiftc, then hand-assembles a standard .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
APP_NAME="SSHLauncher"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BINARY_NAME="$APP_NAME"

echo "==> Limpando build anterior"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "==> Coletando arquivos fonte"
SOURCES=()
while IFS= read -r -d '' f; do
  SOURCES+=("$f")
done < <(find "$ROOT/Sources" "$ROOT/Vendor/SwiftTerm" -name '*.swift' -print0)

echo "    ${#SOURCES[@]} arquivos .swift"

echo "==> Compilando (swiftc)"
swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -module-name SwiftTerm \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  -framework Security \
  -framework CryptoKit \
  -o "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" \
  "${SOURCES[@]}"

echo "==> Gerando Info.plist"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Assinando (ad-hoc, uso local)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Pronto: $APP_BUNDLE"
echo "    Para abrir agora:  open \"$APP_BUNDLE\""
