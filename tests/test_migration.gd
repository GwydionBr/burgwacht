extends TestCase
## Simulationstests: Kommen und Gehen nach der Beliebtheit. Leere Karte 20×16 (nur Wiese),
## Bergfried (ID 1) bei (2, 2), Lagerfeuer (ID 3) bei (3, 8); Grundwohnraum 8, 4 Startbewohner
## als Untätige um das Lagerfeuer (Bewohner 4 bei (2, 8)).
## tiny_popular: Beliebtheit 97 → Abstand 18 Takte; tiny_unpopular: 3 → ebenfalls 18 Takte;
## tiny_discontent: 49 → 294 Takte, mit 20 Äpfeln.

const KEEP_ORIGIN := Vector2i(2, 2)
const CAMPFIRE := Vector2i(3, 8)
## Die Randkachel mit dem kürzesten Weg zum Lagerfeuer und zu den Bewohnern dort.
const EDGE := Vector2i(0, 8)
## Abstand bei Beliebtheit 97 bzw. 3.
const INTERVAL := 18
## Freie Stellen für Holzfäller bzw. Wohnhäuser (2×2).
const SITE := Vector2i(12, 2)
const SITE_2 := Vector2i(15, 2)
## Obergrenze, bis jemand angekommen sein muss.
const MAX_TICKS := 500


