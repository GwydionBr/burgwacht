extends RefCounted
## Aufbau für Startparameter --setup=defense (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet, mit einer Mauer vor der Burg (Treppe innen und außen); zwei
## Bogenschützen stehen oben, ein Schwertkämpfer davor am Boden. Zwei Räuber greifen an; ohne
## Befehl verteidigen sich die Soldaten selbst.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(14, 6)
const BARRACKS_SITE := Vector2i(14, 2)
const INNER_STAIRS := Vector2i(1, 9)
const OUTER_STAIRS := Vector2i(10, 11)
const BANDITS: Array[Vector2i] = [Vector2i(13, 15), Vector2i(16, 14)]
## So viele Takte nach dem Erscheinen der Räuber: Der Kampf läuft.
const TICKS := 60


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	_ok(world.execute(Command.found(KEEP_ORIGIN)), "Gründung")
	helper.put_goods(world, WAREHOUSE, "stone", 100)
	var armory := helper.build(world, "armory", ARMORY_SITE)
	helper.put_goods(world, armory, "bow", 2)
	helper.put_goods(world, armory, "sword", 1)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	_ok(world.execute(Command.recruit(barracks, "archer")), "Anwerben")
	_ok(world.execute(Command.recruit(barracks, "archer")), "Anwerben")
	_ok(world.execute(Command.recruit(barracks, "swordsman")), "Anwerben")
	_ok(world.execute(Command.build_line("wall", Vector2i(0, 10), Vector2i(10, 10))), "Mauerlinie")
	helper.build(world, "stairs", INNER_STAIRS)
	helper.build(world, "stairs", OUTER_STAIRS)
	_ok(world.execute(Command.move([1] as Array[int], Vector3i(5, 10, Resident.Level.WALL_WALK))), "Bewegen")
	_ok(world.execute(Command.move([2] as Array[int], Vector3i(8, 10, Resident.Level.WALL_WALK))), "Bewegen")
	_ok(world.execute(Command.move([3] as Array[int], Resident.ground(Vector2i(7, 12)))), "Bewegen")
	for i in 400:
		world.step()
	for tile in BANDITS:
		helper.add_enemy(world, "bandit", tile)
	for i in TICKS:
		world.step()
	return world


static func _ok(reason: String, what: String) -> void:
	assert(reason == "", "%s: %s" % [what, reason])
