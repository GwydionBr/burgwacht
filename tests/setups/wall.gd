extends RefCounted
## Testzustand: Mauer mit Treppe und zwei Soldaten auf dem Wehrgang. Das Preset wall ergänzt
## darüber eine Mauerlinien-Vorschau mit freien und bereits bebauten Kacheln.

const WALL_TOP := Vector2i(6, 11)
const WALL_BOTTOM := Vector2i(6, 14)
const STAIRS := Vector2i(5, 12)
const MAX_TICKS := 500


static func create() -> GameWorld:
	var barracks_setup: GDScript = load("res://tests/setups/barracks.gd")
	var world: GameWorld = barracks_setup.call("create")
	var helper := TestCase.new()
	helper.put_goods(world, 2, "stone", 100)
	var reason := world.execute(Command.build_line("wall", WALL_TOP, WALL_BOTTOM))
	assert(reason == "", "Mauerlinie: " + reason)
	helper.build(world, "stairs", STAIRS)
	var target := Vector3i(WALL_BOTTOM.x, WALL_BOTTOM.y, Figure.Level.WALL_WALK)
	reason = world.execute(Command.move([1, 2] as Array[int], target))
	assert(reason == "", "Bewegen auf den Wehrgang: " + reason)
	for i in MAX_TICKS:
		if world.get_resident(1).position() == world.get_resident(1).post \
				and world.get_resident(2).position() == world.get_resident(2).post:
			return world
		world.step()
	assert(false, "Soldaten erreichen den Wehrgang nicht")
	return world
