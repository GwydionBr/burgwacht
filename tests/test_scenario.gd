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
