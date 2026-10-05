extends TestCase
## Prüft tools/presets.json; ob jedes Preset fehlerfrei startet, prüft der Rauchtest.


func test_presets_are_valid() -> void:
	assert_eq(Presets.error(), "")
	assert_true(Presets.load_all().size() > 0, "Keine Presets")


func test_setups_exist_and_create_a_world() -> void:
	for id in Presets.load_all():
		for arg in Presets.args_of(id):
			if arg.begins_with("--setup="):
				var path := Presets.setup_path(arg.trim_prefix("--setup="))
				assert_true(ResourceLoader.exists(path), "%s: %s fehlt" % [id, path])
				var setup: GDScript = load(path)
				assert_true(setup.call("create") is GameWorld, "%s: %s liefert keine Spielwelt" % [id, path])


func test_unknown_preset_has_no_args() -> void:
	assert_eq(Presets.args_of("gibt_es_nicht").size(), 0)


func test_without_saves_parameter_the_game_saves_to_the_user_folder() -> void:
	var path := Presets.save_games_for({}).path_for(SaveGame.Kind.QUICK)
	assert_true(path.begins_with(SaveGames.DIR), "Ordner: " + path)


func test_demo_saves_live_in_a_throwaway_folder() -> void:
	var saves := Presets.save_games_for({"saves": "demo"})
	var path := saves.path_for(SaveGame.Kind.QUICK)
	assert_false(path.begins_with(SaveGames.DIR), "Nicht im Nutzerordner: " + path)
	var kinds: Array[SaveGame.Kind] = []
	var outdated := 0
	for save in saves.list():
		kinds.append(save.kind)
		if save.is_outdated():
			outdated += 1
	for kind: SaveGame.Kind in [SaveGame.Kind.NAMED, SaveGame.Kind.QUICK, SaveGame.Kind.AUTO]:
		assert_true(kinds.has(kind), "Art %d fehlt" % kind)
	assert_eq(outdated, 1, "Veraltete Spielstände:")
	assert_false(saves.newest_loadable() == null, "Ein ladbarer Spielstand fehlt")


func test_empty_saves_parameter_gives_an_empty_throwaway_folder() -> void:
	var saves := Presets.save_games_for({"saves": "empty"})
	assert_false(saves.path_for(SaveGame.Kind.QUICK).begins_with(SaveGames.DIR), "Nicht im Nutzerordner")
	assert_eq(saves.list().size(), 0, "Spielstände:")


func test_presets_and_screenshots_never_save_to_the_user_folder() -> void:
	for args: Dictionary in [{"preset": "workers"}, {"screenshot": "bild.png", "days": "3"}]:
		var saves := Presets.save_games_for(args)
		assert_false(saves.path_for(SaveGame.Kind.AUTO).begins_with(SaveGames.DIR), "Nicht im Nutzerordner: %s" % args)
		assert_eq(saves.list().size(), 0, "Leer bei %s:" % args)
