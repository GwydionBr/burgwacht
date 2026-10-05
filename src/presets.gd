class_name Presets
extends RefCounted
## Benannte Testzustände aus tools/presets.json: ID → {"name": Anzeigename, "args": Startparameter}.
## Gestartet mit --preset=id (tools/run.sh id), im Editor über das Menü „Testzustand“
## (addons/presets) und im Rauchtest (tools/smoke.sh) alle der Reihe nach.
## Aufbauten, die Startparameter nicht schaffen, liegen als tests/setups/<name>.gd (--setup=name).

const PATH := "res://tools/presets.json"
const SETUP_DIR := "res://tests/setups/"
## Füllt den Wegwerf-Ordner für --saves=demo mit Spielständen.
const DEMO_SAVES_PATH := "res://tests/preset_saves.gd"
## Umgebungsvariable, über die der Editor dem gestarteten Spiel den Testzustand nennt.
const ENV := "BURGWACHT_PRESET"

## Die Spielstände dieses Spiels (siehe save_games()); Hauptmenü und Partie teilen sie.
static var _save_games: SaveGames
## Wegwerf-Ordner; sie leben bis zum Ende des Spiels und werden dann samt Inhalt gelöscht.
static var _temp_dirs: Array[DirAccess] = []


## Alle Presets in der Reihenfolge der Datei; bei Fehlern leer (Grund über error()).
static func load_all() -> Dictionary[String, Dictionary]:
	var presets: Dictionary[String, Dictionary] = {}
	if error() != "":
		return presets
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for id: String in data:
		presets[id] = data[id]
	return presets


## Warum die Datei nicht passt, leer = in Ordnung.
static func error() -> String:
	if not FileAccess.file_exists(PATH):
		return "%s fehlt" % PATH
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return "%s ist kein JSON-Objekt" % PATH
	for id: Variant in data:
		var preset: Variant = data[id]
		if not preset is Dictionary or not preset.get("name") is String or not preset.get("args") is Array:
			return "Preset „%s“ braucht „name“ (Text) und „args“ (Liste)" % id
		for arg: Variant in preset["args"]:
			if not arg is String or not str(arg).begins_with("--"):
				return "Preset „%s“: Startparameter beginnen mit -- (%s)" % [id, str(arg)]
	return ""


## Startparameter des Presets, leer wenn es fehlt.
static func args_of(id: String) -> PackedStringArray:
	var args: PackedStringArray = []
	for arg: String in load_all().get(id, {}).get("args", []):
		args.append(arg)
	return args


## Pfad des Aufbau-Skripts für --setup=name.
static func setup_path(setup_name: String) -> String:
	return SETUP_DIR + setup_name + ".gd"


## Startparameter als Name → Wert; die eines Presets (--preset= oder aus dem Editor über die
## Umgebungsvariable ENV) zuerst, eigene Parameter überschreiben sie.
static func user_args() -> Dictionary:
	var own := _args_to_dict(OS.get_cmdline_user_args())
	var preset := str(own.get("preset", OS.get_environment(ENV)))
	if preset == "":
		return own
	var args := {}
	if error() != "":
		printerr("--preset: ", error())
	elif not load_all().has(preset):
		printerr("--preset: unbekannt: ", preset, " (vorhanden: ", ", ".join(load_all().keys()), ")")
	else:
		args = _args_to_dict(args_of(preset))
	args.merge(own, true)
	return args


## Die Spielstände dieses Spiels nach den Startparametern (siehe save_games_for()), einmal je Lauf.
static func save_games() -> SaveGames:
	if _save_games == null:
		_save_games = save_games_for(user_args())
	return _save_games


## Wo gespeichert wird: im Nutzerordner (user://saves/), mit --saves=demo in einem Wegwerf-Ordner
## mit Spielständen der Testzustände, mit --saves=empty in einem leeren. So schreiben Presets,
## Rauchtest und Screenshots nichts in den Nutzerordner.
static func save_games_for(args: Dictionary) -> SaveGames:
	if not args.has("saves"):
		return SaveGames.new()
	var temp := DirAccess.create_temp("burgwacht_saves", false)
	_temp_dirs.append(temp)
	var saves := SaveGames.new(temp.get_current_dir())
	match str(args["saves"]):
		"demo":
			var demo: GDScript = load(DEMO_SAVES_PATH)
			demo.call("fill", saves)
		"empty":
			pass
		_:
			printerr("--saves: demo oder empty, nicht „%s“" % args["saves"])
	return saves


static func _args_to_dict(list: PackedStringArray) -> Dictionary:
	var args := {}
	for arg in list:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args
