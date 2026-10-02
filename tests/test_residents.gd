extends TestCase
## Simulationstests: Startbewohner stehen nach der Gründung als Untätige am Lagerfeuer.
## Leere Karte (nur Wiese); Bergfried bei (2, 2), das Lagerfeuer laut Daten davor.

const ORIGIN := Vector2i(2, 2)


func _campfire(world: GameWorld) -> Vector2i:
	return founding_origin(world, "campfire", ORIGIN)


## Leere Welt aus einem Test-Szenario, bei ORIGIN gegründet.
func _founded(scenario_id := "tiny") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(ORIGIN)), "", "Gründung:")
	return world


func _tiles(residents: Array[Resident]) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for resident in residents:
		tiles.append(resident.tile)
	return tiles


func test_no_residents_before_founding() -> void:
	assert_eq(empty_world().get_residents().size(), 0, "Bewohner in Gründung:")


func test_start_residents_stand_idle_next_to_campfire() -> void:
	var world := _founded()
	var campfire := _campfire(world)
	var residents := world.get_residents()
	assert_eq(residents.size(), 4, "Bewohner (Startbewohner des Szenarios):")
	assert_eq(world.get_idle_count(), 4, "Untätige:")
	# Erst die Kacheln mit gemeinsamer Kante, im Uhrzeigersinn ab „oben“ (kleineres y).
	var expected: Array[Vector2i] = [
		campfire + Vector2i(0, -1), campfire + Vector2i(1, 0), campfire + Vector2i(0, 1), campfire + Vector2i(-1, 0),
	]
	assert_eq(_tiles(residents), expected, "Kacheln:")
	for resident in residents:
		assert_true(resident.is_idle(), "Bewohner %d sollte untätig sein" % resident.id)
		assert_eq(resident.level, Resident.Level.GROUND, "Ebene von Bewohner %d:" % resident.id)


func test_residents_get_ascending_ids() -> void:
	var ids: Array[int] = []
	for resident in _founded().get_residents():
		ids.append(resident.id)
	assert_eq(ids, [1, 2, 3, 4] as Array[int], "IDs:")


func test_ring_fills_nearest_tiles_first_then_further_out() -> void:
	var world := _founded("tiny_crowd")
	var campfire := _campfire(world)
	var tiles := _tiles(world.get_residents())
	assert_eq(tiles.size(), 14, "Bewohner:")
	var expected: Array[Vector2i] = [
		campfire + Vector2i(0, -1), campfire + Vector2i(1, 0), campfire + Vector2i(0, 1), campfire + Vector2i(-1, 0),
		campfire + Vector2i(1, -1), campfire + Vector2i(1, 1), campfire + Vector2i(-1, 1), campfire + Vector2i(-1, -1),
		campfire + Vector2i(0, -2), campfire + Vector2i(2, 0), campfire + Vector2i(0, 2), campfire + Vector2i(-2, 0),
		campfire + Vector2i(1, -2), campfire + Vector2i(2, -1),
	]
	assert_eq(tiles, expected, "Kacheln von innen nach außen:")


func test_residents_skip_blocked_tiles() -> void:
	var world := empty_world()
	var campfire := founding_origin(world, "campfire", ORIGIN)
	add_deposit(world, campfire + Vector2i(0, -1), "tree")
	world.map.set_terrain(campfire + Vector2i(1, 0), "water")
	# Ufer ist begehbar, wenn auch nicht bebaubar.
	world.map.set_terrain(campfire + Vector2i(0, 1), "sand")
	assert_eq(world.execute(Command.found(ORIGIN)), "", "Gründung:")
	var expected: Array[Vector2i] = [
		campfire + Vector2i(0, 1), campfire + Vector2i(-1, 0), campfire + Vector2i(1, -1), campfire + Vector2i(1, 1),
	]
	assert_eq(_tiles(world.get_residents()), expected, "Kacheln ohne Baum und Wasser:")


