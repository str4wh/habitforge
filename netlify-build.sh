#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

# ── Install Flutter (stable) if not already cached ───────────────────────────
if [ ! -d "$FLUTTER_DIR" ]; then
  echo ">>> Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
else
  echo ">>> Flutter already cached at $FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# ── SDK hygiene ───────────────────────────────────────────────────────────────
flutter config --no-analytics
flutter precache --web

echo ">>> Flutter version:"
flutter --version

# ── Build ─────────────────────────────────────────────────────────────────────
flutter pub get
flutter build web --release

echo ">>> build/web contents:"
ls build/web
