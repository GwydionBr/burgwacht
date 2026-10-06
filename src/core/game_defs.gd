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


## Pfad des Bilds eines Eintrags; leer ohne „sprite“. Die Variante wird modulo „sprite_variants“ gewählt.
static func sprite_path(entry: Dictionary, variant: int = 0) -> String:
	return _sprite_file(entry, "", variant)


## Pfad des Schattenbilds derselben Variante; leer ohne „sprite“.
static func shadow_path(entry: Dictionary, variant: int = 0) -> String:
	return _sprite_file(entry, SHADOW_SUFFIX, variant)


## Pfad eines Animationsbilds für Bewegungszustand, Blickrichtung und Einzelbild; leer ohne „sprite“.
static func animation_path(entry: Dictionary, animation: String, direction: int, frame: int) -> String:
	return SPRITE_DIR + str(entry["sprite"]) + "_%s_%d_%d.png" % [animation, direction, frame] if entry.has("sprite") else ""


## Pfad zu „sprite“ eines Eintrags mit angehängtem Suffix und Endung; leer ohne „sprite“.
static func _sprite_file(entry: Dictionary, suffix: String, variant: int) -> String:
	var index := posmod(variant, int(entry.get("sprite_variants", 1)))
	var variant_suffix := "_%d" % index if index > 0 else ""
	return SPRITE_DIR + str(entry["sprite"]) + variant_suffix + suffix + ".png" if entry.has("sprite") else ""


## Prüft das Feld "sprite" aller Einträge (ID → Dictionary) einer Datendatei: ein Text ohne Endung,
## Bild und Schatten vorhanden. Leer, wenn alles stimmt; sonst der Grund mit Datei und Eintrag.
static func sprites_error(file_name: String, entries: Dictionary) -> String:
	for id: String in entries:
		var entry: Variant = entries[id]
		if not entry is Dictionary or not (entry as Dictionary).has("sprite"):
			continue
		if file_name == "terrain.json" and (entry as Dictionary).has("sprite_transition"):
			var neighbor: Variant = entry["sprite_transition"]
			if not neighbor is String or not entries.has(neighbor) or neighbor == id:
				return "%s, „%s“: „sprite_transition“ muss ein anderes bekanntes Gelände nennen" % [file_name, id]
		var base_reason: String = _sprite_error(entry)
		if base_reason != "":
			return "%s, „%s“: %s" % [file_name, id, base_reason]
		if file_name == "terrain.json":
			var terrain_reason: String = _terrain_sprite_error(entry)
			if terrain_reason != "":
				return "%s, „%s“: %s" % [file_name, id, terrain_reason]
	return ""


static func _terrain_sprite_error(entry: Dictionary) -> String:
	var priority: Variant = entry.get("sprite_priority", 0)
	if not (priority is int or priority is float) or float(priority) < 0 or float(priority) != floor(float(priority)):
		return "„sprite_priority“ muss eine nichtnegative ganze Zahl sein"
	for field: String in ["sprite_overlay", "sprite_edge"]:
		if not entry.has(field):
			continue
		var value: Variant = entry[field]
		if not value is String or str(value) == "" or str(value).ends_with(".png"):
			return "„%s“ muss der Pfad eines Bilds sein (Text, ohne .png)" % field
		var count: int = int(entry.get("sprite_variants", 1)) if field == "sprite_overlay" else 1
		for variant: int in count:
			var path: String = sprite_path({"sprite": value, "sprite_variants": count}, variant)
			if not ResourceLoader.exists(path):
				return "%s %s fehlt" % ["Übergangsbild" if field == "sprite_overlay" else "Erdkantenbild", path]
	return ""


