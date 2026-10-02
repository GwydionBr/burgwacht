#!/bin/sh
# Startet das Spiel. Zusätzliche Parameter nach "--", z. B.: tools/run.sh -- --scenario=free_play --seed=42
cd "$(dirname "$0")/.." && exec godot --path . "$@"
