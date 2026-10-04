#!/bin/sh
# Startet das Spiel. Mit Testzustand aus tools/presets.json: tools/run.sh barracks [--weitere]
# Nur Startparameter: tools/run.sh -- --scenario=free_play --seed=42
cd "$(dirname "$0")/.." || exit 1
# Klassen-Cache auffrischen, sonst fehlen nach einem Pull neue class_name-Typen
godot --headless --path . --import > /dev/null 2>&1
case "$1" in
	"" | -*) exec godot --path . "$@" ;;
	*) PRESET="$1"; shift; [ "$1" = "--" ] && shift; exec godot --path . -- --preset="$PRESET" "$@" ;;
esac
