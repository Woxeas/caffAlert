#!/usr/bin/env bash
set -e  # pokud se objeví chyba, skript skončí

echo "=== Cloning Flutter SDK ==="
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Switching to stable channel ==="
flutter channel stable
flutter upgrade
flutter config --enable-web

echo "=== Building Flutter web (release) ==="
flutter build web --release
