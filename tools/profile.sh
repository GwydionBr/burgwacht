#!/bin/sh
# Misst Taktzeit, Speicher und Nodes über mehrere Spieltage (Leak vs. wachsende Simulation).
# Aufruf: tools/profile.sh [Tage]
# --saves=empty, damit der Autospielstand nicht in den Nutzerordner geht.
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
DAYS="${1:-12}"
exec godot --headless --path . --audio-driver Dummy --script res://tools/profile.gd -- --saves=empty --seed=1 --found --profile-days="$DAYS"
