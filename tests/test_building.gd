extends TestCase
## Simulationstests: Gebäude bauen mit Kosten aus den Warenlagern.
## Leere Karte (nur Wiese); Bergfried bei (2, 2), das erste Warenlager (ID 2) daneben, davor
## das Lagerfeuer (ID 3), unter dem Warenlager der erste Kornspeicher (ID 4); im Warenlager
## die Startwaren des Testszenarios (100 Holz, 50 Stein).

const KEEP_ORIGIN := Vector2i(2, 2)
## Freie Stelle rechts vom ersten Warenlager.
const SITE := Vector2i(12, 2)
## Freie Stelle unter dem ersten Kornspeicher.
const SITE_BELOW := Vector2i(7, 11)
## Freie Stelle direkt rechts neben dem ersten Warenlager (Bauregel des Warenlagers).
const NEXT_TO_STORAGE := Vector2i(10, 2)


func _founded_world() -> GameWorld:
	var world := empty_world()
	world.execute(Command.found(KEEP_ORIGIN))
	return world


func test_woodcutter_is_built_and_costs_wood() -> void:
	var world := _founded_world()
	assert_eq(world.execute(Command.build("woodcutter", SITE)), "", "Grund:")
	var building := world.get_building_at(SITE + Vector2i(1, 1))
	assert_eq(building.type, "woodcutter", "Gebäude auf der Grundfläche:")
	assert_eq(building.id, 5, "ID nach Bergfried, Warenlager, Lagerfeuer und Kornspeicher:")
	assert_eq(building.origin, SITE, "Ursprung:")
	assert_eq(world.get_stock("wood"), 97, "Holz nach 3 Holz Kosten:")
	assert_eq(world.get_stock("stone"), 50, "Stein unverändert:")
	assert_eq(world.get_tick(), 0, "Ohne Takt gebaut:")


func test_quarry_costs_twenty_wood() -> void:
	var world := _founded_world()
	add_rock_for_quarry(world, SITE)
	assert_eq(world.execute(Command.build("quarry", SITE)), "", "Grund:")
	assert_eq(world.get_stock("wood"), 80, "Holz:")
	assert_eq(world.get_storage_used("warehouse"), 130, "Belegt:")


func test_warehouse_is_free_and_adds_capacity() -> void:
	var world := _founded_world()
	assert_eq(world.execute(Command.build("warehouse", NEXT_TO_STORAGE)), "", "Grund:")
	assert_eq(world.get_stock("wood"), 100, "Holz:")
	assert_eq(world.get_storage_capacity("warehouse"), 400, "Fassung über zwei Warenlager:")
	assert_eq(world.get_storage_used("warehouse"), 150, "Belegt über zwei Warenlager:")


func test_building_is_reported() -> void:
	var world := _founded_world()
	var events: Array[String] = []
	world.building_added.connect(func(id: int) -> void: events.append("Gebäude %d" % id))
	world.stock_changed.connect(func(id: int) -> void: events.append("Bestand %d" % id))
	world.execute(Command.build("woodcutter", SITE))
	assert_eq(events, ["Bestand 2", "Gebäude 5"] as Array[String], "Signale:")


