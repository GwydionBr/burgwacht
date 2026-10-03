extends TestCase
## Simulationstests: Turm und Tor. Der ganze Turm ist Wehrgang, sein Eingang führt hinauf; ein Tor
## lässt am Boden durch und trägt oben Wehrgang. Wehrgang von Turm, Mauer und Tor hängt zusammen.
## Leere Karte (nur Wiese, 20×16), tiny_production mit 100 Stein; Bergfried (ID 1) bei (2, 2),
## Lagerfeuer bei (3, 8), Waffenkammer bei (10, 10) und Kaserne bei (14, 2) wie in test_wall_walk.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const WALL_WALK := Resident.Level.WALL_WALK
## Turm (2×2) frei auf der Wiese; Eingang unten links bei (6, 13), davor (6, 14).
const TOWER_SITE := Vector2i(6, 12)
const TOWER_ENTRANCE := Vector2i(6, 13)
## Senkrechte Mauer quer über die Karte bei x = 17, rechts vom Lagerfeuer.
const SPLIT_X := 17
## Obergrenze, bis ein Soldat am Ziel steht.
const MAX_TICKS := 600


## Gegründet, mit Waffenkammer, Kaserne und count angeworbenen Soldaten (IDs 1 bis count), die
## schon auf ihrem Posten stehen.
func _soldiers(count: int) -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	put_goods(world, WAREHOUSE, "stone", 100)
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", count)
	var barracks := build(world, "barracks", BARRACKS_SITE)
	for i in count:
		assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	_until_settled(world)
	return world


func _wall(world: GameWorld, from: Vector2i, to: Vector2i) -> void:
	assert_eq(world.execute(Command.build_line("wall", from, to)), "", "Mauerlinie:")


func _on_wall(tile: Vector2i) -> Vector3i:
	return Vector3i(tile.x, tile.y, WALL_WALK)


func _move(world: GameWorld, target: Vector3i) -> void:
	assert_eq(world.execute(Command.move([1] as Array[int], target)), "", "Bewegen:")


## Lässt die Welt laufen, bis alle Soldaten stehen (höchstens MAX_TICKS Takte); liefert alle
## Positionen, die der Soldat mit ID 1 dabei betreten hat.
func _until_settled(world: GameWorld) -> Array[Vector3i]:
	var visited: Array[Vector3i] = []
	for i in MAX_TICKS:
		var moving := false
		for resident: Resident in world.get_residents():
			moving = moving or resident.is_soldier() and resident.is_moving()
		var soldier := world.get_resident(1)
		if soldier != null and (visited.is_empty() or visited.back() != soldier.position()):
			visited.append(soldier.position())
		if not moving:
			return visited
		world.step()
	assert_true(false, "Soldaten sind nach %d Takten nicht angekommen" % MAX_TICKS)
	return visited


func test_tower_is_a_defense_building_with_range_bonus() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["tower"]
	assert_eq(def["behavior"], "defense", "Verhalten:")
	assert_eq(Building.size_of("tower"), Vector2i(2, 2), "Größe:")
	assert_eq(int(def["range_bonus"]), 3, "Reichweitenbonus:")
	var world := _soldiers(0)
	var tower := world.get_building(build(world, "tower", TOWER_SITE))
	assert_eq(tower.range_bonus(), 3, "Reichweitenbonus des Gebäudes:")
	assert_eq(tower.entrance(), TOWER_ENTRANCE, "Eingang:")


func test_whole_tower_is_wall_walk() -> void:
	var world := _soldiers(0)
	build(world, "tower", TOWER_SITE)
	for tile: Vector2i in Building.footprint("tower", TOWER_SITE):
		assert_true(world.is_walkable(tile, WALL_WALK), "Wehrgang auf %s" % str(tile))
	# Am Boden nur der Eingang.
	assert_true(world.is_walkable(TOWER_ENTRANCE, Resident.Level.GROUND), "Eingang am Boden")
	assert_true(not world.is_walkable(TOWER_SITE, Resident.Level.GROUND), "Turm versperrt den Boden")


func test_soldier_climbs_the_tower_through_its_entrance() -> void:
	var world := _soldiers(1)
	build(world, "tower", TOWER_SITE)
	var top := _on_wall(TOWER_SITE + Vector2i(1, 0))
	_move(world, top)
	var visited := _until_settled(world)
	assert_eq(world.get_resident(1).position(), top, "Oben angekommen:")
	# Hinauf nur am Eingang: vom Boden auf den Wehrgang derselben Kachel.
	var up := visited.find(Resident.ground(TOWER_ENTRANCE))
	assert_true(up >= 0 and visited[up + 1] == _on_wall(TOWER_ENTRANCE), "Über den Eingang: %s" % str(visited))
	# Und wieder hinab.
	_move(world, Resident.ground(Vector2i(6, 15)))
	visited = _until_settled(world)
	assert_eq(world.get_resident(1).position(), Resident.ground(Vector2i(6, 15)), "Unten angekommen:")
	var down := visited.find(_on_wall(TOWER_ENTRANCE))
	assert_true(down >= 0 and visited[down + 1] == Resident.ground(TOWER_ENTRANCE), "Hinab über den Eingang: %s" % str(visited))


