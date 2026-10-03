class_name FighterType
extends RefCounted
## Kampfwerte aus data/units.json, gemeinsam für Soldatentypen ("kind": "soldier") und Feinde
## ("kind": "enemy"): Name, Lebenspunkte "hp", Schaden "damage" je Angriff, Angriffsdauer
## "attack_ticks" (Takte zwischen zwei Angriffen), Nahkampf "melee" oder Reichweite "range" (dazu
## auf dem Wehrgang "wall_walk_range_bonus"), Sichtweite "sight", Leine "leash" (wie weit ein
## Nahkämpfer beim selbstständigen Verteidigen vom Posten weg verfolgt), Gehgeschwindigkeit
## "ticks_per_tile" und Farbe der Figur.

const ENEMY_KIND := "enemy"


## Die Feindtypen in Datenreihenfolge.
static func enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for unit_id: String in GameDefs.get_instance().units:
		if is_enemy_type(unit_id):
			result.append(unit_id)
	return result


static func is_enemy_type(type_id: String) -> bool:
	var def: Dictionary = GameDefs.get_instance().units.get(type_id, {})
	return def.get("kind", "") == ENEMY_KIND


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


## Zusätzliche Reichweite eines Fernkämpfers auf dem Wehrgang; 0, wenn keine.
static func wall_walk_range_bonus(type_id: String) -> int:
	return int(_def(type_id).get("wall_walk_range_bonus", 0))


## Wie weit ein Nahkämpfer beim selbstständigen Verteidigen höchstens verfolgt, in Kacheln vom
## Posten (Abstand der Kachelmitten); 0, wenn er dabei nicht losläuft.
static func leash_of(type_id: String) -> int:
	return int(_def(type_id).get("leash", 0))


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