func test_too_few_goods_is_rejected_and_changes_nothing() -> void:
	var world := found_castle(new_world("tiny_poor"))
	var site := find_site(world, "quarry", "Zu wenig Holz (20 nötig)")
	var events: Array[String] = []
	world.building_added.connect(func(id: int) -> void: events.append("Gebäude %d" % id))
	world.stock_changed.connect(func(id: int) -> void: events.append("Bestand %d" % id))
	var before := world.to_data()
	assert_eq(world.execute(Command.build("quarry", site)), "Zu wenig Holz (20 nötig)", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")
	assert_eq(world.get_stock("wood"), 10, "Holz:")
	assert_eq(events, [] as Array[String], "Keine Signale:")


func test_exactly_enough_goods_is_allowed() -> void:
	var world := _founded_world()
	put_goods(world, 2, "wood", 3)
	assert_eq(world.execute(Command.build("woodcutter", SITE)), "", "Grund:")
	assert_eq(world.get_stock("wood"), 0, "Holz:")
	assert_eq(world.get_building(2).contents, {"stone": 50} as Dictionary[String, int], "Leere Ware fällt aus dem Lager:")
	assert_eq(world.build_error("woodcutter", SITE_BELOW), "Zu wenig Holz (3 nötig)", "Danach reicht es nicht mehr:")


func test_goods_are_checked_last() -> void:
	var world := _founded_world()
	put_goods(world, 2, "wood", 0)
	assert_eq(world.build_error("woodcutter", KEEP_ORIGIN), "Bergfried im Weg", "Belegt vor zu wenig Waren:")
	assert_eq(world.build_error("woodcutter", Vector2i(-1, 0)), "Außerhalb der Karte", "Karte vor zu wenig Waren:")
	assert_eq(world.build_error("woodcutter", SITE), "Zu wenig Holz (3 nötig)", "Sonst zu wenig Waren:")


func test_command_gives_same_reason_as_query() -> void:
	var world := _founded_world()
	put_goods(world, 2, "wood", 1)
	for origin: Vector2i in [KEEP_ORIGIN, Vector2i(-1, 0), SITE]:
		var expected: String = world.build_error("woodcutter", origin)
		assert_eq(world.execute(Command.build("woodcutter", origin)), expected, "Befehl bei %s:" % str(origin))


func test_building_before_founding_is_rejected() -> void:
	var world := empty_world()
	var before := world.to_data()
	assert_eq(world.build_error("woodcutter", SITE), "Erst die Burg gründen: Bergfried setzen.", "Abfrage:")
	assert_eq(world.execute(Command.build("woodcutter", SITE)), "Erst die Burg gründen: Bergfried setzen.", "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_keep_cannot_be_built() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.execute(Command.build("keep", SITE)), "Der Bergfried entsteht nur bei der Gründung.", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_types_without_hotkey_cannot_be_built() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.execute(Command.build("castle", SITE)), "„castle“ kann nicht gebaut werden.", "Unbekannter Typ:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_buildable_types_come_from_data() -> void:
	assert_eq(GameWorld.buildable_types(), ["warehouse", "granary", "armory", "woodcutter", "quarry", "hunter", "house",
			"orchard", "wheat_farm", "iron_mine", "mill", "bakery", "smith", "bowyer", "market", "barracks", "wall", "stairs", "tower", "gate"] as Array[String],
			"Baubare Typen:")


func test_campfire_cannot_be_built() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.execute(Command.build("campfire", SITE)), "„campfire“ kann nicht gebaut werden.", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_cost_comes_from_storages_in_ascending_id() -> void:
	var world := _founded_world()
	world.execute(Command.build("warehouse", NEXT_TO_STORAGE))
	put_goods(world, 2, "wood", 2)
	put_goods(world, 5, "wood", 10)
	assert_eq(world.get_stock("wood"), 12, "Bestand ist die Summe über alle Lager:")
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	assert_eq(world.execute(Command.build("woodcutter", SITE_BELOW)), "", "Grund:")
	assert_eq(world.get_building(2).contents, {"stone": 50} as Dictionary[String, int], "Ältestes Lager zuerst geleert:")
	assert_eq(world.get_building(5).contents, {"wood": 9} as Dictionary[String, int], "Rest aus dem nächsten Lager:")
	assert_eq(world.get_stock("wood"), 9, "Holz:")
	assert_eq(changed, [2, 5] as Array[int], "Gemeldete Lager:")


func test_cost_from_oldest_storage_leaves_newer_untouched() -> void:
	var world := _founded_world()
	world.execute(Command.build("warehouse", NEXT_TO_STORAGE))
	put_goods(world, 5, "wood", 10)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	add_rock_for_quarry(world, SITE_BELOW)
	world.execute(Command.build("quarry", SITE_BELOW))
	assert_eq(world.get_building(2).contents["wood"], 80, "Aus dem ältesten Lager:")
	assert_eq(world.get_building(5).contents["wood"], 10, "Neueres Lager unberührt:")
	assert_eq(changed, [2] as Array[int], "Nur das älteste Lager gemeldet:")


func test_building_works_while_time_runs() -> void:
	var world := _founded_world()
	for i in 7:
		world.step()
	assert_eq(world.execute(Command.build("woodcutter", SITE)), "", "Grund:")
	world.step()
	assert_eq(world.get_tick(), 8, "Takt läuft weiter:")
	assert_eq(world.get_building_at(SITE).type, "woodcutter", "Gebäude steht:")
