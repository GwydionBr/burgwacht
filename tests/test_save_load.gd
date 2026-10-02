extends TestCase
## Spielwelt in Daten umwandeln und daraus wiederherstellen (ADR 0002).


## Wie beim Speichern in eine Datei: nur reine Daten überstehen das.
func _through_bytes(data: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(data))


func _reload(world: GameWorld) -> GameWorld:
	return GameWorld.from_data(_through_bytes(world.to_data()))


func test_save_and_load_gives_same_state() -> void:
	var world := run_scenario_with_seed("tiny", GameWorld.TICKS_PER_DAY * 2 + 13, 99)
	var loaded := _reload(world)
	assert_eq(loaded.get_scenario_id(), "tiny", "Szenario:")
	assert_eq(loaded.get_seed(), 99, "Seed:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")


func test_loaded_world_continues_exactly_like_unsaved_one() -> void:
	var ticks_after := GameWorld.TICKS_PER_DAY * 5
	var original := run_scenario_with_seed("tiny", GameWorld.TICKS_PER_DAY * 2 + 13, 99)
	var loaded := _reload(original)
	var trees_before := original.map.deposits.size()
	var added_original: Array[Vector2i] = []
	var added_loaded: Array[Vector2i] = []
	original.deposit_added.connect(func(tile: Vector2i) -> void: added_original.append(tile))
	loaded.deposit_added.connect(func(tile: Vector2i) -> void: added_loaded.append(tile))
	for i in ticks_after:
		original.step()
		loaded.step()
	assert_true(original.map.deposits.size() > trees_before, "Es sollten Bäume nachwachsen")
	assert_eq(added_loaded, added_original, "Nachgewachsene Bäume (gemeldet):")
	assert_eq(world_snapshot(loaded), world_snapshot(original), "Zustand nach weiteren %d Takten:" % ticks_after)
	# Auch Zufallsgenerator und Reihenfolge der Vorkommen laufen gleich weiter.
	assert_eq(loaded.to_data(), original.to_data(), "Daten nach weiteren %d Takten:" % ticks_after)


func test_save_and_load_keeps_buildings_and_storage() -> void:
	var world := run_scenario("tiny", 10)
	var loaded := _reload(world)
	assert_true(not loaded.is_founding(), "Geladene Spielwelt ist gegründet")
	assert_eq(loaded.get_buildings().size(), 2, "Gebäude:")
	assert_eq(loaded.get_stock("wood"), 100, "Holz:")
	assert_eq(loaded.get_building_at(loaded.get_buildings()[0].origin), loaded.get_buildings()[0], "Belegung nach dem Laden:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")


func test_save_and_load_keeps_built_buildings_and_several_storages() -> void:
	var world := run_scenario("tiny", 10)
	for type_id: String in ["warehouse", "woodcutter", "quarry"]:
		var site := find_site(world, type_id)
		assert_true(site != NO_SITE, "Auf der Testkarte sollte Platz für %s sein" % type_id)
		assert_eq(world.execute(Command.build(type_id, site)), "", "Bauen von %s:" % type_id)
	put_goods(world, 3, "iron", 7)
	var loaded := _reload(world)
	assert_eq(loaded.get_buildings().size(), 5, "Gebäude:")
	assert_eq(loaded.get_stock("wood"), 77, "Holz nach den Kosten:")
	assert_eq(loaded.get_stock("iron"), 7, "Eisen im zweiten Warenlager:")
	assert_eq(loaded.get_storage_capacity("warehouse"), 400, "Fassung:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	# Weiterbauen und weiterlaufen ergibt dasselbe wie ohne Speichern.
	for each: GameWorld in [world, loaded]:
		each.execute(Command.build("woodcutter", find_site(each, "woodcutter")))
		for i in GameWorld.TICKS_PER_DAY * 3:
			each.step()
	assert_eq(loaded.get_buildings().size(), 6, "Gebäude nach dem Weiterbauen:")
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach Weiterbauen und 3 Tagen:")


func test_save_and_load_during_founding() -> void:
	var world := new_world("tiny")
	var loaded := _reload(world)
	assert_true(loaded.is_founding(), "Geladene Spielwelt ist noch in Gründung")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	# Gründung nach dem Laden ergibt dasselbe wie ohne Speichern – samt Startwaren.
	found_castle(world)
	found_castle(loaded)
	for i in GameWorld.TICKS_PER_DAY * 3:
		world.step()
		loaded.step()
	assert_eq(loaded.get_stock("stone"), 50, "Stein aus den Startwaren:")
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach Gründung und 3 Tagen:")


func test_loaded_world_reports_new_day() -> void:
	var loaded := _reload(run_scenario("tiny", GameWorld.TICKS_PER_DAY - 1))
	var days: Array[int] = []
	loaded.day_started.connect(func(day: int) -> void: days.append(day))
	loaded.step()
	assert_eq(days, [2] as Array[int], "Gemeldete Tage:")


func test_saved_data_carries_format_version() -> void:
	var data := run_scenario("tiny", 0).to_data()
	assert_eq(data.get("version"), GameWorld.SAVE_VERSION, "Formatversion:")
	assert_eq(GameWorld.data_error(data), "", "Fehler bei eigenen Daten:")


func test_unknown_format_version_is_rejected_in_german() -> void:
	var data := run_scenario("tiny", 0).to_data()
	data["version"] = GameWorld.SAVE_VERSION + 1
	var expected := "Spielstand hat Formatversion %d, unterstützt wird nur %d." % [GameWorld.SAVE_VERSION + 1, GameWorld.SAVE_VERSION]
	assert_eq(GameWorld.data_error(data), expected, "Fehler:")
	assert_eq(GameWorld.from_data(data), null, "Spielwelt aus unbekannter Version:")


func test_data_without_version_is_rejected() -> void:
	assert_eq(GameWorld.data_error({"foo": 1}), "Das ist kein Spielstand (Formatversion fehlt).", "Fehler:")
	assert_eq(GameWorld.from_data({}), null, "Spielwelt aus leeren Daten:")
