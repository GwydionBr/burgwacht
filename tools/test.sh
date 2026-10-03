#!/bin/sh
# Führt alle Tests ohne Fenster aus, danach den Rauchtest (tools/smoke.sh).
# Nur einzelne Dateien (ohne Rauchtest): tools/test.sh test_founding
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
godot --headless --path . --script res://tests/run_tests.gd -- "$@" || exit 1
[ $# -gt 0 ] || exec tools/smoke.sh
