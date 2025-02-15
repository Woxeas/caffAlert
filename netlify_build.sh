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

echo "=== Creating .env file from Netlify environment variables ==="
mkdir -p assets
echo "SUPABASE_URL=$SUPABASE_URL" > assets/.env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> assets/.env

echo "=== Building Flutter web (release) ==="
flutter build web --release
