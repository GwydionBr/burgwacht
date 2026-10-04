extends RefCounted
## Aufbau für Startparameter --setup=barracks_ready (Presets in tools/presets.json): wie barracks,
## danach liegt ein Schwert in der Waffenkammer, aber kein Bogen. Schwertkämpfer anwerben geht,
## Bogenschütze anwerben ist gesperrt (Grund und Hinweis auf Bogner oder Markt).

const Barracks := preload("res://tests/setups/barracks.gd")


static func create() -> GameWorld:
	var world := Barracks.create()
	var helper := TestCase.new()
	for building in world.get_buildings():
		if building.type == "armory":
			helper.put_goods(world, building.id, "sword", 1)
	assert(world.get_stock("sword") == 1, "Schwert in der Waffenkammer")
	return world
