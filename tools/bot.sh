#!/bin/sh
# Szenario-Bot: spielt ein Szenario headless nach seiner Bauordnung in tools/bots/ (Balancing, #161).
# Aufruf: tools/bot.sh <szenario> [--seeds=Anzahl] [--days=Tage] [--quiet]
cd "$(dirname "$0")/.." || exit 1
godot --headless --path . --import > /dev/null 2>&1
exec godot --headless --path . --script res://tools/bot.gd -- "$@"
