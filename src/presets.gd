class_name Presets
extends RefCounted
## Benannte Testzustände aus tools/presets.json: ID → {"name": Anzeigename, "args": Startparameter}.
## Gestartet mit --preset=id (tools/run.sh id), im Editor über das Menü „Testzustand“
## (addons/presets) und im Rauchtest (tools/smoke.sh) alle der Reihe nach.
## Aufbauten, die Startparameter nicht schaffen, liegen als tests/setups/<name>.gd (--setup=name).

const PATH := "res://tools/presets.json"
const SETUP_DIR := "res://tests/setups/"
## Umgebungsvariable, über die der Editor dem gestarteten Spiel den Testzustand nennt.
const ENV := "BURGWACHT_PRESET"


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
