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
	var saved := run_scenario("tiny_three", 30)
	var path := _write_save(saved.to_data())
	var game := _new_match()
	game.start(MatchStart.from_scenario("tiny"))
	assert_eq(game.start(MatchStart.from_save(path)), "", "Fehler beim Laden:")
	DirAccess.remove_absolute(path)
	assert_eq(world_snapshot(game.world), world_snapshot(saved), "Spielwelt:")
	assert_eq(game.scenario.id, "tiny_three", "Szenario nach dem Laden:")


## Schreibt Daten wie ein Spielstand in eine Wegwerf-Datei und nennt ihren Pfad.
func _write_save(data: Variant) -> String:
	var path := OS.get_temp_dir().path_join("burgwacht_test_match.sav")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(data)
	file.close()
	return path


func test_damaged_save_gives_a_message_and_keeps_the_world() -> void:
	var game := _new_match()
	game.start(MatchStart.from_scenario("tiny"))
	var before := game.world
	var path := _write_save("kein Spielstand")
	assert_eq(game.start(MatchStart.from_save(path)), "Spielstand ist beschädigt", "Grund:")
	DirAccess.remove_absolute(path)
	assert_true(game.world == before, "Spielwelt sollte bleiben")
	assert_false(game.start(MatchStart.from_save(path)) == "", "Fehlende Datei sollte nicht laden")


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
