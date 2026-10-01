#!/bin/sh
# Speichert ein Bild des Spiels. Aufruf: tools/screenshot.sh [ausgabe.png] [seed]
cd "$(dirname "$0")/.." || exit 1
OUT="${1:-/tmp/burgwacht.png}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
exec godot --path . -- --screenshot="$OUT" --seed="${2:-1}"
