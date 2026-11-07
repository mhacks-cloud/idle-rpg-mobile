#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"
: "${ANDROID_HOME:?Defina ANDROID_HOME apontando para o Android SDK com API 36.}"
mkdir -p "$PROJECT_ROOT/android/app/src/main/assets"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT/godot" --editor --import --quit
"$GODOT_BIN" --headless --path "$PROJECT_ROOT/godot" --export-pack 'Android Pack' "$PROJECT_ROOT/android/app/src/main/assets/game.pck"
test -s "$PROJECT_ROOT/android/app/src/main/assets/game.pck"
cd "$PROJECT_ROOT/android"
./gradlew testDebugUnitTest lintDebug assembleDebug
printf '\nAPK: %s\n' "$PROJECT_ROOT/android/app/build/outputs/apk/debug/app-debug.apk"
