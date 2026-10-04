extends RefCounted
## Aufbau für Startparameter --setup=milestone7 (Preset milestone7 in tools/presets.json):
## Vorführung von allem aus Meilenstein 7. Die Burg liegt unten links hinter einer Mauer mit
## Tor, Turm, schrägem Stück und Treppen; Bogenschützen stehen auf dem Turm, auf der Mauer und
## am Boden, Schwertkämpfer auf der Mauer an der äußeren Treppe und hinter dem Tor. Vier
## Untätige, Waffen und Gold reichen zum Anwerben in der Kaserne. Fünf Räuber kommen von oben
## rechts, steigen über die äußere Treppe auf den Wehrgang und werden ohne Befehl abgewehrt.
## Ideen zum Ausprobieren: äußere Treppe abreißen (Räuber müssen die Mauer durchbrechen),
## Soldaten wählen und schicken, mit F8 weitere Räuber holen.

const KEEP_ORIGIN := Vector2i(3, 16)
const WAREHOUSE := 2
## Reicht für alle Mauern, Tor, Turm und Treppen, mit Rest zum Weiterbauen.
const STONE := 160
const BARRACKS_SITE := Vector2i(13, 16)
const ARMORY_SITE := Vector2i(17, 16)
const HOUSE_SITES: Array[Vector2i] = [Vector2i(13, 21), Vector2i(16, 21)]
## Mauer bei y = 12 mit Lücken für Tor und Turm, dann schräg und senkrecht bis zum Rand.
const WALL_LINES: Array[Array] = [
	[Vector2i(0, 12), Vector2i(4, 12)],
	[Vector2i(6, 12), Vector2i(9, 12)],
	[Vector2i(12, 12), Vector2i(19, 12)],
	[Vector2i(20, 13), Vector2i(25, 18)],
	[Vector2i(26, 19), Vector2i(26, 27)],
]
const GATE := Vector2i(5, 12)
## Der Turm füllt die Lücke (10..11, 11..12); sein Eingang liegt innen.
const TOWER_SITE := Vector2i(10, 11)
const INNER_STAIRS := Vector2i(15, 13)
const OUTER_STAIRS := Vector2i(18, 11)
const ARCHER := "archer"
const SWORDSMAN := "swordsman"
## Soldatentyp und Posten der Reihe nach (IDs 1, 2, …): zwei Schützen auf dem Turm (größte
## Reichweite), zwei auf der Mauer, einer am Boden; zwei Schwertkämpfer oben an der äußeren
## Treppe, einer hinter dem Tor.
const SOLDIERS: Array[Array] = [
	[ARCHER, Vector3i(10, 11, Figure.Level.WALL_WALK)],
	[ARCHER, Vector3i(11, 11, Figure.Level.WALL_WALK)],
	[ARCHER, Vector3i(3, 12, Figure.Level.WALL_WALK)],
	[ARCHER, Vector3i(14, 12, Figure.Level.WALL_WALK)],
	[ARCHER, Vector3i(8, 14, Figure.Level.GROUND)],
	[SWORDSMAN, Vector3i(17, 12, Figure.Level.WALL_WALK)],
	[SWORDSMAN, Vector3i(19, 12, Figure.Level.WALL_WALK)],
	[SWORDSMAN, Vector3i(5, 13, Figure.Level.GROUND)],
]
## Waffen in der Waffenkammer, die nach dem Anwerben oben übrig bleiben.
const SPARE_BOWS := 2
const SPARE_SWORDS := 2
const BANDITS: Array[Vector2i] = [
	Vector2i(27, 1), Vector2i(28, 0), Vector2i(29, 2), Vector2i(30, 1), Vector2i(31, 3),
]
const MAX_TICKS := 1000


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("milestone7")
	_ok(world.execute(Command.found(KEEP_ORIGIN)), "Gründung")
	helper.put_goods(world, WAREHOUSE, "stone", STONE)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	var armory := helper.build(world, "armory", ARMORY_SITE)
	for site in HOUSE_SITES:
		helper.build(world, "house", site)
	helper.put_goods(world, armory, "bow", _count(ARCHER) + SPARE_BOWS)
	helper.put_goods(world, armory, "sword", _count(SWORDSMAN) + SPARE_SWORDS)
	for line in WALL_LINES:
		_ok(world.execute(Command.build_line("wall", line[0], line[1])), "Mauerlinie")
	helper.build(world, "gate", GATE)
	helper.build(world, "tower", TOWER_SITE)
	helper.build(world, "stairs", INNER_STAIRS)
	helper.build(world, "stairs", OUTER_STAIRS)
	for soldier in SOLDIERS:
		_ok(world.execute(Command.recruit(barracks, soldier[0])), "Anwerben")
	for i in SOLDIERS.size():
		_ok(world.execute(Command.move([i + 1] as Array[int], SOLDIERS[i][1])), "Bewegen")
	_wait_for_posts(world)
	for tile in BANDITS:
		helper.add_enemy(world, "bandit", tile)
	return world


static func _count(type_id: String) -> int:
	return SOLDIERS.filter(func(soldier: Array) -> bool: return soldier[0] == type_id).size()


static func _wait_for_posts(world: GameWorld) -> void:
	for tick in MAX_TICKS:
		var arrived := true
		for i in SOLDIERS.size():
			if world.get_resident(i + 1).position() != SOLDIERS[i][1]:
				arrived = false
		if arrived:
			return
		world.step()
	assert(false, "Soldaten erreichen ihre Posten nicht")


static func _ok(reason: String, what: String) -> void:
	assert(reason == "", "%s: %s" % [what, reason])