func test_residents_do_not_stand_on_buildings() -> void:
	var world := _founded("tiny_crowd")
	for resident in world.get_residents():
		assert_eq(world.get_building_at(resident.tile), null, "Gebäude unter Bewohner %d:" % resident.id)
		assert_true(world.is_walkable(resident.tile, resident.level), "Kachel von Bewohner %d begehbar" % resident.id)


func test_residents_at_tile() -> void:
	var world := _founded()
	var tile := _campfire(world) + Vector2i(1, 0)
	var here := world.get_residents_at(tile)
	assert_eq(here.size(), 1, "Bewohner auf der Kachel:")
	assert_eq(here[0].id, 2, "ID:")
	assert_eq(world.get_residents_at(_campfire(world)).size(), 0, "Auf dem Lagerfeuer selbst:")


func test_scenario_without_start_residents_has_none() -> void:
	var world := found_castle(new_world("tiny_poor"))
	assert_eq(world.get_residents().size(), 0, "Bewohner:")
	assert_eq(world.get_idle_count(), 0, "Untätige:")


func test_residents_are_reported_before_founded() -> void:
	var world := empty_world()
	var events: Array[String] = []
	world.resident_added.connect(func(id: int) -> void: events.append("Bewohner %d" % id))
	world.founded.connect(func() -> void: events.append("gegründet"))
	world.execute(Command.found(ORIGIN))
	assert_eq(events, ["Bewohner 1", "Bewohner 2", "Bewohner 3", "Bewohner 4", "gegründet"] as Array[String], "Signale:")


func test_walkability() -> void:
	var world := _founded()
	var ground := Resident.Level.GROUND
	assert_true(world.is_walkable(_campfire(world), ground), "Lagerfeuer ist begehbar")
	assert_true(world.is_walkable(Building.entrance_of("keep", ORIGIN), ground), "Eingang des Bergfrieds ist begehbar")
	assert_true(not world.is_walkable(ORIGIN, ground), "Grundfläche des Bergfrieds ist nicht begehbar")
	world.map.set_terrain(Vector2i(15, 12), "water")
	assert_true(not world.is_walkable(Vector2i(15, 12), ground), "Wasser ist nicht begehbar")
	add_deposit(world, Vector2i(16, 12), "stone")
	assert_true(not world.is_walkable(Vector2i(16, 12), ground), "Felsen ist nicht begehbar")
	assert_true(world.is_walkable(Vector2i(17, 12), ground), "Wiese ist begehbar")
	assert_true(not world.is_walkable(Vector2i(-1, 0), ground), "Außerhalb der Karte")


func test_residents_survive_save_and_load() -> void:
	var world := _founded()
	for i in 5:
		world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_residents().size(), 4, "Bewohner nach dem Laden:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")


## Ein neuer Arbeitsschritt braucht seine Bedeutung an der einen Stelle in Resident.
func test_every_task_has_phase_and_goal() -> void:
	for task: Resident.Task in Resident.Task.values():
		assert_true(Resident.TASK_PHASE.has(task), "Phase für %s" % Resident.Task.find_key(task))
		assert_true(Resident.TASK_GOAL.has(task), "Ziel für %s" % Resident.Task.find_key(task))


func test_blocked_and_waiting_follow_from_phase() -> void:
	var resident := Resident.create(1, Vector2i(3, 3), Resident.Level.GROUND)
	resident.timer = 5
	resident.task = Resident.Task.TO_STORAGE
	assert_true(resident.is_waiting() and resident.is_blocked(), "Laufschritt mit Wartezeit: Weg versperrt")
	resident.task = Resident.Task.WAITING_FOR_STORAGE
	assert_true(resident.is_waiting() and not resident.is_blocked(), "Warten auf Lagerplatz: nicht versperrt")
	resident.task = Resident.Task.MINING
	assert_true(not resident.is_waiting() and not resident.is_blocked(), "Abbau ist kein Warten")
	resident.task = Resident.Task.TO_STORAGE
	resident.path.append(Vector3i(4, 3, 0))
	assert_true(resident.is_waiting() and not resident.is_blocked(), "Unterwegs wartet er erst nach der Ankunft")
