extends TestCase

func _valid_data() -> Dictionary:
	return {"name": "Test", "map": {"width": 12, "height": 10}, "seed": 3}


func _error_for(data: Dictionary) -> String:
	return Scenario.from_dict("test", data).error


func test_free_play_is_default_and_valid() -> void:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	assert_eq(Scenario.DEFAULT, "free_play", "Standard-Szenario:")
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.id, "free_play", "ID:")
	assert_true(scenario.random_seed, "Freies Spiel sollte einen zufälligen Seed haben")


func test_load_valid_scenario() -> void:
	var scenario := Scenario.load_named("tiny", TEST_SCENARIO_DIR)
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.title, "Kleine Testkarte", "Name:")
	assert_eq(scenario.map_size, Vector2i(20, 16), "Kartengröße:")
	assert_true(not scenario.random_seed, "Seed sollte fest sein")
	assert_eq(scenario.resolve_seed(123), 7, "Fester Seed ignoriert den Zufallswert:")


func test_random_seed_scenario() -> void:
	var scenario := Scenario.load_named("tiny_random", TEST_SCENARIO_DIR)
	assert_eq(scenario.error, "", "Fehler:")
	assert_true(scenario.random_seed, "Seed sollte zufällig sein")
	assert_eq(scenario.resolve_seed(123), 123, "Zufälliger Seed nimmt den Zufallswert:")


func test_missing_scenario_reports_german_error() -> void:
	var scenario := Scenario.load_named("gibt_es_nicht", TEST_SCENARIO_DIR)
	assert_true(scenario.error.contains("gibt_es_nicht"), "Fehler nennt den Namen: " + scenario.error)
	assert_true(scenario.error.contains("nicht gefunden"), "Fehler sagt, was los ist: " + scenario.error)


func test_broken_json_reports_error() -> void:
	var scenario := Scenario.load_named("broken", TEST_SCENARIO_DIR)
	assert_true(scenario.error.contains("broken"), "Fehler nennt den Namen: " + scenario.error)
	assert_true(scenario.error.contains("JSON"), "Fehler nennt JSON: " + scenario.error)


func test_valid_dict_has_no_error() -> void:
	assert_eq(_error_for(_valid_data()), "", "Fehler:")


func test_missing_name_is_invalid() -> void:
	var data := _valid_data()
	data.erase("name")
	assert_true(_error_for(data).contains("name"), "Fehler: " + _error_for(data))


func test_bad_map_size_is_invalid() -> void:
	for map: Variant in [null, {"width": 12}, {"width": 0, "height": 10}, {"width": 12.5, "height": 10}, {"width": "12", "height": 10}]:
		var data := _valid_data()
		data["map"] = map
		assert_true(_error_for(data).contains("map"), "Kartengröße %s: %s" % [str(map), _error_for(data)])


func test_bad_seed_is_invalid() -> void:
	for seed_value: Variant in [null, "zufall", 1.5, true]:
		var data := _valid_data()
		data["seed"] = seed_value
		assert_true(_error_for(data).contains("seed"), "Seed %s: %s" % [str(seed_value), _error_for(data)])


func test_error_names_scenario() -> void:
	var data := _valid_data()
	data.erase("name")
	assert_true(Scenario.from_dict("mein_test", data).error.contains("mein_test"), "Fehler nennt die ID")


func test_start_goods_are_read() -> void:
	var scenario := Scenario.load_named("tiny", TEST_SCENARIO_DIR)
	assert_eq(scenario.start_goods, {"wood": 100, "stone": 50} as Dictionary[String, int], "Startwaren:")


func test_free_play_starts_with_wood_stone_and_apples() -> void:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	assert_eq(scenario.start_goods, {"wood": 100, "stone": 50, "apples": 40} as Dictionary[String, int], "Startwaren:")


func test_missing_start_goods_means_none() -> void:
	var scenario := Scenario.from_dict("test", _valid_data())
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.start_goods, {} as Dictionary[String, int], "Startwaren:")


func test_unknown_good_in_start_goods_is_invalid() -> void:
	var data := _valid_data()
	data["start_goods"] = {"wood": 10, "gold": 5}
	assert_true(_error_for(data).contains("„gold“"), "Fehler nennt die Ware: " + _error_for(data))


