extends RefCounted
## Aufbau für Startparameter --setup=wave_announced (Presets in tools/presets.json): leere Karte
## 24×18 (nur Wiese) mit einer Welle aus Norden an Tag 2, gegründet; die Ankündigung läuft, noch
## 42 Sekunden bis zum Erscheinen (HUD-Countdown „Welle aus Norden in 0:42“, Randmarkierung).

const KEEP_ORIGIN := Vector2i(10, 8)
## So weit in Tag 1: 600 − 180 = 420 Takte bis Tag 2, bei 1× 42 Sekunden.
const TICKS := 180


static func create() -> GameWorld:
	var scenario := Scenario.from_dict("wave_announced", {
		"name": "Angekündigte Welle", "map": {"width": 24, "height": 18}, "seed": 7,
		"start_goods": {"wood": 100, "stone": 50}, "start_residents": 4,
		"waves": {"list": [{"day": 2, "enemies": {"bandit": 3}, "side": "north"}]},
	})
	assert(scenario.error == "", scenario.error)
	var world := TestCase.new().clear_map(GameWorld.create(scenario, 7))
	var reason := world.execute(Command.found(KEEP_ORIGIN))
	assert(reason == "", "Gründung: %s" % reason)
	for i in TICKS:
		world.step()
	assert(world.get_announced_side() == "north", "Ankündigung läuft")
	return world
