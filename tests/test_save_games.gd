extends TestCase
## Spielstand-Modul (SaveGames) mit einem Wegwerf-Ordner: speichern, auflisten, laden, löschen.

const PresetSaves := preload("res://tests/preset_saves.gd")

## Wird beim Freigeben samt Inhalt gelöscht.
var _temp: DirAccess


func _store() -> SaveGames:
	_temp = DirAccess.create_temp("burgwacht_saves", false)
	return SaveGames.new(_temp.get_current_dir())


## Ein fester Zeitpunkt (Unix-Sekunden), damit Datum und Sortierung prüfbar sind.
func _at(store: SaveGames, time: float) -> SaveGames:
	store.now = func() -> float: return time
	return store


func test_saved_game_is_listed_with_its_header() -> void:
	var store := _at(_store(), 1_700_000_000.0)
	var world := run_scenario_with_seed("tiny", GameWorld.TICKS_PER_DAY * 2 + 13, 99)
	assert_eq(store.save(world, "Winzig", SaveGame.Kind.NAMED, "Meine Burg"), "", "Speichern:")
	var saves := store.list()
	assert_eq(saves.size(), 1, "Spielstände:")
	var save := saves[0]
	assert_eq(save.name, "Meine Burg", "Name:")
	assert_eq(save.kind, SaveGame.Kind.NAMED, "Art:")
	assert_eq(save.scenario_id, "tiny", "Szenario-ID:")
	assert_eq(save.scenario_title, "Winzig", "Szenario-Name:")
	assert_eq(save.world_seed, 99, "Seed:")
	assert_eq(save.day, 3, "Tag:")
	assert_eq(save.saved_at, 1_700_000_000.0, "Speicherdatum:")
	assert_false(save.is_outdated(), "Veraltet:")
	assert_eq(save.error, "", "Fehler:")


func test_loaded_game_has_same_state_and_continues_the_same() -> void:
	var store := _store()
	var original := run_scenario_with_seed("tiny", GameWorld.TICKS_PER_DAY * 2 + 13, 99)
	assert_eq(store.save(original, "Winzig", SaveGame.Kind.NAMED, "Meine Burg"), "", "Speichern:")
	var loaded := SaveGames.read(store.list()[0].path)
	assert_eq(loaded.error, "", "Fehler beim Laden:")
	assert_eq(loaded.name, "Meine Burg", "Name:")
	assert_eq(world_snapshot(loaded.world), world_snapshot(original), "Zustand nach dem Laden:")
	for i in GameWorld.TICKS_PER_DAY * 2:
		original.step()
		loaded.world.step()
	assert_eq(loaded.world.to_data(), original.to_data(), "Daten nach zwei weiteren Tagen:")


func test_quick_and_auto_save_have_fixed_names_and_are_overwritten() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	store.save(world, "Winzig", SaveGame.Kind.QUICK)
	store.save(world, "Winzig", SaveGame.Kind.AUTO)
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	assert_eq(store.save(world, "Winzig", SaveGame.Kind.QUICK), "", "Erneut schnell speichern:")
	var saves := store.list()
	assert_eq(saves.size(), 2, "Je ein Schnell- und Autospielstand:")
	var quick := SaveGames.read(store.path_for(SaveGame.Kind.QUICK))
	assert_eq(quick.kind, SaveGame.Kind.QUICK, "Art:")
	assert_eq(quick.name, "Schnellspielstand", "Name:")
	assert_eq(quick.day, 2, "Der zweite Schnellspielstand ersetzt den ersten:")
	assert_eq(quick.world.get_day(), 2, "Tag der Spielwelt:")
	var auto := SaveGames.read(store.path_for(SaveGame.Kind.AUTO))
	assert_eq([auto.kind, auto.name, auto.day], [SaveGame.Kind.AUTO, "Autospielstand", 1], "Autospielstand:")


