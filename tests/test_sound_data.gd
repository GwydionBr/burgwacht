extends TestCase
## Die Geräuschdatei (SoundData, data/sounds.json): Geräuschanlässe mit Varianten, Grundlautstärke
## und Ortsabhängigkeit sowie die Musikstücke nach Rolle; Fehler als deutscher Text in `error`.


func test_game_data_is_valid() -> void:
	var data := SoundData.load_file()
	assert_eq(data.error, "", "Fehler der Geräuschdatei:")
	assert_eq(data.variant_count("button"), 3, "Varianten des Knopfs:")
	assert_eq(data.file_of("trade", 0), "res://assets/audio/sounds/trade/trade_1.ogg", "erste Variante des Handels:")


## Die Geräuschdatei der Spieldaten als rohe Daten, zum Verändern in den Fehlerfällen.
func _raw() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SoundData.PATH))


func test_unknown_occasion_is_named() -> void:
	var raw := _raw()
	raw["sounds"]["trumpet"] = raw["sounds"]["button"]
	assert_eq(SoundData.from_dict(raw).error, "Unbekannter Geräuschanlass „trumpet“", "Fehler:")


func test_missing_sound_file_is_named() -> void:
	var raw := _raw()
	raw["sounds"]["trade"]["files"].append("sounds/trade/trade_9.ogg")
	assert_eq(SoundData.from_dict(raw).error,
			"Geräuschanlass „trade“: Tondatei res://assets/audio/sounds/trade/trade_9.ogg fehlt", "Fehler:")


func test_wrong_types_are_named() -> void:
	var cases := {
		"volume": ["laut", "Geräuschanlass „button“: „volume“ muss eine Zahl über 0 sein"],
		"positional": ["ja", "Geräuschanlass „button“: „positional“ muss true oder false sein"],
		"vary_pitch": ["nein", "Geräuschanlass „button“: „vary_pitch“ muss true oder false sein"],
		"group": ["menu", "Geräuschanlass „button“: „group“ muss „control“, „game“ oder „match“ sein"],
		"files": ["sounds/button/button_1.ogg", "Geräuschanlass „button“: „files“ muss eine nicht leere Liste von Tondateien sein"],
	}
	for key: String in cases:
		var raw := _raw()
		raw["sounds"]["button"][key] = cases[key][0]
		assert_eq(SoundData.from_dict(raw).error, cases[key][1], "Fehler bei „%s“:" % key)
	var empty := _raw()
	empty["sounds"]["button"]["files"] = []
	assert_eq(SoundData.from_dict(empty).error, cases["files"][1], "Fehler bei leerer Liste:")
	var pitch := _raw()
	pitch["pitch_variation"] = "viel"
	assert_eq(SoundData.from_dict(pitch).error, "„pitch_variation“ muss eine Zahl von 0 bis unter 1 sein", "Fehler bei der Tonhöhe:")
	var sounds := _raw()
	sounds["sounds"] = []
	assert_eq(SoundData.from_dict(sounds).error, "„sounds“ muss ein Objekt mit den Geräuschanlässen sein", "Fehler bei „sounds“:")


func test_music_lists_pieces_by_role() -> void:
	var data := SoundData.load_file()
	assert_eq(data.music_of("menu"), ["res://assets/audio/music/menu/exploration.ogg"] as Array[String], "Menümusik:")
	assert_eq(data.music_of("peaceful").size(), 5, "friedliche Musikstücke:")
	var unknown := _raw()
	unknown["music"]["victory"] = unknown["music"]["battle"]
	assert_eq(SoundData.from_dict(unknown).error, "Unbekannte Musikrolle „victory“", "Fehler bei unbekannter Rolle:")
	var missing := _raw()
	missing["music"]["battle"] = ["music/battle/siege.ogg"]
	assert_eq(SoundData.from_dict(missing).error,
			"Musikrolle „battle“: Tondatei res://assets/audio/music/battle/siege.ogg fehlt", "Fehler bei fehlender Datei:")


func test_missing_occasion_is_named() -> void:
	var raw := _raw()
	raw["sounds"].erase("defeat")
	assert_eq(SoundData.from_dict(raw).error, "Geräuschanlass „defeat“ fehlt", "Fehler:")
