extends TestCase
## Simulationstests: Der Befehl Mauerlinie baut Mauern als gerade Linie (eingerastet auf
## waagrecht, senkrecht oder diagonal), überspringt unbebaubare Kacheln und hört auf, wenn der
## Stein nicht mehr reicht. Leere Karte (nur Wiese), tiny_production: 50 Stein; Bergfried (ID 1)
## bei (2, 2), Warenlager (ID 2) bei (7, 2).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const START := Vector2i(5, 10)


func _world() -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Die Kacheln, auf denen jetzt eine Mauer steht, nach Gebäude-ID.
func _wall_tiles(world: GameWorld) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for building in world.get_buildings():
		if building.type == "wall":
			result.append(building.origin)
	return result


func _row(from: Vector2i, step: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in count:
		result.append(from + step * i)
	return result


func test_line_builds_one_wall_per_tile_from_the_start() -> void:
	var world := _world()
	assert_eq(world.execute(Command.build_line("wall", START, START + Vector2i(4, 0))), "", "Mauerlinie:")
	assert_eq(_wall_tiles(world), _row(START, Vector2i(1, 0), 5), "Mauern:")
	assert_eq(world.get_stock("stone"), 40, "2 Stein je Kachel:")


func test_other_directions_snap_to_the_nearest_straight_or_diagonal_line() -> void:
	var world := _world()
	# 14° → waagrecht, so lang wie der Weg entlang x.
	assert_eq(world.line_tiles(START, START + Vector2i(4, 1)), _row(START, Vector2i(1, 0), 5), "Fast waagrecht:")
	# 104° nach oben → senkrecht.
	assert_eq(world.line_tiles(START, START + Vector2i(-1, -4)), _row(START, Vector2i(0, -1), 5), "Fast senkrecht:")
	# 34° → diagonal; Länge der Mittelwert beider Achsen, gerundet: (3 + 2) / 2 → 3.
	assert_eq(world.line_tiles(START, START + Vector2i(3, 2)), _row(START, Vector2i(1, 1), 4), "Schräg:")
	assert_eq(world.line_tiles(START, START + Vector2i(-2, 2)), _row(START, Vector2i(-1, 1), 3), "Genau diagonal:")
	assert_eq(world.line_tiles(START, START), [START] as Array[Vector2i], "Eine Kachel:")


func test_unbuildable_tiles_are_skipped() -> void:
	var world := _world()
	add_deposit(world, START + Vector2i(1, 0), "tree")
	build(world, "house", START + Vector2i(3, -1))
	assert_eq(world.execute(Command.build_line("wall", START, START + Vector2i(5, 0))), "", "Mauerlinie:")
	assert_eq(_wall_tiles(world), [START, START + Vector2i(2, 0), START + Vector2i(5, 0)] as Array[Vector2i],
			"Baum und Wohnhaus übersprungen:")


func test_line_stops_when_the_stone_runs_out() -> void:
	var world := _world()
	put_goods(world, WAREHOUSE, "stone", 7)
	add_deposit(world, START + Vector2i(1, 0), "tree")
	assert_eq(world.execute(Command.build_line("wall", START, START + Vector2i(6, 0))), "", "Mauerlinie:")
	# 7 Stein reichen für drei Kacheln; der Baum zählt nicht mit.
	assert_eq(_wall_tiles(world), [START, START + Vector2i(2, 0), START + Vector2i(3, 0)] as Array[Vector2i],
			"Bis der Stein ausgeht:")
	assert_eq(world.get_stock("stone"), 1, "Rest:")


func test_plan_shows_per_tile_what_is_built_without_changing_anything() -> void:
	var world := _world()
	put_goods(world, WAREHOUSE, "stone", 4)
	add_deposit(world, START + Vector2i(1, 0), "tree")
	var before := world.to_data()
	var plan := world.line_plan("wall", START, START + Vector2i(3, 0))
	assert_eq(plan.keys(), _row(START, Vector2i(1, 0), 4), "Kacheln ab dem Start:")
	assert_eq(plan.values(), ["", "Baum im Weg", "", "Zu wenig Stein (2 nötig)"], "Je Kachel:")
	assert_eq(world.to_data(), before, "Unverändert:")


func test_line_is_rejected_only_if_no_tile_is_built() -> void:
	var world := _world()
	add_deposit(world, START, "tree")
	add_deposit(world, START + Vector2i(1, 0), "stone")
	var before := world.to_data()
	assert_eq(world.execute(Command.build_line("wall", START, START + Vector2i(1, 0))), "Baum im Weg",
			"Grund der ersten Kachel:")
	assert_eq(world.to_data(), before, "Unverändert:")
	put_goods(world, WAREHOUSE, "stone", 1)
	assert_eq(world.execute(Command.build_line("wall", START + Vector2i(0, 1), START + Vector2i(3, 1))),
			"Zu wenig Stein (2 nötig)", "Kein Stein:")
	assert_eq(world.execute(Command.build_line("house", START + Vector2i(0, 1), START + Vector2i(3, 1))),
			"„Wohnhaus“ kann nicht als Linie gebaut werden", "Kein Linientyp:")
	assert_eq(world.execute(Command.build_line("moat", START, START)), "„moat“ kann nicht gebaut werden.", "Unbekannt:")


func test_single_walls_can_be_demolished_for_half_the_cost() -> void:
	var world := _world()
	world.execute(Command.build_line("wall", START, START + Vector2i(2, 0)))
	assert_eq(world.execute(Command.demolish(world.get_building_at(START + Vector2i(1, 0)).id)), "", "Abriss:")
	assert_eq(_wall_tiles(world), [START, START + Vector2i(2, 0)] as Array[Vector2i], "Die anderen bleiben:")
	assert_eq(world.get_stock("stone"), 45, "1 Stein zurück:")
