#!/bin/sh
# Wirtschaftsrechner: schätzt aus den Spieldaten Leistung, Ketten und Nahrung (Balancing, #160).
# Aufruf: tools/economy.sh [--storage=Kacheln] [--deposit=Kacheln]
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
exec godot --headless --path . --script res://tools/economy.gd -- "$@"