static func _sprite_error(entry: Dictionary) -> String:
	var value: Variant = entry["sprite"]
	if not value is String or str(value) == "" or str(value).ends_with(".png"):
		return SPRITE_TYPE_ERROR
	var count: Variant = entry.get("sprite_variants", 1)
	if not (count is int or count is float) or float(count) < 1 or float(count) != floor(float(count)):
		return "„sprite_variants“ muss eine positive ganze Zahl sein"
	# ResourceLoader statt FileAccess: In der exportierten App liegen nur die importierten Dateien.
	for variant in int(count):
		if not ResourceLoader.exists(sprite_path(entry, variant)):
			return "Bild %s fehlt" % sprite_path(entry, variant)
		if not ResourceLoader.exists(shadow_path(entry, variant)):
			return "Schatten %s fehlt" % shadow_path(entry, variant)
	if entry.has("sprite_walk_height"):
		var floor_height: Variant = entry["sprite_walk_height"]
		if not (floor_height is int or floor_height is float) or not is_finite(float(floor_height)) or float(floor_height) <= 0.0 or float(floor_height) > float(entry.get("height", 0)):
			return "„sprite_walk_height“ muss endlich, positiv und höchstens „height“ sein"
	if bool(entry.get("sprite_connections", false)):
		for direction in 8:
			var arm := "res://assets/sprites/%s_arm_%d.png" % [entry["sprite"], direction]
			if not ResourceLoader.exists(arm):
				return "Mauerarm %s fehlt" % arm
			if not ResourceLoader.exists(arm.trim_suffix(".png") + "_shadow.png"):
				return "Schatten des Mauerarms %s fehlt" % arm
	var reason := _building_animation_error(entry)
	return reason if reason != "" else _animation_error(entry)


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


## Stehen und Gehen sowie jede zusätzliche Animation brauchen acht Richtungen und alle Bilder.
static func _animation_error(entry: Dictionary) -> String:
	if not entry.has("animations"):
		return ""
	var animations: Variant = entry["animations"]
	if not animations is Dictionary:
		return "„animations“ muss Stehen und Gehen beschreiben"
	for required: String in ["idle", "walk"]:
		if not animations.has(required):
			return "Animation „%s“ fehlt" % required
	for animation: String in animations:
		var settings: Variant = animations.get(animation)
		if not settings is Dictionary:
			return "Animation „%s“ fehlt" % animation
		var frames: Variant = settings.get("frames")
		var fps: Variant = settings.get("fps")
		if not (frames is int or frames is float) or float(frames) < 1 or float(frames) != floorf(float(frames)):
			return "Animation „%s“ braucht eine positive ganze Bildanzahl" % animation
		if not (fps is int or fps is float) or float(fps) <= 0:
			return "Animation „%s“ braucht eine positive Bildrate" % animation
		for direction in 8:
			for frame in int(frames):
				var path := animation_path(entry, animation, direction, frame)
				if not ResourceLoader.exists(path):
					return "Animationsbild %s fehlt" % path
	return ""


## Flackernde Gebäudebilder haben keine Blickrichtung; alle Einzelbilder werden geprüft.
static func building_animation_path(entry: Dictionary, frame: int) -> String:
	return SPRITE_DIR + str(entry["sprite"]) + "_flame_%d.png" % frame if entry.has("sprite") else ""


static func _building_animation_error(entry: Dictionary) -> String:
	if not entry.has("sprite_animation"):
		return ""
	var settings: Variant = entry["sprite_animation"]
	if not settings is Dictionary:
		return "„sprite_animation“ muss Bildanzahl und Bildrate beschreiben"
	var frames: Variant = settings.get("frames")
	var fps: Variant = settings.get("fps")
	if not (frames is int or frames is float) or float(frames) < 1 or float(frames) != floorf(float(frames)):
		return "„sprite_animation“ braucht eine positive ganze Bildanzahl"
	if not (fps is int or fps is float) or float(fps) <= 0:
		return "„sprite_animation“ braucht eine positive Bildrate"
	for frame in int(frames):
		var path := building_animation_path(entry, frame)
		if not ResourceLoader.exists(path):
			return "Animationsbild %s fehlt" % path
	return ""
