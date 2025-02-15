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

# 1) Vypíšeme environment variables, které Netlify poskytuje:
echo "=== Print Netlify environment variables ==="
echo "SUPABASE_URL is: $SUPABASE_URL"
echo "SUPABASE_ANON_KEY is: $SUPABASE_ANON_KEY"

# 2) Vytvoříme .env soubor v kořenovém adresáři (varianta A):
echo "=== Creating .env file from Netlify environment variables ==="
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env

# 3) Zkontrolujeme, co bylo do .env zapsáno:
echo "=== Content of .env file: ==="
cat .env

# 4) Spustíme Flutter build:
echo "=== Building Flutter web (release) ==="
flutter build web --release

# 5) Na závěr vypíšeme obsah build/web, abychom ověřili, co tam je:
echo "=== Listing build/web folder: ==="
ls -R build/web

