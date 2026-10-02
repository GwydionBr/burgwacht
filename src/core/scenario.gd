class_name Scenario
extends RefCounted
## Ein Szenario: die Datenbeschreibung, aus der eine Partie startet (res://data/scenarios/<id>.json).
## Felder bisher: "name", "map" ({"width", "height"}), "seed" (Zahl oder "random")
## und optional "start_goods" (Ware → Menge, liegt nach der Gründung im ersten Lager ihrer Lagerart)
## sowie "start_residents" (so viele Bewohner stehen nach der Gründung am Lagerfeuer).
## Fehler beim Laden stehen in `error` (leer = gültig), damit der Aufrufer sie anzeigen kann.

const DIR := "res://data/scenarios/"
const DEFAULT := "free_play"
const RANDOM_SEED := "random"

## Dateiname ohne Endung, z. B. "free_play".
var id: String
## Anzeigename, z. B. "Freies Spiel".
var title: String
var map_size: Vector2i
var random_seed: bool
var fixed_seed: int
## Ware → Menge, in der Reihenfolge der Datei.
var start_goods: Dictionary[String, int] = {}
## Bewohner, die bei der Gründung als Untätige am Lagerfeuer entstehen.
var start_residents := 0
var error := ""


static func load_named(scenario_id: String, dir := DIR) -> Scenario:
	var path := dir + scenario_id + ".json"
	if not FileAccess.file_exists(path):
		return _failed(scenario_id, "Szenario „%s“ nicht gefunden (%s)." % [scenario_id, path])
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _failed(scenario_id, "Szenario „%s“ ist kein gültiges JSON (Zeile %d: %s)." % [
				scenario_id, json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary:
		return _failed(scenario_id, "Szenario „%s“ muss ein JSON-Objekt sein." % scenario_id)
	return from_dict(scenario_id, json.data)


static func from_dict(scenario_id: String, data: Dictionary) -> Scenario:
	var scenario := Scenario.new()
	scenario.id = scenario_id
	var problems: PackedStringArray = []

	var title_value: Variant = data.get("name")
	if title_value is String and title_value != "":
		scenario.title = title_value
	else:
		problems.append("„name“ fehlt oder ist kein Text")

	var map_value: Variant = data.get("map")
	var map_dict: Dictionary = map_value if map_value is Dictionary else {}
	var width := _positive_int(map_dict.get("width"))
	var height := _positive_int(map_dict.get("height"))
	if width > 0 and height > 0:
		scenario.map_size = Vector2i(width, height)
	else:
		problems.append("„map“ braucht ganze Zahlen „width“ und „height“ größer als 0")

	var seed_value: Variant = data.get("seed")
	if seed_value is String and seed_value == RANDOM_SEED:
		scenario.random_seed = true
	elif _is_whole_number(seed_value):
		scenario.fixed_seed = int(seed_value)
	else:
		problems.append("„seed“ muss eine ganze Zahl oder \"%s\" sein" % RANDOM_SEED)

	_read_start_goods(scenario, data.get("start_goods", {}), problems)

	var residents_value: Variant = data.get("start_residents", 0)
	if _is_whole_number(residents_value) and int(residents_value) >= 0:
		scenario.start_residents = int(residents_value)
	else:
		problems.append("„start_residents“ muss eine ganze Zahl ab 0 sein")

	if not problems.is_empty():
		scenario.error = "Szenario „%s“ ist ungültig: %s." % [scenario_id, "; ".join(problems)]
	return scenario


## Der Seed für eine neue Partie: der feste aus dem Szenario, sonst random_value.
## Den Zufallswert liefert der Aufrufer, damit der Kern keinen globalen Zufall nutzt (ADR 0001).
func resolve_seed(random_value: int) -> int:
	return random_value if random_seed else fixed_seed


static func _read_start_goods(scenario: Scenario, value: Variant, problems: PackedStringArray) -> void:
	if not value is Dictionary:
		problems.append("„start_goods“ muss ein Objekt Ware → Menge sein")
		return
	var goods := GameDefs.get_instance().goods
	var entries: Dictionary = value
	for good: Variant in entries:
		var amount: Variant = entries[good]
		if not goods.has(good):
			problems.append("„start_goods“ enthält die unbekannte Ware „%s“" % str(good))
		elif not _is_whole_number(amount) or int(amount) < 0:
			problems.append("„start_goods“: Menge für „%s“ muss eine ganze Zahl ab 0 sein" % str(good))
		else:
			scenario.start_goods[str(good)] = int(amount)


static func _failed(scenario_id: String, message: String) -> Scenario:
	var scenario := Scenario.new()
	scenario.id = scenario_id
	scenario.error = message
	return scenario


## JSON kennt nur Kommazahlen; ganze Zahlen kommen als float mit Nachkommateil 0.
static func _is_whole_number(value: Variant) -> bool:
	return (value is float and value == floorf(value)) or value is int


static func _positive_int(value: Variant) -> int:
	return int(value) if _is_whole_number(value) and int(value) > 0 else 0
