#!/bin/sh
# Speichert ein Bild des Spiels. Aufruf: tools/screenshot.sh [ausgabe.png] [seed] [szenario] [tage] [weitere Parameter]
# Mit Testzustand aus tools/presets.json statt Seed: tools/screenshot.sh bild.png barracks [weitere Parameter]
# Mit Tagen > 0 wird die Burg vorher gegründet; sonst zeigt das Bild die Gründung (oder --found angeben).
# Baumodus im Bild: --build=woodcutter --hover=46,44 (Kachel unter der Maus); Abriss: --demolish --hover=40,40.
# Laufende Arbeiter: --place=woodcutter@46,41 --ticks=25 (bauen, dann Takte laufen lassen).
# Ohne Ton: Screenshots laufen mit dem Dummy-Audiotreiber.
cd "$(dirname "$0")/.." || exit 1
# Klassen-Cache auffrischen, sonst fehlen nach einem Pull neue class_name-Typen
godot --headless --path . --import > /dev/null 2>&1
OUT="${1:-/tmp/burgwacht.png}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
case "$2" in
	"" | *[!0-9]*) ;;
	*)
		SEED="$2"; SCENARIO="${3:-free_play}"; DAYS="${4:-0}"
		[ $# -gt 4 ] && shift 4 || set --
		exec godot --path . --audio-driver Dummy -- --screenshot="$OUT" --seed="$SEED" --scenario="$SCENARIO" --days="$DAYS" "$@" ;;
esac
if [ -n "$2" ]; then
	PRESET="$2"; shift 2
	exec godot --path . --audio-driver Dummy -- --screenshot="$OUT" --preset="$PRESET" "$@"
fi
exec godot --path . --audio-driver Dummy -- --screenshot="$OUT" --seed=1 --scenario=free_play --days=0
