extends TestCase
## Simulationstests: Gebäude abreißen, die Hälfte der Baukosten kommt zurück.
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), das erste Warenlager (ID 2) daneben,
## darin die Startwaren des Testszenarios (100 Holz, 50 Stein).

const KEEP_ORIGIN := Vector2i(2, 2)
## Freie Stelle rechts vom ersten Warenlager.
const SITE := Vector2i(12, 2)
## Freie Stelle unter dem ersten Warenlager.
const SITE_BELOW := Vector2i(7, 8)
## Freie Stelle direkt rechts neben dem ersten Warenlager (Bauregel des Warenlagers).
const NEXT_TO_STORAGE := Vector2i(10, 2)


func _founded_world() -> GameWorld:
	var world := empty_world()
	world.execute(Command.found(KEEP_ORIGIN))
	return world


## Felsen rechts neben einem Steinbruch mit diesem Ursprung (Bauregel des Steinbruchs).
func _add_rock_for_quarry(world: GameWorld, origin: Vector2i) -> void:
	add_deposit(world, origin + Vector2i(3, 1), "stone")


## Baut ein Gebäude und liefert seine ID.
func _build(world: GameWorld, type_id: String, origin: Vector2i) -> int:
	var reason := world.execute(Command.build(type_id, origin))
	assert(reason == "", "Bauen von %s fehlgeschlagen: %s" % [type_id, reason])
	return world.get_building_at(origin).id


func test_demolish_removes_building_and_frees_tiles() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	assert_eq(world.demolish_error(id), "", "Abfrage:")
	assert_eq(world.execute(Command.demolish(id)), "", "Grund:")
	assert_eq(world.get_building(id), null, "Gebäude weg:")
	for tile in Building.footprint("woodcutter", SITE):
		assert_eq(world.get_building_at(tile), null, "Kachel %s frei:" % str(tile))
	assert_eq(world.build_error("woodcutter", SITE), "", "Wieder bebaubar:")


func test_refund_is_half_the_cost_rounded_down() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	assert_eq(world.get_stock("wood"), 97, "Holz nach dem Bauen:")
	world.execute(Command.demolish(id))
	assert_eq(world.get_stock("wood"), 98, "3 Holz → 1 Holz zurück:")


func test_refund_of_quarry() -> void:
	var world := _founded_world()
	_add_rock_for_quarry(world, SITE)
	var id := _build(world, "quarry", SITE)
	world.execute(Command.demolish(id))
	assert_eq(world.get_stock("wood"), 90, "20 Holz → 10 Holz zurück:")


func test_refund_goes_to_storages_in_ascending_id() -> void:
	var world := _founded_world()
	_build(world, "warehouse", NEXT_TO_STORAGE)
	_add_rock_for_quarry(world, SITE_BELOW)
	var quarry := _build(world, "quarry", SITE_BELOW)
	# Erstes Lager bis auf 4 Plätze voll, das zweite leer.
	put_goods(world, 2, "wood", 146)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	assert_eq(world.execute(Command.demolish(quarry)), "", "Grund:")
	assert_eq(world.get_building(2).contents["wood"], 150, "Ältestes Lager zuerst aufgefüllt:")
	assert_eq(world.get_building(3).contents, {"wood": 6} as Dictionary[String, int], "Rest ins nächste Lager:")
	assert_eq(changed, [2, 3] as Array[int], "Gemeldete Lager:")


func test_refund_that_does_not_fit_is_lost() -> void:
	var world := _founded_world()
	_add_rock_for_quarry(world, SITE)
	var id := _build(world, "quarry", SITE)
	put_goods(world, 2, "wood", 145)
	assert_eq(world.execute(Command.demolish(id)), "", "Abriss gelingt trotzdem:")
	assert_eq(world.get_stock("wood"), 150, "Nur was passt, kommt zurück:")
	assert_eq(world.get_storage_used("warehouse"), 200, "Lager voll:")
	assert_eq(world.get_building(id), null, "Gebäude weg:")


func test_refund_without_any_storage_space_is_lost() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	put_goods(world, 2, "wood", 150)
	var changed: Array[int] = []
	world.stock_changed.connect(func(building_id: int) -> void: changed.append(building_id))
	assert_eq(world.execute(Command.demolish(id)), "", "Grund:")
	assert_eq(world.get_stock("wood"), 150, "Holz:")
	assert_eq(changed, [] as Array[int], "Kein Lager geändert:")


