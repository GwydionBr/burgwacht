#!/bin/sh
# Rauchtest: startet das Spiel ohne Fenster in mehreren Zuständen, lässt einige Frames laufen
# und schlägt fehl, sobald Godot einen Fehler meldet (Skriptfehler in main.gd, view/, ui/).
# Läuft am Ende von tools/test.sh mit; ein Bild ersetzt er nicht (tools/screenshot.sh).
cd "$(dirname "$0")/.." || exit 1
FAILED=0
# Ein Start mit diesen Startparametern (siehe src/main.gd); jede Fehlerzeile lässt ihn scheitern,
# auch „--barracks: …“ und Co., wenn ein Startparameter nichts bewirkt.
smoke() {
	OUTPUT=$(godot --headless --path . --quit-after 30 -- --seed=1 "$@" 2>&1)
	if [ $? -ne 0 ] || echo "$OUTPUT" | grep -q "ERROR\|^--[a-z]*:"; then
		FAILED=1
		echo "FEHLER  Rauchtest: $*"
		echo "$OUTPUT" | grep -v "^Godot Engine" | sed 's/^/        /'
	fi
}
smoke
smoke --found --build=woodcutter --admin
smoke --days=3 --place=woodcutter@46,41 --ticks=25 --market
smoke --days=1 --demolish
# Kasernenansicht und Soldatenauswahl brauchen eine Kaserne mit Soldaten: frischer Spielstand.
SAVE=$(mktemp /tmp/burgwacht-rauchtest-XXXXXX)
trap 'rm -f "$SAVE"' EXIT
OUTPUT=$(godot --headless --path . --script res://tests/smoke_save.gd -- "$SAVE" 2>&1)
if [ $? -ne 0 ] || echo "$OUTPUT" | grep -q "ERROR"; then
	FAILED=1
	echo "FEHLER  Rauchtest: Spielstand mit Kaserne (tests/smoke_save.gd)"
	echo "$OUTPUT" | grep -v "^Godot Engine" | sed 's/^/        /'
else
	smoke --load="$SAVE" --barracks --select --box=10,7
fi
[ $FAILED -eq 0 ] && echo "Rauchtest bestanden"
exit $FAILED
