extends RefCounted
## Aufbau für Startparameter --setup=wave_repelled (Presets in tools/presets.json): wie defense,
## aber die Räuber gehören zu Welle 1; zwei Sekunden (bei 1×) nach dem Start fällt der letzte, die
## Welle ist abgewehrt (Fanfare).

const Defense := preload("res://tests/setups/defense.gd")
## Takte zwischen Start und Abwehr (10 je Sekunde bei 1×).
const LEAD := 20
## Obergrenze bis zur Abwehr.
const MAX_TICKS := 2000


static func create() -> GameWorld:
	return TestCase.new().shortly_before(Defense.attack.bind(1),
			func(world: GameWorld) -> bool: return world.get_repelled_waves() > 0, LEAD, MAX_TICKS)
