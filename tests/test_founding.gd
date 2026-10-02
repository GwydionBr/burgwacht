extends TestCase
## Simulationstests: Gründung der Burg mit Bergfried und erstem Warenlager.


func test_new_world_is_in_founding_and_time_stands_still() -> void:
	var world := new_world("tiny")
	var days: Array[int] = []
	world.day_started.connect(func(day: int) -> void: days.append(day))
	for i in GameWorld.TICKS_PER_DAY + 1:
		world.step()
	assert_true(world.is_founding(), "Neue Spielwelt sollte in Gründung sein")
	assert_eq(world.get_tick(), 0, "Takt während der Gründung:")
	assert_eq(days, [] as Array[int], "Gemeldete Tage während der Gründung:")


## Bergfried bei (2, 2) auf leerer Karte; erstes Warenlager und Lagerfeuer liegen laut Daten daneben.
const ORIGIN := Vector2i(2, 2)


func _storage_origin(world: GameWorld) -> Vector2i:
	return founding_origin(world, "warehouse", ORIGIN)


func _campfire_tile(world: GameWorld) -> Vector2i:
	return founding_origin(world, "campfire", ORIGIN)


func _building_ids(world: GameWorld) -> Array[int]:
	var ids: Array[int] = []
	for building in world.get_buildings():
		ids.append(building.id)
	return ids


func test_founding_works_immediately_without_step() -> void:
	var world := empty_world()
	assert_eq(world.execute(Command.found(ORIGIN)), "", "Grund:")
	assert_true(not world.is_founding(), "Nach der Gründung nicht mehr in Gründung")
	var keep := world.get_building_at(ORIGIN + Vector2i(3, 3))
	var storage := world.get_building_at(_storage_origin(world) + Vector2i(2, 2))
	assert_eq(keep.type, "keep", "Gebäude auf der hinteren Ecke des Bergfrieds:")
	assert_eq(keep.origin, ORIGIN, "Ursprung des Bergfrieds:")
	assert_eq(storage.type, "warehouse", "Gebäude auf dem ersten Warenlager:")
	var campfire := world.get_building_at(_campfire_tile(world))
	assert_eq(campfire.type, "campfire", "Gebäude auf dem Lagerfeuer:")
	assert_eq(world.get_building_at(ORIGIN + Vector2i(4, 0)), null, "Neben dem Bergfried frei:")
	assert_eq(_building_ids(world), [1, 2, 3] as Array[int], "Fortlaufende IDs:")
	assert_eq(world.get_tick(), 0, "Takt:")


func test_time_runs_after_founding() -> void:
	var world := empty_world()
	world.execute(Command.found(ORIGIN))
	for i in 5:
		world.step()
	assert_eq(world.get_tick(), 5, "Takt:")


func test_first_warehouse_holds_start_goods() -> void:
	var world := empty_world()
	world.execute(Command.found(ORIGIN))
	assert_eq(world.get_stock("wood"), 100, "Holz:")
	assert_eq(world.get_stock("stone"), 50, "Stein:")
	assert_eq(world.get_stock("iron"), 0, "Eisen:")
	assert_eq(world.get_building(2).contents, {"wood": 100, "stone": 50} as Dictionary[String, int], "Inhalt des Warenlagers:")
	assert_eq(world.get_storage_used("warehouse"), 150, "Belegt:")
	assert_eq(world.get_storage_capacity("warehouse"), 200, "Fassung:")


func test_start_goods_beyond_capacity_are_lost() -> void:
	var world := found_castle(new_world("tiny_rich"))
	assert_eq(world.get_stock("wood"), 180, "Holz:")
	assert_eq(world.get_stock("stone"), 20, "Stein (Rest verfällt):")
	assert_eq(world.get_stock("iron"), 0, "Eisen (passt nicht mehr):")
	assert_eq(world.get_storage_used("warehouse"), 200, "Belegt:")


func test_founding_is_reported() -> void:
	var world := empty_world()
	var events: Array[String] = []
	world.building_added.connect(func(id: int) -> void: events.append("Gebäude %d" % id))
	world.stock_changed.connect(func(id: int) -> void: events.append("Bestand %d" % id))
	world.founded.connect(func() -> void: events.append("gegründet"))
	world.execute(Command.found(ORIGIN))
	assert_eq(events, ["Gebäude 1", "Gebäude 2", "Gebäude 3", "Bestand 2", "gegründet"] as Array[String], "Signale:")


func test_only_founding_is_allowed_while_founding() -> void:
	var world := empty_world()
	var before := world.to_data()
	var reason := world.execute(Command.build("warehouse", ORIGIN))
	assert_eq(reason, "Erst die Burg gründen: Bergfried setzen.", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_castle_is_founded_only_once() -> void:
	var world := empty_world()
	world.execute(Command.found(ORIGIN))
	var before := world.to_data()
	assert_eq(world.execute(Command.found(Vector2i(2, 9))), "Die Burg ist bereits gegründet.", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_rejected_founding_changes_nothing() -> void:
	var world := empty_world()
	var events: Array[String] = []
	world.building_added.connect(func(id: int) -> void: events.append("Gebäude %d" % id))
	world.founded.connect(func() -> void: events.append("gegründet"))
	var before := world.to_data()
	assert_eq(world.execute(Command.found(Vector2i(-1, 2))), "Außerhalb der Karte", "Grund:")
	assert_true(world.is_founding(), "Weiter in Gründung")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")
	assert_eq(events, [] as Array[String], "Keine Signale:")


func test_founding_site_is_found_on_real_map() -> void:
	var world := new_world("tiny")
	var site := world.find_founding_site()
	assert_true(site != GameWorld.NO_SITE, "Auf der Testkarte sollte es eine Gründungsstelle geben")
	assert_eq(world.founding_error(site), "", "Grund an der gefundenen Stelle:")


func test_founding_buildings_are_keep_storage_and_campfire() -> void:
	var world := empty_world()
	var types: Array[String] = []
	for part in world.founding_buildings(ORIGIN):
		types.append(str(part[0]))
	assert_eq(types, ["keep", "warehouse", "campfire"] as Array[String], "Gebäude der Gründung:")
	assert_eq(world.founding_buildings(ORIGIN)[0][1], ORIGIN, "Ursprung des Bergfrieds:")


func test_campfire_leaves_tile_in_front_of_keep_entrance_free() -> void:
	var world := empty_world()
	world.execute(Command.found(ORIGIN))
	var front := Building.front_of_entrance("keep", ORIGIN)
	assert_eq(world.get_building_at(front), null, "Kachel vor dem Eingang:")
	assert_eq(_campfire_tile(world), front + Vector2i(0, 2), "Lagerfeuer zwei Kacheln vor dem Eingang:")