func test_list_is_sorted_newest_first() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	_at(store, 200.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Mitte")
	_at(store, 300.0).save(world, "Winzig", SaveGame.Kind.QUICK)
	_at(store, 100.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Alt")
	var names: Array[String] = []
	for save in store.list():
		names.append(save.name)
	assert_eq(names, ["Schnellspielstand", "Mitte", "Alt"] as Array[String], "Reihenfolge:")
	assert_eq(store.newest_loadable().name, "Schnellspielstand", "Neuester Spielstand:")


func test_empty_folder_has_no_saves() -> void:
	var store := _store()
	assert_eq(store.list().size(), 0, "Spielstände:")
	assert_eq(store.newest_loadable(), null, "Neuester Spielstand:")
	assert_false(store.is_name_taken("Meine Burg"), "Name belegt:")
	assert_eq(SaveGames.read(store.path_for(SaveGame.Kind.QUICK)).error, "Spielstand nicht gefunden", "Schnellladen:")


func test_folder_that_does_not_exist_yet_has_no_saves_and_is_created_on_save() -> void:
	var store := _store()
	var nested := SaveGames.new(_temp.get_current_dir() + "/saves")
	assert_eq(nested.list().size(), 0, "Spielstände:")
	assert_eq(nested.save(run_scenario("tiny", 10), "Winzig", SaveGame.Kind.QUICK), "", "Speichern:")
	assert_eq(nested.list().size(), 1, "Spielstände danach:")
	assert_eq(store.list().size(), 0, "Im übergeordneten Ordner:")


func test_name_is_taken_regardless_of_case_and_saving_again_overwrites() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	store.save(world, "Winzig", SaveGame.Kind.NAMED, "Burg: Nord/Süd")
	assert_true(store.is_name_taken("Burg: Nord/Süd"), "Gleicher Name:")
	assert_true(store.is_name_taken("burg: nord/süd"), "Andere Schreibung:")
	assert_false(store.is_name_taken("Burg Nord"), "Anderer Name:")
	assert_false(store.is_name_taken("Schnellspielstand"), "Name des Schnellspielstands ist frei:")
	store.save(world, "Winzig", SaveGame.Kind.NAMED, "burg: nord/süd")
	var saves := store.list()
	assert_eq(saves.size(), 1, "Überschrieben statt doppelt:")
	assert_eq(saves[0].name, "burg: nord/süd", "Name des neuen Spielstands:")


func test_named_save_needs_a_name() -> void:
	var store := _store()
	assert_eq(store.save(run_scenario("tiny", 10), "Winzig", SaveGame.Kind.NAMED, "  "), "Der Spielstand braucht einen Namen")
	assert_eq(store.list().size(), 0, "Spielstände:")


func test_delete_removes_save() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	_at(store, 100.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Alt")
	_at(store, 200.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Neu")
	assert_eq(store.delete(store.list()[0]), "", "Löschen:")
	var saves := store.list()
	assert_eq(saves.size(), 1, "Spielstände:")
	assert_eq(saves[0].name, "Alt", "Übrig:")
	assert_false(store.is_name_taken("Neu"), "Name wieder frei:")
	assert_eq(store.newest_loadable().name, "Alt", "Neuester Spielstand:")


func test_outdated_saves_are_listed_but_not_loaded() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	_at(store, 300.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Alte Datei")
	_at(store, 200.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Alte Welt")
	_at(store, 100.0).save(world, "Winzig", SaveGame.Kind.NAMED, "Aktuell")
	PresetSaves.rewrite_header(store.path_for(SaveGame.Kind.NAMED, "Alte Datei"), {"format": SaveGames.FORMAT_VERSION - 1})
	PresetSaves.rewrite_header(store.path_for(SaveGame.Kind.NAMED, "Alte Welt"), {"world_version": GameWorld.SAVE_VERSION - 1})
	var saves := store.list()
	assert_eq(saves.size(), 3, "Spielstände:")
	for i in 2:
		assert_eq(saves[i].name, ["Alte Datei", "Alte Welt"][i], "Name des veralteten Spielstands:")
		assert_true(saves[i].is_outdated(), "%s veraltet:" % saves[i].name)
		assert_false(saves[i].is_loadable(), "%s ladbar:" % saves[i].name)
		var loaded := SaveGames.read(saves[i].path)
		assert_eq(loaded.error, "Spielstand stammt aus einer früheren Spielversion", "Laden von %s:" % saves[i].name)
		assert_eq(loaded.world, null, "Spielwelt von %s:" % saves[i].name)
	assert_eq(store.newest_loadable().name, "Aktuell", "Neuester ladbarer Spielstand:")
	assert_eq(store.delete(saves[0]), "", "Veraltete lassen sich löschen:")
	assert_eq(store.list().size(), 2, "Spielstände nach dem Löschen:")


func test_corrupt_files_give_a_message_instead_of_a_crash() -> void:
	var store := _store()
	var world := run_scenario("tiny", 10)
	store.save(world, "Winzig", SaveGame.Kind.QUICK)
	var good := FileAccess.get_file_as_bytes(store.path_for(SaveGame.Kind.QUICK))
	var dir := _temp.get_current_dir() + "/"
	var flipped := good.duplicate()
	flipped[flipped.size() - 5] ^= 0xFF
	var corrupt: Dictionary[String, PackedByteArray] = {
		"leer": PackedByteArray(),
		"text": "kein Spielstand".to_utf8_buffer(),
		"nur_kennung": SaveGames.MAGIC.to_utf8_buffer(),
		"abgeschnitten": good.slice(0, good.size() - 10),
		"verfälscht": flipped,
	}
	for file_name in corrupt:
		var file := FileAccess.open(dir + file_name + SaveGames.EXTENSION, FileAccess.WRITE)
		file.store_buffer(corrupt[file_name])
		file.close()
	assert_eq(store.list().size(), 6, "Beschädigte werden mit gelistet:")
	for file_name in corrupt:
		var loaded := SaveGames.read(dir + file_name + SaveGames.EXTENSION)
		assert_eq(loaded.error, "Spielstand ist beschädigt", "%s:" % file_name)
		assert_eq(loaded.world, null, "Spielwelt von %s:" % file_name)
	assert_eq(store.newest_loadable().kind, SaveGame.Kind.QUICK, "Neuester ladbarer Spielstand:")
