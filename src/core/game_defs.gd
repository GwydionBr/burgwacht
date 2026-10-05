class_name GameDefs
extends RefCounted
## Spielinhalte (Gelände, Vorkommen, Waren, Gebäude, Kategorien der Bauleiste, Einheiten, Bevölkerung, Markt) aus den JSON-Dateien in res://data.
## Neue Inhalte werden dort eingetragen, nicht im Code. Gelände, Vorkommen, Gebäude und Einheiten
## dürfen ein Feld "sprite" haben (Bild samt Schatten); es wird beim Laden geprüft, ein Fehler steht
## dann in `error` und wird als Fehler gemeldet.

const DATA_DIR := "res://data/"
## Sprites stehen in den Daten ("sprite") relativ zu diesem Ordner und ohne Endung; der Schatten
## liegt daneben mit SHADOW_SUFFIX (gerendert mit tools/render.sh).
const SPRITE_DIR := "res://assets/sprites/"
const SHADOW_SUFFIX := "_shadow"
const SPRITE_TYPE_ERROR := "„sprite“ muss der Pfad eines Bilds sein (Text, ohne .png)"

static var _instance: GameDefs

var terrain: Dictionary = {}
var deposits: Dictionary = {}
var goods: Dictionary = {}
var buildings: Dictionary = {}
## Kategorien der Bauleiste in Anzeigereihenfolge: ID → Name; jedes baubare Gebäude nennt eine ("category").
var build_categories: Dictionary = {}
## Einheiten (bisher nur der Bewohner): Gehgeschwindigkeit, Wartezeit, Platzhalter-Farbe.
var units: Dictionary = {}
## Regelwerte der Bevölkerung: Rationsstufen, Faktoren, Voreinstellungen.
var population: Dictionary = {}
## Regelwerte des Markts: Einheiten je Handel.
var market: Dictionary = {}
## Leer, wenn die Spieldaten gültig sind; sonst der Grund.
var error := ""


static func get_instance() -> GameDefs:
	if _instance == null:
		_instance = GameDefs.new()
		_instance.terrain = _load_json("terrain.json")
		_instance.deposits = _load_json("deposits.json")
		_instance.goods = _load_json("goods.json")
		_instance.buildings = _load_json("buildings.json")
		_instance.build_categories = _load_json("build_categories.json")
		_instance.units = _load_json("units.json")
		_instance.population = _load_json("population.json")
		_instance.market = _load_json("market.json")
		_instance.error = _instance._sprites_error()
		if _instance.error != "":
			push_error("Spieldaten: " + _instance.error)
	return _instance


## Pfad des Bilds eines Eintrags (Gelände, Vorkommen, Gebäude, Einheit); leer ohne "sprite".
static func sprite_path(entry: Dictionary) -> String:
	return _sprite_file(entry, "")


## Pfad des Schattenbilds eines Eintrags; leer ohne "sprite".
static func shadow_path(entry: Dictionary) -> String:
	return _sprite_file(entry, SHADOW_SUFFIX)


## Pfad zu "sprite" eines Eintrags mit angehängtem Suffix und Endung; leer ohne "sprite".
static func _sprite_file(entry: Dictionary, suffix: String) -> String:
	return SPRITE_DIR + str(entry["sprite"]) + suffix + ".png" if entry.has("sprite") else ""


## Prüft das Feld "sprite" aller Einträge (ID → Dictionary) einer Datendatei: ein Text ohne Endung,
## Bild und Schatten vorhanden. Leer, wenn alles stimmt; sonst der Grund mit Datei und Eintrag.
static func sprites_error(file_name: String, entries: Dictionary) -> String:
	for id: String in entries:
		var entry: Variant = entries[id]
		if not entry is Dictionary or not (entry as Dictionary).has("sprite"):
			continue
		var reason := _sprite_error(entry)
		if reason != "":
			return "%s, „%s“: %s" % [file_name, id, reason]
	return ""


static func _sprite_error(entry: Dictionary) -> String:
	var value: Variant = entry["sprite"]
	if not value is String or str(value) == "" or str(value).ends_with(".png"):
		return SPRITE_TYPE_ERROR
	# ResourceLoader statt FileAccess: In der exportierten App liegen nur die importierten Dateien.
	if not ResourceLoader.exists(sprite_path(entry)):
		return "Bild %s fehlt" % sprite_path(entry)
	if not ResourceLoader.exists(shadow_path(entry)):
		return "Schatten %s fehlt" % shadow_path(entry)
	return ""


## Prüft die Datendateien, deren Einträge ein Feld "sprite" haben dürfen, in dieser Reihenfolge;
## der erste Fehler gewinnt.
func _sprites_error() -> String:
	var sections: Dictionary[String, Dictionary] = {
		"terrain.json": terrain,
		"deposits.json": deposits,
		"buildings.json": buildings,
		"units.json": units,
	}
	for file_name: String in sections:
		var reason := sprites_error(file_name, sections[file_name])
		if reason != "":
			return reason
	return ""


static func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Ungültige Datendatei: %s" % path)
	return parsed
