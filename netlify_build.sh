#!/usr/bin/env bash
set -e  # pokud se objeví chyba, skript skončí

if [ -d "flutter" ]; then
  echo "Flutter SDK already exists, updating..."
  cd flutter && git pull && cd ..
else
  echo "=== Cloning Flutter SDK ==="
  git clone https://github.com/flutter/flutter.git
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Switching to stable channel ==="
flutter channel stable
flutter upgrade
flutter config --enable-web

# Spustíme Flutter build s předáním proměnných pomocí --dart-define:
echo "=== Building Flutter web (release) with dart-define ==="
flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