func test_tower_wall_walk_continues_onto_walls_also_diagonally() -> void:
	var world := _soldiers(1)
	build(world, "tower", TOWER_SITE)
	# Gerade an der rechten Kante, schräg an der Ecke oben links.
	_wall(world, Vector2i(8, 12), Vector2i(9, 12))
	_wall(world, Vector2i(5, 11), Vector2i(3, 9))
	_move(world, _on_wall(Vector2i(9, 12)))
	_until_settled(world)
	assert_eq(world.get_resident(1).position(), _on_wall(Vector2i(9, 12)), "Über den Turm auf die Mauer:")
	_move(world, _on_wall(Vector2i(3, 9)))
	var visited := _until_settled(world)
	assert_eq(world.get_resident(1).position(), _on_wall(Vector2i(3, 9)), "Schräg vom Turm auf die Mauer:")
	assert_true(visited.has(_on_wall(TOWER_SITE)) and visited.has(_on_wall(Vector2i(5, 11))), "Oben entlang: %s" % str(visited))
	for position: Vector3i in visited:
		assert_true(position.z == WALL_WALK, "Unterwegs nicht hinab: %s" % str(visited))


func test_gate_needs_a_free_tile_and_does_not_replace_a_wall() -> void:
	var world := _soldiers(0)
	_wall(world, Vector2i(6, 11), Vector2i(6, 14))
	assert_eq(world.build_error("gate", Vector2i(6, 12)), "Mauer im Weg", "Auf der Mauer:")
	assert_eq(world.execute(Command.demolish(world.get_building_at(Vector2i(6, 12)).id)), "", "Abriss:")
	assert_eq(world.build_error("gate", Vector2i(6, 12)), "", "In der Lücke:")


func test_gate_carries_the_wall_walk_and_lets_soldiers_through_below() -> void:
	var world := _soldiers(1)
	_wall(world, Vector2i(6, 11), Vector2i(6, 11))
	_wall(world, Vector2i(6, 13), Vector2i(6, 14))
	var gate := Vector2i(6, 12)
	build(world, "gate", gate)
	assert_true(world.is_walkable(gate, Resident.Level.GROUND), "Tor am Boden begehbar")
	assert_true(world.is_walkable(gate, WALL_WALK), "Tor trägt Wehrgang")
	# Am Boden hindurch: von rechts nach links.
	_move(world, Resident.ground(Vector2i(7, 12)))
	_until_settled(world)
	_move(world, Resident.ground(Vector2i(5, 12)))
	var visited := _until_settled(world)
	assert_eq(world.get_resident(1).position(), Resident.ground(Vector2i(5, 12)), "Hindurch:")
	assert_true(visited.has(Resident.ground(gate)), "Durch das Tor: %s" % str(visited))
	# Oben über das Tor: von einer Treppe an der oberen Mauerkachel zur unteren.
	build(world, "stairs", Vector2i(5, 11))
	_move(world, _on_wall(Vector2i(6, 14)))
	visited = _until_settled(world)
	assert_eq(world.get_resident(1).position(), _on_wall(Vector2i(6, 14)), "Oben angekommen:")
	assert_true(visited.has(_on_wall(gate)), "Über das Tor: %s" % str(visited))


func test_stairs_may_border_a_tower_or_a_gate() -> void:
	var world := _soldiers(0)
	build(world, "tower", TOWER_SITE)
	assert_eq(world.build_error("stairs", Vector2i(8, 12)), "", "Am Turm:")
	build(world, "gate", Vector2i(12, 14))
	assert_eq(world.build_error("stairs", Vector2i(13, 14)), "", "Am Tor:")


## Mauer quer über die Karte bei x = SPLIT_X; dahinter ein Holzfäller.
func _split_world() -> Array:
	var world := _soldiers(0)
	put_goods(world, WAREHOUSE, "wood", 10)
	_wall(world, Vector2i(SPLIT_X, 0), Vector2i(SPLIT_X, 15))
	var woodcutter := build(world, "woodcutter", Vector2i(18, 7))
	return [world, woodcutter]


func _worker_of(world: GameWorld, workplace: int) -> Resident:
	for resident: Resident in world.get_residents():
		if resident.workplace_id == workplace:
			return resident
	return null


func test_workers_never_cross_the_wall_walk() -> void:
	var setup := _split_world()
	var world: GameWorld = setup[0]
	var woodcutter: int = setup[1]
	# Treppen auf beiden Seiten helfen Arbeitern nicht.
	build(world, "stairs", Vector2i(SPLIT_X - 1, 5))
	build(world, "stairs", Vector2i(SPLIT_X + 1, 5))
	for i in 50:
		world.step()
	assert_true(_worker_of(world, woodcutter) == null, "Kein Arbeiter ohne Tor")
	assert_true(world.get_building(woodcutter).unreachable, "Holzfäller nicht erreichbar")


func test_workers_leave_the_walls_through_a_gate() -> void:
	var setup := _split_world()
	var world: GameWorld = setup[0]
	var woodcutter: int = setup[1]
	var gate := Vector2i(SPLIT_X, 12)
	assert_eq(world.execute(Command.demolish(world.get_building_at(gate).id)), "", "Abriss:")
	build(world, "gate", gate)
	var crossed := false
	for i in MAX_TICKS:
		world.step()
		var worker := _worker_of(world, woodcutter)
		if worker != null:
			assert_true(worker.level == Resident.Level.GROUND, "Arbeiter bleibt am Boden")
			crossed = crossed or worker.tile == gate
	var worker := _worker_of(world, woodcutter)
	assert_true(worker != null, "Arbeiter zugeteilt")
	assert_true(crossed, "Durch das Tor gegangen")
