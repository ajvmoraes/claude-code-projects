#!/bin/bash
# Builds SSHLauncher.app without Xcode/SwiftPM (this Mac only has Command Line
# Tools, whose SwiftPM manifest compiler is broken). Compiles every source file
# directly with swiftc, then hand-assembles a standard .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
APP_NAME="VEIVO SSH"       # .app bundle name shown in Finder/Dock/Spotlight
BINARY_NAME="SSHLauncher"  # internal executable name (must match Info.plist's CFBundleExecutable)
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

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

echo "==> Gerando Info.plist e ícone"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Assinando (ad-hoc, uso local)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Pronto: $APP_BUNDLE"
echo "    Para abrir agora:  open \"$APP_BUNDLE\""
