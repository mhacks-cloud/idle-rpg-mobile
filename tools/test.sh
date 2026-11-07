#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT:-godot}"
TEST_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/vigilia-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_TEMP"' EXIT
export XDG_DATA_HOME="$TEST_TEMP/data"
export XDG_CACHE_HOME="$TEST_TEMP/cache"
export XDG_CONFIG_HOME="$TEST_TEMP/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT/godot" --editor --import --quit >"$TEST_TEMP/import.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$TEST_TEMP/import.log"; then
    cat "$TEST_TEMP/import.log"
    exit 1
fi
"$GODOT_BIN" --headless --path "$PROJECT_ROOT/godot" --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path "$PROJECT_ROOT/godot" --script res://tests/test_session.gd
