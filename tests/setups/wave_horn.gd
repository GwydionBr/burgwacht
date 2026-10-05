extends RefCounted
## Aufbau für Startparameter --setup=wave_horn (Presets in tools/presets.json): wie
## wave_announced, aber die Welle kommt an Tag 3; zwei Sekunden nach dem Start (bei 1×) beginnt
## ihre Ankündigung, das Horn ist zu hören (nicht schon im Aufbau).

const WaveAnnounced := preload("res://tests/setups/wave_announced.gd")
## Takte zwischen Start und Ankündigung (10 je Sekunde bei 1×).
const LEAD := 20


static func create() -> GameWorld:
	return TestCase.new().shortly_before(WaveAnnounced.founded.bind(3),
			func(world: GameWorld) -> bool: return world.get_announced_side() != "",
			LEAD, 2 * GameWorld.TICKS_PER_DAY)
