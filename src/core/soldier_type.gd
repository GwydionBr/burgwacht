class_name SoldierType
extends RefCounted
## Soldatentypen aus data/units.json (Einträge mit "kind": "soldier"): Name, Kampfwerte,
## Gehgeschwindigkeit, Farbe und Anwerbekosten ("cost": Ware → Menge, dazu optional "gold" aus
## dem Schatz – wie die Baukosten der Gebäude).

const KIND := "soldier"


## Die Soldatentypen in Datenreihenfolge.
static func ids() -> Array[String]:
	var result: Array[String] = []
	var units := GameDefs.get_instance().units
	for unit_id: String in units:
		if is_soldier_type(unit_id):
			result.append(unit_id)
	return result


static func is_soldier_type(type_id: String) -> bool:
	var def: Dictionary = GameDefs.get_instance().units.get(type_id, {})
	return def.get("kind", "") == KIND


## Anzeigename, z. B. „Schwertkämpfer“.
static func name_of(type_id: String) -> String:
	return str(_def(type_id)["name"])


## Takte für einen geraden Schritt.
static func ticks_per_tile(type_id: String) -> int:
	return int(_def(type_id)["ticks_per_tile"])


## Kämpft er im Nahkampf ("melee")? Sonst ist er ein Fernkämpfer mit "range".
static func is_melee(type_id: String) -> bool:
	return bool(_def(type_id).get("melee", false))


## Platzhalter-Farbe der Figur.
static func color_of(type_id: String) -> Color:
	return Color(str(_def(type_id)["color"]))


## Anwerbekosten in Waren: Ware → Menge (ohne Gold).
static func goods_cost_of(type_id: String) -> Dictionary[String, int]:
	return GameWorld.goods_in(_def(type_id)["cost"])


## Anwerbekosten in Gold aus dem Schatz (0, wenn keins).
static func gold_cost_of(type_id: String) -> int:
	return GameWorld.gold_in(_def(type_id)["cost"])


## Die Waren, die zum Anwerben irgendeines Soldatentyps gebraucht werden (die Waffen), in der
## Reihenfolge der Soldatentypen.
static func weapons() -> Array[String]:
	var result: Array[String] = []
	for type_id in ids():
		for good: String in goods_cost_of(type_id):
			if not result.has(good):
				result.append(good)
	return result


static func _def(type_id: String) -> Dictionary:
	return GameDefs.get_instance().units[type_id]
