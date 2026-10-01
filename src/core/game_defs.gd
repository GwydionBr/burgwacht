class_name GameDefs
extends RefCounted
## Spielinhalte (Gelände, Rohstoffvorkommen, Waren) aus den JSON-Dateien in res://data.
## Neue Inhalte werden dort eingetragen, nicht im Code.

const DATA_DIR := "res://data/"

static var _instance: GameDefs

var terrain: Dictionary = {}
var resource_nodes: Dictionary = {}
var goods: Dictionary = {}


static func get_instance() -> GameDefs:
	if _instance == null:
		_instance = GameDefs.new()
		_instance.terrain = _load_json("terrain.json")
		_instance.resource_nodes = _load_json("resource_nodes.json")
		_instance.goods = _load_json("goods.json")
	return _instance


static func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Ungültige Datendatei: %s" % path)
	return parsed
