#!/usr/bin/env bash
set -euo pipefail

app_name="DummyDisplay.app"
binary_name="dummy_display_menu"
module_cache="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/mac-dummy-display-clang-module-cache}"

rm -rf "$app_name"
mkdir -p "$app_name/Contents/MacOS"
mkdir -p "$module_cache"
cp Info.plist "$app_name/Contents/"

swiftc menu_app.swift \
  -Xcc -fmodules-cache-path="$module_cache" \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics \
  -framework Foundation \
  -framework CoreVideo \
  -framework AppKit \
  -o "$app_name/Contents/MacOS/$binary_name"

codesign --force --deep --sign - "$app_name"
