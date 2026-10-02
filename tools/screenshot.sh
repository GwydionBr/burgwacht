#!/bin/sh
# Speichert ein Bild des Spiels. Aufruf: tools/screenshot.sh [ausgabe.png] [seed] [szenario] [tage] [weitere Parameter]
# Mit Tagen > 0 wird die Burg vorher gegründet; sonst zeigt das Bild die Gründung (oder --found angeben).
# Baumodus im Bild: --build=woodcutter --hover=46,44 (Kachel unter der Maus); Abriss: --demolish --hover=40,40.
# Laufende Arbeiter: --place=woodcutter@46,41 --ticks=25 (bauen, dann Takte laufen lassen).
cd "$(dirname "$0")/.." || exit 1
OUT="${1:-/tmp/burgwacht.png}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
SEED="${2:-1}"; SCENARIO="${3:-free_play}"; DAYS="${4:-0}"
[ $# -gt 4 ] && shift 4 || set --
exec godot --path . -- --screenshot="$OUT" --seed="$SEED" --scenario="$SCENARIO" --days="$DAYS" "$@"
