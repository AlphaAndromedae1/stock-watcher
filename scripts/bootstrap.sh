#!/usr/bin/env bash
# Generates StockWatcher.xcodeproj from project.yml and opens it in Xcode.
# Run this once after cloning (and any time you change project.yml).
set -euo pipefail

cd "$(dirname "$0")/../StockWatcher"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen not found. Installing with Homebrew…"
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "Homebrew not found. Install it from https://brew.sh then run: brew install xcodegen"
    exit 1
  fi
fi

echo "Generating Xcode project…"
xcodegen generate

echo "Done. Opening StockWatcher.xcodeproj"
open StockWatcher.xcodeproj
