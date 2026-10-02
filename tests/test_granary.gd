extends TestCase
## Simulationstests: Kornspeicher und Nahrung. Leere Karte (nur Wiese), Bergfried bei (2, 2);
## Warenlager (ID 2), Lagerfeuer (ID 3) und Kornspeicher (ID 4) entstehen laut Daten daneben.

const KEEP_ORIGIN := Vector2i(2, 2)
const NOT_NEXT_TO_GRANARY := "Muss an einen Kornspeicher grenzen"


func _granary_origin(world: GameWorld) -> Vector2i:
	return founding_origin(world, "granary", KEEP_ORIGIN)


func _founded_world(scenario_id := "tiny") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func test_apples_and_meat_are_food_in_the_granary() -> void:
	var goods := GameDefs.get_instance().goods
	for good: String in ["apples", "meat"]:
		assert_eq(str(goods[good]["storage"]), "granary", "Lagerart von %s:" % good)
		assert_eq(goods[good].get("food", false), true, "%s ist Nahrung:" % good)
	assert_eq(goods["wood"].get("food", false), false, "Holz ist keine Nahrung:")


func test_granary_is_buildable_storage() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["granary"]
	assert_eq(str(def["behavior"]), "storage", "Verhalten:")
	assert_eq(Building.size_of("granary"), Vector2i(3, 3), "Größe:")
	assert_eq(int(def["capacity"]), 200, "Kapazität:")
	assert_eq(Building.storage_type_of("granary"), "granary", "Lagerart:")
	assert_eq(_cost(def), {"wood": 5}, "Kosten:")
	assert_true(GameWorld.buildable_types().has("granary"), "Kornspeicher hat eine Bautaste")


func _cost(def: Dictionary) -> Dictionary:
	var cost: Dictionary = {}
	for good: Variant in def["cost"]:
		cost[str(good)] = int(def["cost"][good])
	return cost


func test_founding_creates_granary() -> void:
	var world := _founded_world()
	var granary := world.get_building_at(_granary_origin(world) + Vector2i(2, 2))
	assert_true(granary != null, "Auf dem Kornspeicher sollte ein Gebäude stehen")
	assert_eq(granary.type, "granary", "Typ:")
	assert_eq(granary.id, 4, "ID:")
	assert_eq(world.get_storage_capacity("granary"), 200, "Fassung der Kornspeicher:")
	assert_eq(world.get_storage_used("granary"), 0, "Ohne Startnahrung leer:")


func test_founding_keeps_all_entrances_free() -> void:
	var world := _founded_world()
	for building in world.get_buildings():
		if not building.has_entrance():
			continue
		var front := Building.front_of_entrance(building.type, building.origin)
		assert_eq(world.get_building_at(front), null, "Vor dem Eingang von %s:" % building.type)
		assert_true(world.is_walkable(front, Resident.Level.GROUND), "Vor dem Eingang von %s begehbar" % building.type)


func test_start_goods_go_to_storage_of_their_kind() -> void:
	var world := _founded_world("tiny_food")
	assert_eq(world.get_building(2).contents, {"wood": 100, "stone": 50} as Dictionary[String, int], "Warenlager:")
	assert_eq(world.get_building(4).contents, {"apples": 30, "meat": 10} as Dictionary[String, int], "Kornspeicher:")
	assert_eq(world.get_stock("apples"), 30, "Äpfel:")
	assert_eq(world.get_stock("meat"), 10, "Fleisch:")
	assert_eq(world.get_storage_used("granary"), 40, "Belegt:")
	assert_eq(world.get_storage_used("warehouse"), 150, "Warenlager belegt:")


func test_founding_reports_stock_of_each_filled_storage() -> void:
	var world := empty_world("tiny_food")
	var events: Array[String] = []
	world.stock_changed.connect(func(id: int) -> void: events.append("Bestand %d" % id))
	world.founded.connect(func() -> void: events.append("gegründet"))
	world.execute(Command.found(KEEP_ORIGIN))
	assert_eq(events, ["Bestand 2", "Bestand 4", "gegründet"] as Array[String], "Signale:")


func test_granary_next_to_granary_is_allowed() -> void:
	var world := _founded_world()
	var next_to := _granary_origin(world) + Vector2i(3, 0)
	assert_eq(world.execute(Command.build("granary", next_to)), "", "Grund:")
	assert_eq(world.get_stock("wood"), 95, "Holz nach den Kosten:")
	assert_eq(world.get_storage_capacity("granary"), 400, "Fassung:")


func test_granary_away_from_granary_is_rejected() -> void:
	var world := _founded_world()
	var away := _granary_origin(world) + Vector2i(5, 0)
	var before := world.to_data()
	assert_eq(world.build_error("granary", away), NOT_NEXT_TO_GRANARY, "Abfrage:")
	assert_eq(world.execute(Command.build("granary", away)), NOT_NEXT_TO_GRANARY, "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_warehouse_does_not_count_as_granary() -> void:
	var world := _founded_world()
	# Rechts neben dem ersten Warenlager, aber nicht am Kornspeicher.
	var warehouse := world.get_building(2)
	assert_eq(world.build_error("granary", warehouse.origin + Vector2i(3, -2)), NOT_NEXT_TO_GRANARY, "Neben dem Warenlager:")


func test_save_and_load_keeps_granary_and_food() -> void:
	var world := _founded_world("tiny_food")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_building(4).type, "granary", "Kornspeicher:")
	assert_eq(loaded.get_stock("apples"), 30, "Äpfel:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in GameWorld.TICKS_PER_DAY * 2:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren 2 Tagen:")


func test_storage_name_comes_from_storage_building() -> void:
	assert_eq(Building.storage_name("granary"), "Kornspeicher", "Kornspeicher:")
	assert_eq(Building.storage_name("warehouse"), "Warenlager", "Warenlager:")
