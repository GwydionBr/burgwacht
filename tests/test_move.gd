extends TestCase
## Simulationstests: der Befehl Bewegen verteilt die Auswahl auf freie Kacheln am Ziel und
## setzt damit ihre Posten. Leere Karte (nur Wiese), tiny_production mit 100 Gold; Bergfried
## (ID 1) bei (2, 2), Lagerfeuer (ID 3) bei (3, 8); Waffenkammer (ID 5) und Kaserne (ID 6)
## wie in test_barracks.

const KEEP_ORIGIN := Vector2i(2, 2)
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const WAREHOUSE := 2
## Freie Wiese links in der Mitte der Karte.
const TARGET := Vector2i(10, 7)
## Obergrenze, bis ein Soldat am Ziel steht.
const MAX_TICKS := 500


## Gegründet, mit Waffenkammer und Kaserne und count angeworbenen Soldaten (IDs 1 bis count).
func _soldiers(count: int) -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", count)
	var barracks := build(world, "barracks", BARRACKS_SITE)
	for i in count:
		assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	return world


## Lässt die Welt laufen, bis alle Soldaten stehen (höchstens MAX_TICKS Takte).
func _until_settled(world: GameWorld) -> void:
	for i in MAX_TICKS:
		var moving := false
		for resident in world.get_residents():
			moving = moving or resident.is_moving()
		if not moving:
			return
		world.step()
	assert_true(false, "Soldaten sind nach %d Takten nicht angekommen" % MAX_TICKS)