func _founded(scenario_id: String) -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _steps(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


## Lässt die Welt laufen, bis der Bewohner steht oder verschwunden ist (höchstens MAX_TICKS).
func _until_settled(world: GameWorld, id: int) -> void:
	for i in MAX_TICKS:
		var resident := world.get_resident(id)
		if resident == null or not resident.is_moving():
			return
		world.step()
	assert_true(false, "Bewohner %d ist nach %d Takten nicht angekommen" % [id, MAX_TICKS])


func _ids(world: GameWorld) -> Array[int]:
	var result: Array[int] = []
	for resident in world.get_residents():
		result.append(resident.id)
	return result


## Die IDs der Bewohner, die gerade gehen.
func _leaving(world: GameWorld) -> Array[int]:
	var result: Array[int] = []
	for resident in world.get_residents():
		if world.activity_of(resident) == "verlässt die Burg":
			result.append(resident.id)
	return result


## Setzt das Gelände auf dem Rand des Rechtecks (Ecken eingeschlossen).
func _set_border(world: GameWorld, top_left: Vector2i, bottom_right: Vector2i, terrain: String) -> void:
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			if x == top_left.x or x == bottom_right.x or y == top_left.y or y == bottom_right.y:
				world.map.set_terrain(Vector2i(x, y), terrain)


## Wassergraben eine Kachel innerhalb des Kartenrands: Der Rand bleibt begehbar, ist aber
## von der Burg aus nicht erreichbar.
func _moat(world: GameWorld) -> void:
	_set_border(world, Vector2i(1, 1), Vector2i(world.map.width - 2, world.map.height - 2), "water")


func test_migration_interval_comes_from_data() -> void:
	var migration: Dictionary = GameDefs.get_instance().population["migration"]
	assert_eq(int(migration["base_ticks"]), 300, "Grundabstand:")
	assert_eq(int(migration["ticks_per_point"]), 6, "Takte je Punkt:")
	assert_eq(int(migration["min_ticks"]), 10, "Mindestabstand:")
	assert_eq(Population.migration_ticks(56), 264, "Abstand bei 56:")
	assert_eq(Population.migration_ticks(44), 264, "Abstand bei 44:")
	assert_eq(Population.migration_ticks(97), INTERVAL, "Abstand bei 97:")
	assert_eq(Population.migration_ticks(100), 10, "Abstand bei 100 (Mindestabstand):")
	assert_eq(Population.migration_ticks(0), 10, "Abstand bei 0 (Mindestabstand):")


func test_newcomer_appears_at_edge_after_interval() -> void:
	var world := _founded("tiny_popular")
	var added: Array[int] = []
	world.resident_added.connect(func(id: int) -> void: added.append(id))
	_steps(world, INTERVAL - 1)
	assert_eq(world.get_population(), 4, "Vor Ablauf des Abstands:")
	world.step()
	assert_eq(added, [5] as Array[int], "Neuer Bewohner gemeldet:")
	var newcomer := world.get_resident(5)
	assert_eq(newcomer.tile, EDGE, "Erscheint am Rand:")
	assert_eq(world.activity_of(newcomer), "kommt an", "Tätigkeit:")
	assert_eq(world.get_population(), 5, "Zählt ab dem Erscheinen:")
	assert_eq(world.get_idle_count(), 4, "Ist noch kein Untätiger:")
	_steps(world, INTERVAL)
	assert_eq(world.get_population(), 6, "Nach einem weiteren Abstand:")


func test_newcomer_becomes_idle_at_campfire() -> void:
	var world := _founded("tiny_popular")
	_steps(world, INTERVAL)
	_until_settled(world, 5)
	var newcomer := world.get_resident(5)
	assert_eq(world.activity_of(newcomer), "Untätig", "Tätigkeit am Ziel:")
	assert_true((newcomer.tile - CAMPFIRE).length() <= 2.0, "Steht am Lagerfeuer, war %s" % str(newcomer.tile))
	assert_true(newcomer.is_idle(), "Ist Untätiger")


func test_newcomer_is_assigned_once_at_campfire() -> void:
	var world := _founded("tiny_popular")
	var workplaces: Array[int] = []
	for site: Vector2i in [Vector2i(12, 2), Vector2i(15, 2), Vector2i(12, 6), Vector2i(15, 6), Vector2i(12, 10)]:
		workplaces.append(build(world, "woodcutter", site))
	world.step()
	assert_eq(world.get_workers(workplaces[4]).size(), 0, "Für den fünften Holzfäller fehlt ein Untätiger:")
	_steps(world, INTERVAL)
	assert_eq(world.get_resident(5).workplace_id, 0, "Unterwegs nicht zugeteilt:")
	assert_eq(world.activity_of(world.get_resident(5)), "kommt an", "Tätigkeit unterwegs:")
	_until_settled(world, 5)
	world.step()
	assert_eq(world.get_resident(5).workplace_id, workplaces[4], "Am Lagerfeuer dem fünften zugeteilt:")


func test_no_arrival_without_free_housing() -> void:
	var world := _founded("tiny_popular")
	_steps(world, INTERVAL * 10)
	assert_eq(world.get_population(), 8, "Bis der Wohnraum voll ist:")
	build(world, "house", SITE)
	_steps(world, INTERVAL)
	assert_eq(world.get_population(), 9, "Mit einem Wohnhaus kommen wieder welche:")


func test_no_migration_at_balance() -> void:
	var world := _founded("tiny")
	_steps(world, GameWorld.TICKS_PER_DAY - 1)
	assert_eq(_ids(world), [1, 2, 3, 4] as Array[int], "Bei Beliebtheit 50 kommt und geht niemand:")


func test_no_arrival_during_founding() -> void:
	var world := empty_world("tiny_popular")
	_steps(world, INTERVAL * 3)
	assert_eq(world.get_residents().size(), 0, "In der Gründung:")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(world.get_population(), 4, "Nach der Gründung nur die Startbewohner:")


func test_newcomer_appears_at_smaller_edge_tile_on_tie() -> void:
	var world := empty_world("tiny_popular")
	world.map.set_terrain(EDGE, "water")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	_steps(world, INTERVAL)
	assert_eq(world.get_resident(5).tile, Vector2i(0, 7), "(0, 7) und (0, 9) gleich weit:")


func test_newcomer_appears_at_campfire_without_reachable_edge() -> void:
	var world := empty_world("tiny_popular")
	_moat(world)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	_steps(world, INTERVAL)
	var newcomer := world.get_resident(5)
	assert_true(newcomer != null, "Neuer Bewohner ist da")
	assert_true((newcomer.tile - CAMPFIRE).length() <= 2.0, "Steht am Lagerfeuer, war %s" % str(newcomer.tile))
	assert_eq(world.activity_of(newcomer), "Untätig", "Gleich Untätiger:")


func test_newcomer_reroutes_when_path_is_blocked() -> void:
	var world := _founded("tiny_popular")
	_steps(world, INTERVAL)
	var newcomer := world.get_resident(5)
	var next: Vector3i = newcomer.path[0]
	world.map.set_terrain(Vector2i(next.x, next.y), "water")
	_until_settled(world, 5)
	assert_eq(world.activity_of(newcomer), "Untätig", "Kommt trotzdem an:")


func test_newcomer_makes_way_for_new_building() -> void:
	var world := _founded("tiny_popular")
	_steps(world, INTERVAL)
	var newcomer := world.get_resident(5)
	while newcomer.tile.x < 1:
		world.step()
	# Er steht auf einer Kachel der Grundfläche, nicht auf dem Eingang.
	assert_eq(world.execute(Command.build("house", newcomer.tile - Vector2i(1, 1))), "", "Bauen über ihm:")
	assert_true(world.is_walkable(newcomer.tile, newcomer.level), "Ist ausgewichen")
	_until_settled(world, 5)
	assert_eq(world.activity_of(newcomer), "Untätig", "Kommt trotzdem an:")


func test_idle_with_largest_id_leaves_first() -> void:
	var world := _founded("tiny_unpopular")
	_steps(world, INTERVAL - 1)
	assert_eq(_leaving(world), [] as Array[int], "Vor Ablauf des Abstands:")
	world.step()
	assert_eq(_leaving(world), [4] as Array[int], "Gehende:")
	assert_eq(world.get_population(), 3, "Gehender zählt nicht mehr:")
	assert_eq(world.get_idle_count(), 3, "Auch nicht als Untätiger:")
	assert_eq(world.get_residents().size(), 4, "Ist aber noch zu sehen:")


func test_leaving_resident_walks_to_edge_and_disappears() -> void:
	var world := _founded("tiny_unpopular")
	var removed: Array[int] = []
	world.resident_removed.connect(func(id: int) -> void: removed.append(id))
	_steps(world, INTERVAL)
	var leaving := world.get_resident(4)
	assert_eq(leaving.destination(), EDGE, "Geht zur nächsten Randkachel:")
	_until_settled(world, 4)
	assert_eq(world.get_resident(4), null, "Am Rand entfernt:")
	assert_eq(removed, [4] as Array[int], "Entfernen gemeldet:")


func test_workers_of_youngest_workplace_leave_after_idle() -> void:
	var world := _founded("tiny_unpopular")
	var older := build(world, "woodcutter", SITE)
	var younger := build(world, "woodcutter", SITE_2)
	world.step()
	assert_eq(world.get_resident(1).workplace_id, older, "Bewohner 1 im älteren:")
	assert_eq(world.get_resident(2).workplace_id, younger, "Bewohner 2 im jüngeren:")
	var order: Array[int] = []
	for i in INTERVAL * 4:
		world.step()
		for id in _leaving(world):
			if not order.has(id):
				order.append(id)
	assert_eq(order, [4, 3, 2, 1] as Array[int], "Reihenfolge der Gehenden:")


func test_leaving_worker_frees_workplace_and_drops_goods() -> void:
	var world := _founded("tiny_unpopular")
	var id := build(world, "woodcutter", SITE)
	add_deposit(world, SITE + Vector2i(3, 0), "tree")
	world.step()
	var worker := world.get_resident(1)
	worker.carried_good = "wood"
	worker.carried_amount = 4
	worker.task = Resident.Task.TO_DEPOSIT
	worker.deposit_tile = SITE + Vector2i(3, 0)
	_steps(world, INTERVAL * 4)
	assert_eq(world.activity_of(worker), "verlässt die Burg", "Arbeiter geht:")
	assert_eq(worker.workplace_id, 0, "Arbeitsstätte frei:")
	assert_eq(world.get_workers(id).size(), 0, "Keine Arbeiter mehr:")
	assert_eq(worker.carried_amount, 0, "Ware verfällt:")
	assert_true(not worker.is_targeting_deposit(SITE + Vector2i(3, 0)), "Reservierung verfällt")
	assert_eq(world.get_stock("wood"), 97, "Nichts eingelagert:")


func test_leaving_resident_does_not_eat() -> void:
	var world := _founded("tiny_discontent")
	_steps(world, GameWorld.TICKS_PER_DAY)
	assert_eq(_leaving(world), [3] as Array[int], "Bewohner 3 ist noch unterwegs:")
	assert_eq(world.get_resident(4), null, "Bewohner 4 ist schon fort:")
	assert_eq(world.get_stock("apples"), 18, "Zwei Bewohner essen normal:")


func test_leaving_without_reachable_edge_disappears_at_once() -> void:
	var world := empty_world("tiny_unpopular")
	_moat(world)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	var removed: Array[int] = []
	world.resident_removed.connect(func(id: int) -> void: removed.append(id))
	_steps(world, INTERVAL)
	assert_eq(removed, [4] as Array[int], "Sofort entfernt:")
	assert_eq(_ids(world), [1, 2, 3] as Array[int], "Übrige Bewohner:")


func test_leaving_resident_reroutes_when_path_is_blocked() -> void:
	var world := _founded("tiny_unpopular")
	_steps(world, INTERVAL)
	var next: Vector3i = world.get_resident(4).path[0]
	world.map.set_terrain(Vector2i(next.x, next.y), "water")
	world.step()
	assert_eq(world.activity_of(world.get_resident(4)), "verlässt die Burg", "Geht weiter:")
	_until_settled(world, 4)
	assert_eq(world.get_resident(4), null, "Kommt trotzdem am Rand an:")


func test_surplus_leaves_at_once_after_demolishing_house() -> void:
	var world := _founded("tiny_popular")
	var house := build(world, "house", SITE)
	# Sechs Ankommende; der letzte (10) ist noch unterwegs.
	_steps(world, INTERVAL * 7 - 1)
	assert_eq(world.get_population(), 10, "Mit Wohnhaus:")
	assert_eq(world.activity_of(world.get_resident(10)), "kommt an", "Bewohner 10:")
	assert_eq(world.execute(Command.demolish(house)), "", "Abriss:")
	assert_eq(world.get_population(), 8, "Sofort nur noch so viele wie Wohnraum:")
	assert_eq(_leaving(world), [8, 9] as Array[int], "Die Untätigen mit den größten IDs gehen, nicht der Ankommende:")


func test_surplus_leaves_regardless_of_popularity() -> void:
	var world := _founded("tiny_crowd")
	assert_eq(world.get_population(), 14, "Startbewohner über dem Wohnraum:")
	world.step()
	assert_eq(world.get_population(), 8, "Bei Beliebtheit 50 gehen die Überzähligen:")
	assert_eq(_leaving(world), [9, 10, 11, 12, 13, 14] as Array[int], "Gehende:")


func test_save_and_load_during_arrival() -> void:
	var world := _founded("tiny_popular")
	_steps(world, INTERVAL + 3)
	assert_eq(world.activity_of(world.get_resident(5)), "kommt an", "Gespeichert mitten in der Ankunft:")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	assert_eq(loaded.activity_of(loaded.get_resident(5)), "kommt an", "Tätigkeit nach dem Laden:")
	for i in GameWorld.TICKS_PER_DAY + 7:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach einem weiteren Tag:")


func test_save_and_load_during_departure() -> void:
	var world := _founded("tiny_unpopular")
	_steps(world, INTERVAL * 2 + 2)
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(_leaving(loaded), _leaving(world), "Gehende nach dem Laden:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in INTERVAL * 3:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten:")
