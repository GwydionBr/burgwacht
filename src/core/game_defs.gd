class_name GameDefs
extends RefCounted
## Spielinhalte (Gelände, Vorkommen, Waren, Gebäude, Einheiten, Bevölkerung, Markt) aus den JSON-Dateien in res://data.
## Neue Inhalte werden dort eingetragen, nicht im Code.

const DATA_DIR := "res://data/"

static var _instance: GameDefs

var terrain: Dictionary = {}
var deposits: Dictionary = {}
var goods: Dictionary = {}
var buildings: Dictionary = {}
## Einheiten (bisher nur der Bewohner): Gehgeschwindigkeit, Wartezeit, Platzhalter-Farbe.
var units: Dictionary = {}
## Regelwerte der Bevölkerung: Rationsstufen, Faktoren, Voreinstellungen.
var population: Dictionary = {}
## Regelwerte des Markts: Einheiten je Handel.
var market: Dictionary = {}


static func get_instance() -> GameDefs:
	if _instance == null:
		_instance = GameDefs.new()
		_instance.terrain = _load_json("terrain.json")
		_instance.deposits = _load_json("deposits.json")
		_instance.goods = _load_json("goods.json")
		_instance.buildings = _load_json("buildings.json")
		_instance.units = _load_json("units.json")
		_instance.population = _load_json("population.json")
		_instance.market = _load_json("market.json")
	return _instance


static func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Ungültige Datendatei: %s" % path)
	return parsed
