extends RefCounted
## Aufbau für Startparameter --setup=poacher (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet, mit einer Mauer vor der Burg (y = 10, x 0..10, Treppe nur
## innen); zwei Bogenschützen stehen oben. Drei Wilderer kommen von unten und beschießen sie auf
## dem Wehrgang; Pfeile fliegen in beide Richtungen.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(14, 6)
const BARRACKS_SITE := Vector2i(14, 2)
const STAIRS := Vector2i(1, 9)
const WALL_Y := 10
const ARCHER_SPOTS: Array[Vector2i] = [Vector2i(5, WALL_Y), Vector2i(8, WALL_Y)]
const POACHERS: Array[Vector2i] = [Vector2i(4, 15), Vector2i(9, 15), Vector2i(13, 15)]
## So viele Takte nach dem Erscheinen der Wilderer: Sie schießen schon auf die Bogenschützen.
const TICKS := 12


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	_ok(world.execute(Command.found(KEEP_ORIGIN)), "Gründung")
	helper.put_goods(world, WAREHOUSE, "stone", 100)
	var armory := helper.build(world, "armory", ARMORY_SITE)
	helper.put_goods(world, armory, "bow", 2)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	for spot in ARCHER_SPOTS:
		_ok(world.execute(Command.recruit(barracks, "archer")), "Anwerben")
	_ok(world.execute(Command.build_line("wall", Vector2i(0, WALL_Y), Vector2i(10, WALL_Y))), "Mauerlinie")
	helper.build(world, "stairs", STAIRS)
	for i in ARCHER_SPOTS.size():
		var spot := ARCHER_SPOTS[i]
		_ok(world.execute(Command.move([i + 1] as Array[int], Vector3i(spot.x, spot.y, Figure.Level.WALL_WALK))),
				"Bewegen")
	for i in 400:
		world.step()
	for tile in POACHERS:
		helper.add_enemy(world, "poacher", tile)
	for i in TICKS:
		world.step()
	var shooting := 0
	for enemy in world.get_enemies():
		if world.get_resident(enemy.target_id) != null:
			shooting += 1
	assert(shooting > 0, "Wilderer schießen auf die Bogenschützen")
	return world


static func _ok(reason: String, what: String) -> void:
	assert(reason == "", "%s: %s" % [what, reason])
