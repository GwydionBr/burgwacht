class_name WallSprites
extends RefCounted
## Zusammengesetzte Mauerbilder: Mittelpfeiler und Arme zu allen acht Wehrgangnachbarn.

## Reihenfolge der Armdateien, beginnend mit Kachel-x, im Uhrzeigersinn in Kachelkoordinaten.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


## Bildpfade für Karte und Bauvorschau; neighbors enthält Wehrgangkacheln, keine Gebäudeursprünge.
static func paths(entry: Dictionary, origin: Vector2i, neighbors: Array[Vector2i]) -> Array[String]:
	if bool(entry.get("sprite_ramp", false)):
		for direction in DIRECTIONS.size():
			if neighbors.has(origin + DIRECTIONS[direction]):
				return [GameDefs.sprite_path(entry, direction)]
		return [GameDefs.sprite_path(entry)]
	var result: Array[String] = [GameDefs.sprite_path(entry, BuildingSprites.variant(origin, int(entry.get("sprite_variants", 1))))]
	if bool(entry.get("sprite_connections", false)):
		for direction in DIRECTIONS.size():
			if neighbors.has(origin + DIRECTIONS[direction]):
				result.append("res://assets/sprites/%s_arm_%d.png" % [entry["sprite"], direction])
	return result


## Auch jede Kachel einer größeren Turmgrundfläche ist ein Anschluss.
static func neighbors(world: GameWorld, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in DIRECTIONS:
		var tile := origin + offset
		var building := world.get_building_at(tile)
		if building != null and building.has_walkway():
			result.append(tile)
	return result
