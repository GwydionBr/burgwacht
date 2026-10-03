extends TestCase
## Simulationstests: Wehrgang auf Mauern, Treppen verbinden Boden und Wehrgang. Soldaten gehen auf beiden Ebenen
## und wechseln sie nur über Treppen, alle anderen Bewohner bleiben am Boden. Leere Karte (nur
## Wiese, 20×16), tiny_production mit 100 Stein; Bergfried (ID 1) bei (2, 2), Lagerfeuer bei
## (3, 8), Waffenkammer bei (10, 10) und Kaserne bei (14, 2) wie in test_move.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const WALL_WALK := Figure.Level.WALL_WALK
## Senkrechte Mauer von (6, 11) bis (6, 14), Treppe links daneben.
const WALL_TOP := Vector2i(6, 11)
const WALL_BOTTOM := Vector2i(6, 14)
const STAIRS := Vector2i(5, 12)
## Obergrenze, bis ein Soldat am Ziel steht.
const MAX_TICKS := 600


## Gegründet, mit Waffenkammer, Kaserne und count angeworbenen Soldaten (IDs 1 bis count).
func _soldiers(count: int) -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	put_goods(world, WAREHOUSE, "stone", 100)
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", count)
	var barracks := build(world, "barracks", BARRACKS_SITE)
	for i in count:
		assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	return world


func _wall(world: GameWorld, from: Vector2i, to: Vector2i) -> void:
	assert_eq(world.execute(Command.build_line("wall", from, to)), "", "Mauerlinie:")


## Die senkrechte Mauer mit Treppe.
func _wall_with_stairs(world: GameWorld) -> void:
	_wall(world, WALL_TOP, WALL_BOTTOM)
	build(world, "stairs", STAIRS)


func _on_wall(tile: Vector2i) -> Vector3i:
	return Vector3i(tile.x, tile.y, WALL_WALK)


## Lässt die Welt laufen, bis alle Soldaten stehen (höchstens MAX_TICKS Takte); liefert alle
## Positionen, die der Soldat mit dieser ID dabei betreten hat.
func _until_settled(world: GameWorld, watched := 1) -> Array[Vector3i]:
	var visited: Array[Vector3i] = []
	for i in MAX_TICKS:
		var moving := false
		for resident in world.get_residents():
			moving = moving or resident.is_moving()
			assert_true(resident.is_soldier() or resident.level == Figure.Level.GROUND,
					"Bewohner %d auf dem Wehrgang" % resident.id)
		var soldier := world.get_resident(watched)
		if soldier != null and (visited.is_empty() or visited.back() != soldier.position()):
			visited.append(soldier.position())
		if not moving:
			return visited
		world.step()
	assert_true(false, "Soldaten sind nach %d Takten nicht angekommen" % MAX_TICKS)
	return visited


func test_stairs_must_border_a_wall() -> void:
	var world := _soldiers(0)
	assert_eq(world.build_error("stairs", STAIRS), "Muss an eine Mauer grenzen", "Ohne Mauer:")
	_wall(world, WALL_TOP, WALL_BOTTOM)
	# Schräg an der Ecke zählt nicht.
	assert_eq(world.build_error("stairs", WALL_TOP + Vector2i(-1, -1)), "Muss an eine Mauer grenzen", "Schräg:")
	assert_eq(world.build_error("stairs", STAIRS), "", "An der Mauer:")


func test_soldier_climbs_the_stairs_onto_the_wall_walk() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	_wall_with_stairs(world)
	assert_true(world.is_walkable(WALL_BOTTOM, WALL_WALK), "Wehrgang auf der Mauer")
	assert_true(not world.is_walkable(WALL_BOTTOM, Figure.Level.GROUND), "Mauer versperrt den Boden")
	assert_true(not world.is_walkable(STAIRS, WALL_WALK), "Auf der Treppe kein Wehrgang")
	assert_eq(world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM))), "", "Bewegen:")
	var visited := _until_settled(world)
	assert_eq(world.get_resident(1).position(), _on_wall(WALL_BOTTOM), "Oben angekommen:")
	# Hinauf nur von der Treppe auf die Mauerkachel daneben.
	var up := visited.find(Figure.ground(STAIRS))
	assert_true(up >= 0 and visited[up + 1] == _on_wall(STAIRS + Vector2i(1, 0)), "Über die Treppe: %s" % str(visited))


