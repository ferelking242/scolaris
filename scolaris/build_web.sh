#!/bin/bash
set -e
export FLUTTER_ROOT="/home/runner/flutter"
export DART="/home/runner/flutter/bin/cache/dart-sdk/bin/dart"
export SNAPSHOT="/home/runner/flutter/bin/cache/flutter_tools.snapshot"
export PATH="/home/runner/flutter/bin:/home/runner/flutter/bin/cache/dart-sdk/bin:/home/runner/bin:$PATH"

cd /home/runner/workspace

# Remove lock if exists
rm -f "$FLUTTER_ROOT/bin/cache/lockfile"

# Create material_fonts stamp with correct hash to skip download
FONTS_HASH="3012db47f3130e62f7cc0beabff968a33cbec8d8"
echo "$FONTS_HASH" > "$FLUTTER_ROOT/bin/cache/material_fonts.stamp"

# Run build
"$DART" "$SNAPSHOT" build web --release --base-href "/" 2>&1
