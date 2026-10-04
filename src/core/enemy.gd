class_name Enemy
extends Figure
## Ein Feind, z. B. der Räuber: gehört nicht zur Burg und ist kein Bewohner. Typ und Kampfwerte
## aus units.json ("kind": "enemy", FighterType); Bewegung und Kampfzustand: Figure.
## Er läuft zum Bergfried und greift Soldaten in Sichtweite an, die er erreichen kann; am
## Bergfried greift er diesen an.

## Feindtyp aus units.json, z. B. "bandit".
var type: String
## Nummer der Welle, mit der er kam (ab 1); 0 bei Startfeinden und Feinden per Debug-Befehl.
var wave := 0
## Das Gebäude, das er gerade angreift (0 = keines); eigene IDs, getrennt von target_id
## (Bewohner).
var target_building_id := 0


static func create(enemy_id: int, type_id: String, start_tile: Vector2i, wave_number := 0) -> Enemy:
	var enemy := Enemy.new()
	enemy.id = enemy_id
	enemy.type = type_id
	enemy.wave = wave_number
	enemy.tile = start_tile
	enemy.hp = FighterType.max_hp(type_id)
	return enemy


func straight_step_ticks() -> int:
	return FighterType.ticks_per_tile(type)


func fighter_type() -> String:
	return type


func report_hit(combat: Combat) -> void:
	combat.enemy_hit(self)


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	var data := _figure_data()
	data["type"] = type
	data["wave"] = wave
	data["target_building_id"] = target_building_id
	return data


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Enemy:
	var enemy := Enemy.new()
	enemy._read_figure_data(data)
	enemy.type = str(data["type"])
	enemy.wave = int(data["wave"])
	enemy.target_building_id = int(data["target_building_id"])
	return enemy