func test_soldier_walks_along_a_diagonal_wall() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	_wall(world, Vector2i(1, 10), Vector2i(5, 14))
	build(world, "stairs", Vector2i(0, 10))
	assert_eq(world.execute(Command.move([1] as Array[int], _on_wall(Vector2i(5, 14)))), "", "Bewegen:")
	var visited := _until_settled(world)
	var on_wall: Array[Vector3i] = []
	for position in visited:
		if position.z == WALL_WALK:
			on_wall.append(position)
	assert_eq(on_wall, [_on_wall(Vector2i(1, 10)), _on_wall(Vector2i(2, 11)), _on_wall(Vector2i(3, 12)),
			_on_wall(Vector2i(4, 13)), _on_wall(Vector2i(5, 14))] as Array[Vector3i], "Schräg über die Mauer:")


func test_diagonal_wall_is_closed_on_the_ground() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	# Schneidet die Ecke unten links ab; dahinter liegt (0, 15).
	_wall(world, Vector2i(0, 12), Vector2i(3, 15))
	assert_eq(world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(0, 15)))), "Kein Weg dorthin",
			"Kein Weg durch die schräge Mauer:")


func test_wall_walk_without_stairs_is_out_of_reach() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	_wall(world, WALL_TOP, WALL_BOTTOM)
	var before := world.to_data()
	assert_eq(world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM))), "Kein Weg dorthin", "Ohne Treppe:")
	assert_eq(world.to_data(), before, "Unverändert:")


func test_workers_never_use_the_wall_walk() -> void:
	var world := _soldiers(0)
	# Mauer quer über die Karte mit Treppen auf beiden Seiten; Holzfäller und Kaserne dahinter.
	_wall(world, Vector2i(13, 0), Vector2i(13, 15))
	build(world, "stairs", Vector2i(12, 7))
	build(world, "stairs", Vector2i(14, 7))
	add_deposit(world, Vector2i(18, 14), "tree")
	var woodcutter := build(world, "woodcutter", Vector2i(16, 9))
	put_goods(world, world.get_building_at(ARMORY_SITE).id, "sword", 1)
	var barracks := world.get_building_at(BARRACKS_SITE).id
	assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	var soldier := world.get_resident(1)
	assert_eq(soldier.post_tile(), world.get_building(barracks).entrance_front(), "Posten hinter der Mauer:")
	_until_settled(world)
	assert_eq(soldier.position(), soldier.post, "Soldat über die Treppen an seinem Posten:")
	assert_true(world.get_building(woodcutter).unreachable, "Holzfäller ist für Arbeiter nicht erreichbar")
	assert_eq(world.get_workers(woodcutter).size(), 0, "Kein Arbeiter:")


func test_soldiers_spread_along_the_wall_walk() -> void:
	var world := _soldiers(3)
	_wall_with_stairs(world)
	assert_eq(world.execute(Command.move([1, 2, 3] as Array[int], _on_wall(Vector2i(6, 12)))), "", "Bewegen:")
	var posts: Array[Vector3i] = []
	for id: int in [1, 2, 3]:
		posts.append(world.get_resident(id).post)
	# Ziel, dann die nächsten Wehrgang-Kacheln: oben, unten (rechts und links ist keiner).
	assert_eq(posts, [_on_wall(Vector2i(6, 12)), _on_wall(Vector2i(6, 11)), _on_wall(Vector2i(6, 13))] as Array[Vector3i],
			"Posten auf dem Wehrgang:")
	_until_settled(world)
	for id: int in [1, 2, 3]:
		assert_eq(world.get_resident(id).position(), posts[id - 1], "Soldat %d am Posten:" % id)


func test_soldier_on_a_demolished_wall_moves_to_the_next_wall_walk_else_down() -> void:
	var world := _soldiers(1)
	_wall_with_stairs(world)
	world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM)))
	_until_settled(world)
	var soldier := world.get_resident(1)
	var changed: Array[int] = []
	world.resident_changed.connect(func(id: int) -> void: changed.append(id))
	assert_eq(world.execute(Command.demolish(world.get_building_at(WALL_BOTTOM).id)), "", "Abriss:")
	var above := WALL_BOTTOM + Vector2i(0, -1)
	assert_eq(soldier.position(), _on_wall(above), "Auf die Wehrgang-Kachel daneben:")
	assert_eq(soldier.post, _on_wall(above), "Posten ist die neue Position:")
	assert_eq(changed, [1] as Array[int], "Gemeldet:")
	# Ohne Wehrgang daneben geht es auf den Boden derselben Kachel.
	world.execute(Command.demolish(world.get_building_at(above + Vector2i(0, -1)).id))
	world.execute(Command.demolish(world.get_building_at(above).id))
	assert_eq(soldier.position(), Figure.ground(above), "Auf den Boden:")
	assert_eq(soldier.post, Figure.ground(above), "Posten am Boden:")
	assert_true(not soldier.is_moving(), "Steht")


