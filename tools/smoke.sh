#!/bin/sh
# Rauchtest: startet das Spiel ohne Fenster in jedem Testzustand aus tools/presets.json, lässt
# einige Frames laufen und schlägt fehl, sobald Godot einen Fehler meldet (Skriptfehler in
# main.gd, view/, ui/). Läuft am Ende von tools/test.sh mit; ein Bild ersetzt er nicht.
cd "$(dirname "$0")/.." || exit 1
FAILED=0
# Ein Start mit diesen Startparametern (siehe src/main.gd); jede Fehlerzeile lässt ihn scheitern,
# auch „--barracks: …“ und Co., wenn ein Startparameter nichts bewirkt.
smoke() {
	OUTPUT=$(godot --headless --path . --quit-after 30 -- "$@" 2>&1)
	check $? "$*"
}
# Wertet Exitcode ($1) und $OUTPUT eines Godot-Laufs aus; $2 benennt ihn in der Meldung.
check() {
	if [ "$1" -ne 0 ] || echo "$OUTPUT" | grep -q "ERROR\|^--[a-z]*:"; then
		FAILED=1
		echo "FEHLER  Rauchtest: $2"
		echo "$OUTPUT" | grep -v "^Godot Engine" | sed 's/^/        /'
		return 1
	fi
}
OUTPUT=$(godot --headless --path . --script res://tests/preset_ids.gd 2>&1)
check $? "Presets lesen (tools/presets.json)" || exit 1
PRESETS=$(echo "$OUTPUT" | grep -v "^Godot Engine" | grep .)
for PRESET in $PRESETS; do
	smoke --preset="$PRESET"
done
# Was kein Preset zeigt: Auswahlrahmen über den Soldaten.
smoke --preset=barracks --box=10,7
[ $FAILED -eq 0 ] && echo "Rauchtest bestanden ($(echo "$PRESETS" | wc -l | tr -d ' ') Presets)"
exit $FAILED
