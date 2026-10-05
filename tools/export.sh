#!/bin/sh
# Exportiert das Spiel als macOS-App nach export/Burgwacht.app (Vorlage „macOS“ in
# export_presets.cfg) und startet sie danach einmal ohne Fenster mit einem Testzustand.
# Lädt nichts herunter: fehlen die Export-Templates, bricht es mit einer Anleitung ab.
cd "$(dirname "$0")/.." || exit 1
APP="export/Burgwacht.app"
PRESET="workers"

# 1. Export-Templates für genau die installierte Godot-Version
# („4.7.2.stable.official.ed1daf0bf“ → Ordner „4.7.2.stable“, „4.7.stable.official.…“ → „4.7.stable“)
VERSION=$(godot --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+[0-9]*)\..*$/\1/')
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION"
if [ ! -f "$TEMPLATES/macos.zip" ]; then
	TAG=$(echo "$VERSION" | sed 's/\.\([a-z][a-z0-9]*\)$/-\1/')
	cat <<EOF
FEHLER  Export-Templates für Godot $VERSION fehlen (erwartet: $TEMPLATES/macos.zip).
Installieren, dann erneut starten – auf einem der beiden Wege:
  a) Im Godot-Editor: Editor → Export-Templates verwalten… → Herunterladen und installieren
  b) Von Hand: https://github.com/godotengine/godot/releases/download/$TAG/Godot_v${TAG}_export_templates.tpz
     herunterladen, die .tpz-Datei (ein Zip) entpacken und den Inhalt des Ordners „templates“
     nach „$TEMPLATES/“ kopieren.
EOF
	exit 1
fi

# 2. Release-Export
godot --headless --path . --import > /dev/null 2>&1
rm -rf "$APP"
mkdir -p export
OUTPUT=$(godot --headless --path . --export-release "macOS" "$APP" 2>&1)
if [ $? -ne 0 ] || [ ! -d "$APP" ] || echo "$OUTPUT" | grep -q "ERROR"; then
	echo "FEHLER  Export nach $APP"
	echo "$OUTPUT" | sed 's/^/        /'
	exit 1
fi
echo "Exportiert: $APP"

# 3. Startprobe der exportierten App (wie der Rauchtest in tools/smoke.sh)
OUTPUT=$("$APP/Contents/MacOS/Burgwacht" --headless --quit-after 30 -- --preset="$PRESET" 2>&1)
if [ $? -ne 0 ] || echo "$OUTPUT" | grep -q "ERROR\|^--[a-z]*:"; then
	echo "FEHLER  Startprobe der App mit Testzustand $PRESET"
	echo "$OUTPUT" | grep -v "^Godot Engine" | sed 's/^/        /'
	exit 1
fi
echo "Startprobe bestanden (Testzustand $PRESET)"
