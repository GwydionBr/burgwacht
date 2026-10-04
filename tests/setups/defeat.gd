extends RefCounted
## Aufbau für Startparameter --setup=defeat (Presets in tools/presets.json): wie keep_attack,
## aber bis der Bergfried gefallen ist; die Niederlage-Ansicht ist offen.

const KeepAttack := preload("res://tests/setups/keep_attack.gd")
## Obergrenze bis zur Niederlage (fünf Räuber brauchen gut 160 Takte).
const MAX_TICKS := 600


static func create() -> GameWorld:
	var world := KeepAttack.besiege()
	for i in MAX_TICKS:
		if world.is_defeated():
			break
		world.step()
	assert(world.is_defeated(), "Niederlage nach %d Takten nicht eingetreten" % MAX_TICKS)
	return world
