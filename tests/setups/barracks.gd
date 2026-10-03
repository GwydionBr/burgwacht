extends RefCounted
## Aufbau für Startparameter --setup=barracks (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet, mit Waffenkammer, Kaserne und zwei Schwertkämpfern, die
## schon zum Posten laufen. Baut mit den Hilfen der Tests; ein fehlgeschlagenes assert() darin
## meldet Godot als Fehler, und daran scheitert der Rauchtest.

const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const SOLDIERS := 2
## So viele Takte nach dem Anwerben: Die Soldaten sind unterwegs.
const TICKS := 20


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	helper.found_castle(world)
	var armory := helper.build(world, "armory", ARMORY_SITE)
	helper.put_goods(world, armory, "sword", SOLDIERS)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	for i in SOLDIERS:
		var reason := world.execute(Command.recruit(barracks, "swordsman"))
		assert(reason == "", "Anwerben: " + reason)
	for i in TICKS:
		world.step()
	return world
