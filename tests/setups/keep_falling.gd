extends RefCounted
## Aufbau für Startparameter --setup=keep_falling (Presets in tools/presets.json): wie defeat,
## aber zwei Sekunden (bei 1×) bevor der Bergfried fällt; die Niederlage und ihr Trauerstück
## kommen kurz nach dem Start (nicht schon im Aufbau).

const KeepAttack := preload("res://tests/setups/keep_attack.gd")
const Defeat := preload("res://tests/setups/defeat.gd")
## Takte zwischen Start und Niederlage (10 je Sekunde bei 1×).
const LEAD := 20


static func create() -> GameWorld:
	return TestCase.new().shortly_before(KeepAttack.besiege,
			func(world: GameWorld) -> bool: return world.is_defeated(), LEAD, Defeat.MAX_TICKS)
