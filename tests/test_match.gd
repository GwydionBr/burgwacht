extends TestCase
## Die Partie: startet aus einer Startbeschreibung und hält Spielwelt und Szenario.


func _new_match() -> Match:
	return Match.new(TEST_SCENARIO_DIR)


func test_start_from_scenario_and_seed_gives_that_map() -> void:
	var game := _new_match()
	assert_eq(game.start(MatchStart.from_scenario_with_seed("tiny_random", 99)), "", "Fehler beim Start:")
	var expected := MapGenerator.generate(99, 20, 16)
	assert_eq(game.world.get_seed(), 99, "Seed:")
	assert_eq(game.world.map.to_data(), expected.to_data(), "Karte:")
	assert_eq(game.scenario.id, "tiny_random", "Szenario:")
	assert_true(game.world.is_founding(), "Neue Partie beginnt mit der Gründung")


func test_start_without_seed_uses_the_seed_of_the_scenario() -> void:
	var game := _new_match()
	assert_eq(game.start(MatchStart.from_scenario("tiny")), "", "Fehler beim Start:")
	assert_eq(game.world.get_seed(), 7, "Fester Seed aus tiny.json:")


func test_failed_start_keeps_the_running_world() -> void:
	var game := _new_match()
	game.start(MatchStart.from_scenario("tiny"))
	var before := game.world
	assert_true(game.start(MatchStart.from_scenario("gibt_es_nicht")).contains("nicht gefunden"), "Grund fehlt")
	assert_true(game.world == before, "Spielwelt sollte bleiben")
	assert_eq(game.scenario.id, "tiny", "Szenario:")


func test_start_from_save_continues_that_world_in_its_scenario() -> void:
	var temp := DirAccess.create_temp("burgwacht_match", false)
	var saves := SaveGames.new(temp.get_current_dir())
	var saved := run_scenario("tiny_three", 30)
	assert_eq(saves.save(saved, "Drei", SaveGame.Kind.QUICK), "", "Fehler beim Speichern:")
	var game := _new_match()
	game.start(MatchStart.from_scenario("tiny"))
	assert_eq(game.start(MatchStart.from_save(saves.path_for(SaveGame.Kind.QUICK))), "", "Fehler beim Laden:")
	assert_eq(world_snapshot(game.world), world_snapshot(saved), "Spielwelt:")
	assert_eq(game.scenario.id, "tiny_three", "Szenario nach dem Laden:")


func test_damaged_save_gives_a_message_and_keeps_the_world() -> void:
	var temp := DirAccess.create_temp("burgwacht_match", false)
	var path := temp.get_current_dir().path_join("kaputt.sav")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("kein Spielstand")
	file.close()
	var game := _new_match()
	game.start(MatchStart.from_scenario("tiny"))
	var before := game.world
	assert_eq(game.start(MatchStart.from_save(path)), SaveGames.CORRUPT, "Grund:")
	assert_true(game.world == before, "Spielwelt sollte bleiben")
	assert_false(game.start(MatchStart.from_save(path + ".fehlt")) == "", "Fehlende Datei sollte nicht laden")


func test_start_from_setup_builds_that_world() -> void:
	var game := Match.new()
	assert_eq(game.start(MatchStart.from_setup("barracks")), "", "Fehler beim Start:")
	assert_eq(game.world.get_soldier_count(), 2, "Soldaten aus dem Testaufbau:")
	assert_eq(game.scenario.id, Scenario.DEFAULT, "Testszenario fehlt in den Spieldaten, neue Karte im Standardszenario:")
	assert_true(game.start(MatchStart.from_setup("gibt_es_nicht")).contains("fehlt"), "Grund für fehlenden Testaufbau")


func test_start_args_fill_the_description() -> void:
	var game := _new_match()
	assert_eq(game.start(MatchStart.from_args({"scenario": "tiny_random", "seed": "42"})), "", "Fehler beim Start:")
	assert_eq([game.scenario.id, game.world.get_seed()], ["tiny_random", 42], "Szenario und Seed:")
	game.start(MatchStart.from_args({"scenario": "tiny"}))
	assert_eq(game.world.get_seed(), 7, "Ohne --seed der des Szenarios:")
	assert_eq(MatchStart.from_args({}).scenario_id, Scenario.DEFAULT, "Ohne --scenario das Standardszenario:")
	var setup := MatchStart.from_args({"setup": "barracks", "seed": "3"})
	assert_eq([setup.kind, setup.setup_name], [MatchStart.Kind.SETUP, "barracks"], "--setup:")
	var save := MatchStart.from_args({"load": "a.sav", "setup": "barracks"})
	assert_eq([save.kind, save.save_path], [MatchStart.Kind.SAVE, "a.sav"], "--load geht vor:")


func test_typed_seed_gives_that_map() -> void:
	var game := _new_match()
	assert_eq(MatchStart.seed_error(" 42 "), "", "Gültiger Seed:")
	assert_eq(game.start(MatchStart.from_seed_text("tiny_random", " 42 ")), "", "Fehler beim Start:")
	assert_eq(game.world.get_seed(), 42, "Seed:")
	assert_eq(game.world.map.to_data(), MapGenerator.generate(42, 20, 16).to_data(), "Karte:")
	assert_eq(MatchStart.seed_error("4294967295"), "", "Größter Seed:")


func test_empty_seed_gives_a_random_map() -> void:
	var game := _new_match()
	assert_eq(MatchStart.seed_error(""), "", "Leer heißt zufällig:")
	game.start(MatchStart.from_seed_text("tiny_random", ""))
	var first := game.world.get_seed()
	game.start(MatchStart.from_seed_text("tiny_random", "  "))
	assert_false(game.world.get_seed() == first, "Zweimal zufällig sollte zwei Karten geben")


func test_invalid_seed_is_rejected() -> void:
	for text: String in ["abc", "-1", "1.5", "12 34", "1e5", "4294967296", "99999999999999999999"]:
		assert_false(MatchStart.seed_error(text) == "", "„%s“ sollte abgewiesen werden" % text)
	assert_true(MatchStart.seed_error("abc").contains("Seed"), "Grund nennt den Seed: " + MatchStart.seed_error("abc"))
