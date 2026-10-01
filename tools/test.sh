#!/bin/sh
# Führt alle Tests ohne Fenster aus.
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
exec godot --headless --path . --script res://tests/run_tests.gd
