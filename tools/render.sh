#!/bin/sh
# Rendert Sprites mit Blender aus ihren Rezepten (tools/render/recipes/) nach assets/sprites/.
# Aufruf: tools/render.sh [rezept …]   Rezept relativ zu recipes/ ohne .json, z. B. buildings/house;
# ohne Angabe alle. Braucht Blender in genau der Version aus REQUIRED_VERSION in render.py (ADR 0006);
# gesucht wird $BLENDER, dann blender im PATH, dann /Applications/Blender.app.
cd "$(dirname "$0")/.." || exit 1
if [ -z "$BLENDER" ]; then
	BLENDER=$(command -v blender || echo /Applications/Blender.app/Contents/MacOS/Blender)
fi
if [ ! -x "$BLENDER" ]; then
	echo "Fehler: Blender nicht gefunden ($BLENDER); Pfad mit BLENDER=… angeben" >&2
	exit 1
fi
exec "$BLENDER" --background --factory-startup --python-exit-code 1 --python tools/render/render.py -- "$@"