func test_demolish_is_reported() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	var events: Array[String] = []
	world.building_removed.connect(func(building_id: int) -> void: events.append("Gebäude weg %d" % building_id))
	world.stock_changed.connect(func(building_id: int) -> void: events.append("Bestand %d" % building_id))
	world.execute(Command.demolish(id))
	assert_eq(events, ["Gebäude weg %d" % id, "Bestand 2"] as Array[String], "Signale:")


func test_keep_cannot_be_demolished() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.demolish_error(1), "Der Bergfried kann nicht abgerissen werden.", "Abfrage:")
	assert_eq(world.execute(Command.demolish(1)), "Der Bergfried kann nicht abgerissen werden.", "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_storage_with_goods_cannot_be_demolished() -> void:
	var world := _founded_world()
	var events: Array[int] = []
	world.building_removed.connect(func(id: int) -> void: events.append(id))
	var before := world.to_data()
	assert_eq(world.execute(Command.demolish(2)), "Warenlager ist nicht leer", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")
	assert_eq(events, [] as Array[int], "Keine Signale:")


func test_empty_storage_can_be_demolished() -> void:
	var world := _founded_world()
	var id := _build(world, "warehouse", NEXT_TO_STORAGE)
	assert_eq(world.execute(Command.demolish(id)), "", "Grund:")
	assert_eq(world.get_storage_capacity("warehouse"), 200, "Nur noch das erste Lager:")
	put_goods(world, 2, "wood", 0)
	put_goods(world, 2, "stone", 0)
	assert_eq(world.execute(Command.demolish(2)), "", "Auch das letzte Lager, wenn leer:")
	assert_eq(world.get_storage_capacity("warehouse"), 0, "Kein Lager mehr:")


func test_unknown_building_cannot_be_demolished() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.execute(Command.demolish(99)), "Dieses Gebäude gibt es nicht", "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_demolish_before_founding_is_rejected() -> void:
	var world := empty_world()
	assert_eq(world.execute(Command.demolish(1)), GameWorld.FOUNDING_FIRST, "Grund:")


func test_command_gives_same_reason_as_query() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	for building_id: int in [1, 2, 99, id]:
		var expected: String = world.demolish_error(building_id)
		assert_eq(world.execute(Command.demolish(building_id)), expected, "Befehl für %d:" % building_id)


func test_ids_are_not_reused_after_demolish() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	world.execute(Command.demolish(id))
	assert_eq(_build(world, "woodcutter", SITE), id + 1, "Neue ID:")


func test_trees_grow_into_demolished_building() -> void:
	var world := _founded_world()
	var id := _build(world, "woodcutter", SITE)
	var spread: Dictionary = GameDefs.get_instance().deposits["tree"]["spread"]
	var old_chance: float = spread["chance"]
	spread["chance"] = 1.0
	var rng := RandomNumberGenerator.new()
	world.map.add_deposit(SITE + Vector2i(2, 0), Deposit.create("tree", rng))
	world.execute(Command.demolish(id))
	for i in int(spread["interval_ticks"]):
		world.step()
	spread["chance"] = old_chance
	# Der Baum grenzt an die rechte Spalte der früheren Grundfläche.
	assert_true(world.map.get_deposit(SITE + Vector2i(1, 0)) != null, "Baum wächst in die frühere Grundfläche")
	assert_true(world.map.get_deposit(SITE + Vector2i(1, 1)) != null, "Baum wächst in die frühere Grundfläche (unten)")


func test_save_and_load_after_demolish_continues_the_same() -> void:
	var world := run_scenario("tiny", 10)
	var site := find_site(world, "quarry")
	world.execute(Command.build("quarry", site))
	var id := world.get_building_at(site).id
	assert_eq(world.execute(Command.demolish(id)), "", "Abriss:")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for each: GameWorld in [world, loaded]:
		each.execute(Command.build("woodcutter", find_site(each, "woodcutter")))
		for i in GameWorld.TICKS_PER_DAY * 3:
			each.step()
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach Weiterbauen und 3 Tagen:")
