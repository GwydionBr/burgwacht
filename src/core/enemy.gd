class_name Enemy
extends Unit
## Ein Feind, z. B. der Räuber: gehört nicht zur Burg und ist kein Bewohner. Typ und Kampfwerte
## aus units.json ("kind": "enemy", FighterType); Bewegung und Kampfzustand: Unit.
## Er läuft zum Bergfried und greift Soldaten in Sichtweite an, die er erreichen kann.

## Feindtyp aus units.json, z. B. "bandit".
var type: String


static func create(enemy_id: int, type_id: String, start_tile: Vector2i) -> Enemy:
	var enemy := Enemy.new()
	enemy.id = enemy_id
	enemy.type = type_id
	enemy.tile = start_tile
	enemy.hp = FighterType.max_hp(type_id)
	return enemy


func straight_step_ticks() -> int:
	return FighterType.ticks_per_tile(type)


func fighter_type() -> String:
	return type


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	var data := _unit_data()
	data["type"] = type
	return data


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Enemy:
	var enemy := Enemy.new()
	enemy._read_unit_data(data)
	enemy.type = str(data["type"])
	return enemy