func test_bad_start_goods_amount_is_invalid() -> void:
	for amount: Variant in [-1, 1.5, "10", null]:
		var data := _valid_data()
		data["start_goods"] = {"wood": amount}
		assert_true(_error_for(data).contains("start_goods"), "Menge %s: %s" % [str(amount), _error_for(data)])


func test_start_goods_must_be_object() -> void:
	var data := _valid_data()
	data["start_goods"] = [1, 2]
	assert_true(_error_for(data).contains("start_goods"), "Fehler: " + _error_for(data))


func test_free_play_starts_with_eight_residents() -> void:
	assert_eq(Scenario.load_named(Scenario.DEFAULT).start_residents, 8, "Startbewohner:")


func test_start_residents_are_read() -> void:
	var data := _valid_data()
	data["start_residents"] = 3.0
	var scenario := Scenario.from_dict("test", data)
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.start_residents, 3, "Startbewohner:")


func test_missing_start_residents_means_none() -> void:
	assert_eq(Scenario.from_dict("test", _valid_data()).start_residents, 0, "Startbewohner:")


func test_bad_start_residents_is_invalid() -> void:
	for amount: Variant in [-1, 1.5, "8", null, true]:
		var data := _valid_data()
		data["start_residents"] = amount
		assert_true(_error_for(data).contains("start_residents"), "Startbewohner %s: %s" % [str(amount), _error_for(data)])


func test_start_popularity_is_read() -> void:
	var data := _valid_data()
	data["start_popularity"] = 70.0
	var scenario := Scenario.from_dict("test", data)
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.start_popularity, 70, "Startbeliebtheit:")


func test_missing_start_popularity_means_fifty() -> void:
	assert_eq(Scenario.from_dict("test", _valid_data()).start_popularity, 50, "Startbeliebtheit:")


func test_free_play_starts_with_popularity_fifty() -> void:
	assert_eq(Scenario.load_named(Scenario.DEFAULT).start_popularity, 50, "Startbeliebtheit:")


func test_bad_start_popularity_is_invalid() -> void:
	for value: Variant in [-1, 101, 50.5, "50", null, true]:
		var data := _valid_data()
		data["start_popularity"] = value
		assert_true(_error_for(data).contains("start_popularity"), "Startbeliebtheit %s: %s" % [str(value), _error_for(data)])


func test_start_gold_is_read() -> void:
	var data := _valid_data()
	data["start_gold"] = 120.0
	var scenario := Scenario.from_dict("test", data)
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.start_gold, 120, "Startgold:")


func test_missing_start_gold_means_zero() -> void:
	assert_eq(Scenario.from_dict("test", _valid_data()).start_gold, 0, "Startgold:")


func test_free_play_starts_with_100_gold() -> void:
	assert_eq(Scenario.load_named(Scenario.DEFAULT).start_gold, 100, "Startgold:")


func test_bad_start_gold_is_invalid() -> void:
	for value: Variant in [-1, 2.5, "10", null, true]:
		var data := _valid_data()
		data["start_gold"] = value
		assert_true(_error_for(data).contains("start_gold"), "Startgold %s: %s" % [str(value), _error_for(data)])


func test_enemies_are_read() -> void:
	var data := _valid_data()
	data["enemies"] = [{"type": "bandit", "tile": [3.0, 4.0]}, {"type": "bandit", "tile": [11, 9]}]
	var scenario := Scenario.from_dict("test", data)
	assert_eq(scenario.error, "", "Fehler:")
	var read := scenario.start_enemies.map(func(entry: StartEnemy) -> Array: return [entry.type_id, entry.tile])
	assert_eq(read, [["bandit", Vector2i(3, 4)], ["bandit", Vector2i(11, 9)]], "Feinde:")


func test_missing_enemies_means_none() -> void:
	assert_eq(Scenario.from_dict("test", _valid_data()).start_enemies.size(), 0, "Feinde:")


func test_bad_enemies_are_invalid() -> void:
	for value: Variant in [5, [{"type": "swordsman", "tile": [1, 1]}], [{"type": "bandit"}],
			[{"type": "bandit", "tile": [12, 1]}], [{"type": "bandit", "tile": [1.5, 1]}], ["bandit"]]:
		var data := _valid_data()
		data["enemies"] = value
		assert_true(_error_for(data).contains("enemies"), "Feinde %s: %s" % [str(value), _error_for(data)])


