extends RefCounted
## Aufbau für Startparameter --setup=walls (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet, mit einer Mauerlinie samt Tor, Turm, schräger Mauer und
## Treppe; drei Schwertkämpfer stehen auf dem Turm, auf der Mauer und im Tor.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(14, 6)
const BARRACKS_SITE := Vector2i(14, 2)
const TOWER_SITE := Vector2i(8, 10)
const GATE := Vector2i(4, 11)
const STAIRS := Vector2i(12, 12)
const SOLDIERS := 3
## So viele Takte nach dem Bewegen: Die Soldaten sind angekommen.
const TICKS := 300


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	_ok(world.execute(Command.found(KEEP_ORIGIN)), "Gründung")
	helper.put_goods(world, WAREHOUSE, "stone", 100)
	var armory := helper.build(world, "armory", ARMORY_SITE)
	helper.put_goods(world, armory, "sword", SOLDIERS)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	for i in SOLDIERS:
		_ok(world.execute(Command.recruit(barracks, "swordsman")), "Anwerben")
	_ok(world.execute(Command.build_line("wall", Vector2i(0, 11), Vector2i(3, 11))), "Mauerlinie")
	_ok(world.execute(Command.build_line("wall", Vector2i(5, 11), Vector2i(7, 11))), "Mauerlinie")
	_ok(world.execute(Command.build_line("wall", Vector2i(10, 11), Vector2i(13, 11))), "Mauerlinie")
	_ok(world.execute(Command.build_line("wall", Vector2i(14, 12), Vector2i(16, 14))), "Mauerlinie")
	helper.build(world, "gate", GATE)
	helper.build(world, "tower", TOWER_SITE)
	helper.build(world, "stairs", STAIRS)
	_ok(world.execute(Command.move([1] as Array[int], Vector3i(9, 10, Figure.Level.WALL_WALK))), "Bewegen")
	_ok(world.execute(Command.move([2] as Array[int], Vector3i(15, 13, Figure.Level.WALL_WALK))), "Bewegen")
	_ok(world.execute(Command.move([3] as Array[int], Figure.ground(GATE))), "Bewegen")
	for i in TICKS:
		world.step()
	return world


static func _ok(reason: String, what: String) -> void:
	assert(reason == "", "%s: %s" % [what, reason])
