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
