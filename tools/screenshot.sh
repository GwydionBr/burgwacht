#!/bin/sh
# Speichert ein Bild des Spiels. Aufruf: tools/screenshot.sh [ausgabe.png] [seed] [szenario] [tage] [weitere Parameter]
# Mit Tagen > 0 wird die Burg vorher gegründet; sonst zeigt das Bild die Gründung (oder --found angeben).
cd "$(dirname "$0")/.." || exit 1
OUT="${1:-/tmp/burgwacht.png}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
SEED="${2:-1}"; SCENARIO="${3:-free_play}"; DAYS="${4:-0}"
[ $# -gt 4 ] && shift 4 || set --
exec godot --path . -- --screenshot="$OUT" --seed="$SEED" --scenario="$SCENARIO" --days="$DAYS" "$@"
