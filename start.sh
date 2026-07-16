#!/bin/bash
set -e

FLUTTER_ROOT="/home/runner/flutter"
DART="$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart"
SNAPSHOT="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
SCOLARIS_DIR="/home/runner/workspace/scolaris"

export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:/home/runner/bin:$PATH"
export FLUTTER_ROOT

# ── Sanity check ─────────────────────────────────────────────────────────────
if [ ! -f "$DART" ]; then
  echo "[error] Dart SDK not found at $DART"
  exit 1
fi
if [ ! -f "$SNAPSHOT" ]; then
  echo "[error] flutter_tools.snapshot not found at $SNAPSHOT"
  exit 1
fi

# Remove stale lockfile if any
rm -f "$FLUTTER_ROOT/bin/cache/lockfile"

# Skip material fonts download (use existing stamp)
FONTS_HASH="3012db47f3130e62f7cc0beabff968a33cbec8d8"
echo "$FONTS_HASH" > "$FLUTTER_ROOT/bin/cache/material_fonts.stamp"

# ── Build Flutter web (via Dart snapshot — évite le script shell cassé) ───────
echo "[build] Building Flutter web..."
cd "$SCOLARIS_DIR"

"$DART" "$SNAPSHOT" build web --release --base-href "/" 2>&1
echo "[build] Done → $SCOLARIS_DIR/build/web"

# ── Serve ─────────────────────────────────────────────────────────────────────
echo "[serve] Starting on port 5000..."
node "$SCOLARIS_DIR/serve.js"