func test_soldier_on_a_demolished_wall_skips_the_posts_of_others() -> void:
	var world := _soldiers(2)
	_wall_with_stairs(world)
	var middle := WALL_BOTTOM + Vector2i(0, -1)
	world.execute(Command.move([1, 2] as Array[int], _on_wall(middle)))
	_until_settled(world)
	var above := _on_wall(middle + Vector2i(0, -1))
	assert_eq(world.get_resident(2).post, above, "Soldat 2 steht darüber:")
	world.execute(Command.demolish(world.get_building_at(middle).id))
	# Oben ist der Posten von Soldat 2, also unten (6, 14).
	var soldier := world.get_resident(1)
	assert_eq(soldier.position(), _on_wall(WALL_BOTTOM), "Ausgewichen:")
	assert_eq(soldier.post, _on_wall(WALL_BOTTOM), "Eigener Posten:")
	assert_eq(world.get_resident(2).post, above, "Soldat 2 behält seinen Posten:")


func test_soldiers_on_a_demolished_wall_get_their_own_refuge() -> void:
	var world := _soldiers(2)
	_wall_with_stairs(world)
	var middle := _on_wall(WALL_BOTTOM + Vector2i(0, -1))
	world.execute(Command.move([1] as Array[int], middle))
	_until_settled(world)
	# Soldat 2 geht über die Kachel von Soldat 1 nach unten.
	world.execute(Command.move([2] as Array[int], _on_wall(WALL_BOTTOM)))
	var other := world.get_resident(2)
	while other.position() != middle:
		world.step()
	world.execute(Command.demolish(world.get_building_at(WALL_BOTTOM + Vector2i(0, -1)).id))
	# Soldat 1 (kleinere ID) zuerst: nach oben; für Soldat 2 bleibt unten.
	assert_eq(world.get_resident(1).position(), middle + Vector3i(0, -1, 0), "Soldat 1:")
	assert_eq(other.position(), _on_wall(WALL_BOTTOM), "Soldat 2:")
	assert_eq(other.post, _on_wall(WALL_BOTTOM), "Posten von Soldat 2:")


func test_soldier_on_the_way_up_replans_when_the_stairs_are_demolished() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	_wall_with_stairs(world)
	var soldier := world.get_resident(1)
	world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM)))
	while soldier.tile != STAIRS:
		world.step()
	assert_eq(world.execute(Command.demolish(world.get_building_at(STAIRS).id)), "", "Abriss der Treppe:")
	for i in 100:
		world.step()
	assert_eq(soldier.level, Figure.Level.GROUND, "Ohne Treppe kein Weg hinauf")
	assert_true(soldier.is_blocked(), "Wartet: Weg versperrt")


func test_save_and_load_on_the_wall_walk_keeps_the_course() -> void:
	var world := _soldiers(2)
	_wall_with_stairs(world)
	world.execute(Command.move([1, 2] as Array[int], _on_wall(WALL_BOTTOM)))
	var soldier := world.get_resident(1)
	while soldier.level != WALL_WALK:
		world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in 200:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
	assert_eq(loaded.get_resident(1).position(), _on_wall(WALL_BOTTOM), "Oben angekommen:")


func test_post_on_a_demolished_wall_moves_to_the_next_wall_walk() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	_wall_with_stairs(world)
	world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM)))
	world.step()
	world.execute(Command.demolish(world.get_building_at(WALL_BOTTOM).id))
	var soldier := world.get_resident(1)
	assert_eq(soldier.post, _on_wall(WALL_BOTTOM + Vector2i(0, -1)), "Posten weicht aus:")
	_until_settled(world)
	assert_eq(soldier.position(), soldier.post, "Am neuen Posten:")


func test_soldier_walking_on_a_demolished_wall_stops_on_the_next_wall_walk() -> void:
	var world := _soldiers(1)
	_wall_with_stairs(world)
	world.execute(Command.move([1] as Array[int], _on_wall(WALL_BOTTOM)))
	var soldier := world.get_resident(1)
	# Mitten im Schritt von (6, 13) nach (6, 14) oben.
	var middle := _on_wall(WALL_BOTTOM + Vector2i(0, -1))
	while soldier.position() != middle or soldier.step_progress == 0:
		world.step()
	world.execute(Command.demolish(world.get_building_at(Vector2i(middle.x, middle.y)).id))
	# Gerade daneben zuerst: oben (6, 12).
	assert_eq(soldier.position(), _on_wall(WALL_BOTTOM + Vector2i(0, -2)), "Ausgewichen:")
	assert_eq(soldier.post, soldier.position(), "Posten ist die neue Position:")
	assert_true(not soldier.is_moving(), "Steht")
	for i in 50:
		world.step()
	assert_eq(soldier.position(), soldier.post, "Bleibt dort:")
