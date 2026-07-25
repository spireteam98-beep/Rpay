#!/usr/bin/env bash
# Builds the full wayaki.com site: the marketing landing page at "/" and the
# Flutter app at "/app". Run from the repo root (or anywhere — it cd's itself).
#
# Output: build/web/  (index.html + landing assets at the root, the compiled
# Flutter app under build/web/app/). This is what vercel.json's
# outputDirectory points at.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Cleaning previous build output…"
rm -rf build/web build/web-app-tmp

echo "==> Building Flutter web app (base href /app/)…"
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" flutter build web --release --base-href=/app/

echo "==> Moving compiled app into build/web/app …"
mv build/web build/web-app-tmp
mkdir -p build/web
mv build/web-app-tmp build/web/app

echo "==> Copying landing page into build/web root …"
cp landing/index.html build/web/index.html
cp landing/wayaki.css build/web/wayaki.css
cp landing/wayaki.js build/web/wayaki.js
cp landing/favicon.png build/web/favicon.png
mkdir -p build/web/assets
cp landing/assets/wayaki-logo.png build/web/assets/wayaki-logo.png
cp landing/assets/mpesa.png build/web/assets/mpesa.png

echo "==> Done. build/web/index.html is the landing page; build/web/app/ is the Flutter app."
