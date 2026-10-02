class_name MapData
extends RefCounted
## Der Spielzustand der Karte: Gelände pro Kachel und Vorkommen.
## Enthält bewusst keine Darstellung – die Views lesen nur daraus.

signal deposit_removed(tile: Vector2i)

var width: int
var height: int
var deposits: Dictionary[Vector2i, Deposit] = {}

var _terrain := PackedStringArray()


func _init(map_width: int, map_height: int, fill_terrain := "grass") -> void:
	width = map_width
	height = map_height
	_terrain.resize(width * height)
	_terrain.fill(fill_terrain)


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


@warning_ignore("integer_division")
func center() -> Vector2i:
	return Vector2i(width / 2, height / 2)


func get_terrain(tile: Vector2i) -> String:
	return _terrain[tile.y * width + tile.x]


func set_terrain(tile: Vector2i, terrain_id: String) -> void:
	_terrain[tile.y * width + tile.x] = terrain_id


func get_deposit(tile: Vector2i) -> Deposit:
	return deposits.get(tile)


func add_deposit(tile: Vector2i, deposit: Deposit) -> void:
	deposits[tile] = deposit


func remove_deposit(tile: Vector2i) -> void:
	if deposits.erase(tile):
		deposit_removed.emit(tile)


func is_walkable(tile: Vector2i) -> bool:
	return in_bounds(tile) and _terrain_def(tile)["walkable"]


func is_buildable(tile: Vector2i) -> bool:
	return in_bounds(tile) and _terrain_def(tile)["buildable"] and not deposits.has(tile)


func _terrain_def(tile: Vector2i) -> Dictionary:
	return GameDefs.get_instance().terrain[get_terrain(tile)]
