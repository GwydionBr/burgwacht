class_name StartEnemy
extends RefCounted
## Ein Feind, der bei der Gründung erscheint (Szenariofeld "enemies"): Feindtyp und Kachel.

var type_id: String
var tile: Vector2i


static func create(enemy_type: String, enemy_tile: Vector2i) -> StartEnemy:
	var start_enemy := StartEnemy.new()
	start_enemy.type_id = enemy_type
	start_enemy.tile = enemy_tile
	return start_enemy


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"type": type_id, "x": tile.x, "y": tile.y}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> StartEnemy:
	return create(str(data["type"]), Vector2i(int(data["x"]), int(data["y"])))
