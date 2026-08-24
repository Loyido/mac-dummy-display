#!/usr/bin/env bash
set -euo pipefail

app_name="DummyDisplay.app"
binary_name="dummy_display_menu"

rm -rf "$app_name"
mkdir -p "$app_name/Contents/MacOS"
cp Info.plist "$app_name/Contents/"

swiftc menu_app.swift \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics \
  -framework Foundation \
  -framework CoreVideo \
  -framework AppKit \
  -o "$app_name/Contents/MacOS/$binary_name"

codesign --force --deep --sign - "$app_name"
