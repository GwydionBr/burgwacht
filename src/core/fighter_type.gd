class_name FighterType
extends RefCounted
## Kampfwerte aus data/units.json, gemeinsam für Soldatentypen ("kind": "soldier") und Feinde
## ("kind": "enemy"): Name, Lebenspunkte "hp", Schaden "damage" je Angriff, Angriffsdauer
## "attack_ticks" (Takte zwischen zwei Angriffen), Nahkampf "melee" oder Reichweite "range",
## Sichtweite "sight", Gehgeschwindigkeit "ticks_per_tile" und Farbe der Figur.

const ENEMY_KIND := "enemy"


## Die Feindtypen in Datenreihenfolge.
static func enemy_ids() -> Array[String]:
	return ids_of_kind(ENEMY_KIND)


static func is_enemy_type(type_id: String) -> bool:
	return is_kind(type_id, ENEMY_KIND)


## Die Einträge aus units.json mit diesem "kind" (z. B. "enemy", SoldierType.KIND) in
## Datenreihenfolge.
static func ids_of_kind(kind: String) -> Array[String]:
	var result: Array[String] = []
	for unit_id: String in GameDefs.get_instance().units:
		if is_kind(unit_id, kind):
			result.append(unit_id)
	return result


## Hat der Eintrag type_id aus units.json dieses "kind"? false für unbekannte.
static func is_kind(type_id: String, kind: String) -> bool:
	var def: Dictionary = GameDefs.get_instance().units.get(type_id, {})
	return def.get("kind", "") == kind


## Anzeigename, z. B. „Schwertkämpfer“ oder „Räuber“.
static func name_of(type_id: String) -> String:
	return str(_def(type_id)["name"])


## Lebenspunkte bei voller Gesundheit.
static func max_hp(type_id: String) -> int:
	return int(_def(type_id)["hp"])


## Schaden je Angriff.
static func damage_of(type_id: String) -> int:
	return int(_def(type_id)["damage"])


## Takte zwischen zwei Angriffen.
static func attack_ticks(type_id: String) -> int:
	return int(_def(type_id)["attack_ticks"])


## Kämpft er im Nahkampf ("melee")? Sonst ist er ein Fernkämpfer mit "range".
static func is_melee(type_id: String) -> bool:
	return bool(_def(type_id).get("melee", false))


## Reichweite eines Fernkämpfers in Kacheln (Abstand der Kachelmitten); 0 im Nahkampf.
static func range_of(type_id: String) -> int:
	return int(_def(type_id).get("range", 0))


## Wie weit er Gegner sieht, in Kacheln (Abstand der Kachelmitten).
static func sight_of(type_id: String) -> int:
	return int(_def(type_id)["sight"])


## Takte für einen geraden Schritt.
static func ticks_per_tile(type_id: String) -> int:
	return int(_def(type_id)["ticks_per_tile"])


## Platzhalter-Farbe der Figur.
static func color_of(type_id: String) -> Color:
	return Color(str(_def(type_id)["color"]))


static func _def(type_id: String) -> Dictionary:
	return GameDefs.get_instance().units[type_id]