func _waves_data(waves: Variant) -> Dictionary:
	var data := _valid_data()
	data["waves"] = waves
	return data


func test_wave_list_is_read() -> void:
	var scenario := Scenario.from_dict("test", _waves_data({"list": [
		{"day": 2.0, "enemies": {"bandit": 3.0}, "side": "north"},
		{"day": 2, "enemies": {"bandit": 0}},
		{"day": 5, "enemies": {"bandit": 1}, "side": "west"},
	]}))
	assert_eq(scenario.error, "", "Fehler:")
	var read := scenario.wave_plan.list.map(func(wave: PlannedWave) -> Array: return [wave.day, wave.enemies, wave.side])
	assert_eq(read, [[2, {"bandit": 3}, "north"], [2, {"bandit": 0}, ""], [5, {"bandit": 1}, "west"]], "Wellen:")


func test_missing_wave_plan_means_no_waves() -> void:
	var scenario := Scenario.from_dict("test", _valid_data())
	assert_eq(scenario.error, "", "Fehler:")
	assert_eq(scenario.wave_plan.list.size(), 0, "Wellen:")
	assert_eq(Scenario.from_dict("test", _waves_data({})).wave_plan.list.size(), 0, "Wellen ohne Liste:")


func test_wave_plan_must_be_an_object_with_a_list() -> void:
	for value: Variant in [5, [], "list", {"list": 3}, {"list": [3]}]:
		var error := _error_for(_waves_data(value))
		assert_true(error.contains("waves"), "Wellenplan %s: %s" % [str(value), error])


func test_wave_with_unknown_enemy_type_is_invalid() -> void:
	for enemies: Variant in [{"swordsman": 1}, {"drache": 2}, 4, null]:
		var error := _error_for(_waves_data({"list": [{"day": 1, "enemies": enemies}]}))
		assert_true(error.contains("waves") and error.contains("Feind"), "Feinde %s: %s" % [str(enemies), error])


func test_wave_with_invalid_side_is_invalid() -> void:
	for side: Variant in ["nord", "North", "", 1]:
		var error := _error_for(_waves_data({"list": [{"day": 1, "enemies": {"bandit": 1}, "side": side}]}))
		assert_true(error.contains("waves") and error.contains("side"), "Seite %s: %s" % [str(side), error])


func test_wave_before_day_one_is_invalid() -> void:
	for day: Variant in [0, -3, 1.5, "1", null]:
		var error := _error_for(_waves_data({"list": [{"day": day, "enemies": {"bandit": 1}}]}))
		assert_true(error.contains("waves") and error.contains("day"), "Tag %s: %s" % [str(day), error])


func test_waves_with_descending_days_are_invalid() -> void:
	var error := _error_for(_waves_data({"list": [
		{"day": 4, "enemies": {"bandit": 1}}, {"day": 3, "enemies": {"bandit": 1}}]}))
	assert_true(error.contains("waves") and error.contains("aufsteigend"), "Absteigende Tage: " + error)


func test_wave_with_negative_count_is_invalid() -> void:
	for count: Variant in [-1, 1.5, "2"]:
		var error := _error_for(_waves_data({"list": [{"day": 1, "enemies": {"bandit": count}}]}))
		assert_true(error.contains("waves") and error.contains("Anzahl"), "Anzahl %s: %s" % [str(count), error])


func test_warning_days_are_read_with_one_day_as_default() -> void:
	assert_eq(Scenario.from_dict("test", _waves_data({})).wave_plan.warning_days, 1, "Standard:")
	assert_eq(Scenario.from_dict("test", _valid_data()).wave_plan.warning_days, 1, "Ohne Wellenplan:")
	for days: int in [0, 3]:
		var scenario := Scenario.from_dict("test", _waves_data({"warning_days": float(days)}))
		assert_eq(scenario.error, "", "Fehler:")
		assert_eq(scenario.wave_plan.warning_days, days, "Vorwarnzeit:")


func test_negative_or_broken_warning_days_are_invalid() -> void:
	for days: Variant in [-1, 0.5, "1", null]:
		var error := _error_for(_waves_data({"warning_days": days}))
		assert_true(error.contains("waves") and error.contains("warning_days"), "Vorwarnzeit %s: %s" % [str(days), error])