func _posts(world: GameWorld, ids: Array[int]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for id in ids:
		result.append(world.get_resident(id).post_tile())
	return result


func test_moved_soldier_gets_the_target_as_post_and_walks_there() -> void:
	var world := _soldiers(1)
	_until_settled(world)
	var soldier := world.get_resident(1)
	var changed: Array[int] = []
	world.resident_changed.connect(func(id: int) -> void: changed.append(id))
	assert_eq(world.execute(Command.move([1] as Array[int], Resident.ground(TARGET))), "", "Bewegen:")
	assert_eq(soldier.post, Resident.ground(TARGET), "Neuer Posten:")
	assert_true(soldier.is_moving(), "Läuft los")
	assert_eq(changed, [1] as Array[int], "Gemeldet:")
	assert_eq(world.activity_of(soldier), "Schwertkämpfer – geht zum Posten", "Unterwegs:")
	_until_settled(world)
	assert_eq(soldier.tile, TARGET, "Am Ziel:")
	assert_eq(world.activity_of(soldier), "Schwertkämpfer – auf Posten", "Steht:")


func test_soldiers_spread_to_the_nearest_free_tiles_in_id_order() -> void:
	var world := _soldiers(3)
	# Die Reihenfolge im Befehl spielt keine Rolle.
	assert_eq(world.execute(Command.move([3, 1, 2] as Array[int], Resident.ground(TARGET))), "", "Bewegen:")
	# Ziel, dann die nächsten Kacheln im Uhrzeigersinn ab „oben“ (0, -1): oben, rechts.
	assert_eq(_posts(world, [1, 2, 3]), [TARGET, TARGET + Vector2i(0, -1), TARGET + Vector2i(1, 0)] as Array[Vector2i],
			"Posten nach ID:")
	_until_settled(world)
	for id in [1, 2, 3]:
		var soldier := world.get_resident(id)
		assert_eq(soldier.position(), soldier.post, "Soldat %d am Posten:" % id)


func test_posts_of_other_soldiers_and_buildings_are_not_free() -> void:
	var world := _soldiers(3)
	world.execute(Command.move([1] as Array[int], Resident.ground(TARGET)))
	# Wohnhaus (2×2) rechts neben dem Ziel; rechts (11, 7) ist damit belegt.
	build(world, "house", TARGET + Vector2i(1, 0))
	assert_eq(world.execute(Command.move([2, 3] as Array[int], Resident.ground(TARGET))), "", "Bewegen:")
	# Ziel ist Posten von 1; oben frei; rechts Wohnhaus; dann unten.
	assert_eq(_posts(world, [1, 2, 3]), [TARGET, TARGET + Vector2i(0, -1), TARGET + Vector2i(0, 1)] as Array[Vector2i],
			"Posten:")


func test_moving_again_frees_the_old_posts() -> void:
	var world := _soldiers(2)
	world.execute(Command.move([1, 2] as Array[int], Resident.ground(TARGET)))
	# Wer selbst mitgeht, gibt seinen Posten frei: dieselben Kacheln noch einmal.
	world.execute(Command.move([1, 2] as Array[int], Resident.ground(TARGET)))
	assert_eq(_posts(world, [1, 2]), [TARGET, TARGET + Vector2i(0, -1)] as Array[Vector2i], "Posten:")


func test_only_tiles_reachable_from_the_target_count() -> void:
	var world := _soldiers(2)
	var old_post := world.get_resident(2).post
	# Eine einzelne Mauerkachel mit Treppe: Der Wehrgang dort ist nur eine Kachel groß, die
	# Kacheln daneben sind von ihm aus nicht erreichbar – der zweite behält seinen Posten.
	put_goods(world, WAREHOUSE, "stone", 10)
	var target := Vector3i(4, 13, Resident.Level.WALL_WALK)
	assert_eq(world.execute(Command.build_line("wall", Vector2i(4, 13), Vector2i(4, 13))), "", "Mauer:")
	build(world, "stairs", Vector2i(3, 13))
	assert_eq(world.execute(Command.move([1, 2] as Array[int], target)), "", "Bewegen:")
	assert_eq(world.get_resident(1).post, target, "Erster aufs Ziel:")
	assert_eq(world.get_resident(2).post, old_post, "Zweiter behält seinen Posten:")


func test_move_reasons() -> void:
	var world := _soldiers(1)
	var target := Resident.ground(TARGET)
	assert_eq(world.execute(Command.move([] as Array[int], target)), "Keine Soldaten ausgewählt", "Leer:")
	assert_eq(world.execute(Command.move([99] as Array[int], target)), "Kein Soldat", "Unbekannt:")
	# Bewohner 2 ist ein Untätiger.
	assert_eq(world.execute(Command.move([1, 2] as Array[int], target)), "Kein Soldat", "Untätiger:")
	assert_eq(world.execute(Command.move([1] as Array[int], Resident.ground(Vector2i(-1, 3)))),
			"Dort kann kein Soldat stehen", "Außerhalb der Karte:")
	assert_eq(world.execute(Command.move([1] as Array[int], Resident.ground(KEEP_ORIGIN))),
			"Dort kann kein Soldat stehen", "Bergfried:")
	# Felsen schließen eine Kachel ein: Dort kann man stehen, aber niemand kommt hin.
	var enclosed := Vector2i(4, 13)
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		add_deposit(world, enclosed + offset, "stone")
	assert_eq(world.execute(Command.move([1] as Array[int], Resident.ground(enclosed))), "Kein Weg dorthin", "Eingeschlossen:")


func test_rejected_move_changes_nothing() -> void:
	var world := _soldiers(1)
	var before := world.to_data()
	assert_eq(world.execute(Command.move([1, 2] as Array[int], Resident.ground(TARGET))), "Kein Soldat", "Abgelehnt:")
	assert_eq(world.to_data(), before, "Unverändert:")


func test_moved_post_is_kept_when_building_over_it() -> void:
	var world := _soldiers(1)
	world.execute(Command.move([1] as Array[int], Resident.ground(TARGET)))
	_until_settled(world)
	build(world, "house", TARGET)
	var soldier := world.get_resident(1)
	assert_true(soldier.post_tile().distance_to(TARGET) < 3.0, "Neuer Posten nahe dem alten")
	_until_settled(world)
	assert_eq(soldier.position(), soldier.post, "Am neuen Posten:")


func test_save_and_load_keeps_moved_post() -> void:
	var world := _soldiers(2)
	world.execute(Command.move([1, 2] as Array[int], Resident.ground(TARGET)))
	for i in 9:
		world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	assert_eq(_posts(loaded, [1, 2]), _posts(world, [1, 2]), "Posten:")
	for i in 200:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
