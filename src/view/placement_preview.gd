class_name PlacementPreview
extends Node2D
## Halbdurchsichtige Bauvorschau unter der Maus: Grundflächen grün (erlaubt) oder rot,
## dazu die Kachel vor dem Eingang. Beim Abriss das Gebäude unter der Maus orange
## (abreißbar) oder rot, ohne Eingang. Eine Mauerlinie zeigt je Kachel grün, was entsteht, und
## rot, was nicht. Die Spielwelt liefert bestehende Wehrgänge für die Spriteanschlüsse.

const OK_COLOR := Color(0.35, 0.9, 0.4)
const BLOCKED_COLOR := Color(0.95, 0.3, 0.25)
const DEMOLISH_COLOR := Color(1.0, 0.6, 0.15)
const FILL_ALPHA := 0.35
const BLOCK_ALPHA := 0.45
const FRONT_COLOR := Color(1, 0.95, 0.7, 0.8)

## Bestehende Wehrgänge für dieselbe Anschlusswahl wie auf der Karte.
var world: GameWorld
## Zeichenbefehle halten Texturen nicht selbst am Leben.
var _textures: Dictionary[String, Texture2D] = {}

## Paare [Gebäudetyp, Ursprung].
var _parts: Array[Array] = []
var _allowed := true
## Bei einer Linie: Ursprung → entsteht dort ein Gebäude? (sonst gilt _allowed für alle)
var _tile_allowed: Dictionary[Vector2i, bool] = {}
var _demolish := false


func show_parts(parts: Array[Array], allowed: bool) -> void:
	_parts = parts
	_allowed = allowed
	_tile_allowed.clear()
	_demolish = false
	visible = true
	queue_redraw()


## Eine Linie aus Gebäuden mit einer Kachel: plan ist Ursprung → Grund (leer = entsteht),
## wie GameWorld.line_plan().
func show_line(type_id: String, plan: Dictionary[Vector2i, String]) -> void:
	var tiles: Array[Vector2i] = plan.keys()
	# Hinten zuerst, damit vordere Blöcke die hinteren verdecken.
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	_parts.clear()
	_tile_allowed.clear()
	for tile in tiles:
		_parts.append([type_id, tile])
		_tile_allowed[tile] = plan[tile] == ""
	_demolish = false
	visible = true
	queue_redraw()


## Hebt ein bestehendes Gebäude für den Abriss hervor.
func show_demolish(type_id: String, origin: Vector2i, allowed: bool) -> void:
	_parts = [[type_id, origin]]
	_allowed = allowed
	_tile_allowed.clear()
	_demolish = true
	visible = true
	queue_redraw()


## Dieselben Varianten und Mauerteile wie auf der Karte, ergänzt um gültige geplante Wehrgänge.
## Ohne verfügbares Hauptbild bleibt die Blockvorschau erhalten.
func sprite_paths(type_id: String, origin: Vector2i) -> Array[String]:
	var entry: Dictionary = GameDefs.get_instance().buildings[type_id]
	var neighbors: Array[Vector2i] = []
	if world != null:
		neighbors = WallSprites.neighbors(world, origin)
	for part in _parts:
		var planned_type: String = part[0]
		var planned_origin: Vector2i = part[1]
		var planned_entry: Dictionary = GameDefs.get_instance().buildings[planned_type]
		if not _demolish and _tile_allowed.get(planned_origin, _allowed) and bool(planned_entry.get("walkway", false)):
			for tile in Building.footprint(planned_type, planned_origin):
				if not neighbors.has(tile):
					neighbors.append(tile)
	var paths := WallSprites.paths(entry, origin, neighbors)
	if not ResourceLoader.exists(paths[0]):
		return []
	return paths


func _draw() -> void:
	for part in _parts:
		var type_id: String = part[0]
		var origin: Vector2i = part[1]
		var color := BLOCKED_COLOR
		if _tile_allowed.get(origin, _allowed):
			color = DEMOLISH_COLOR if _demolish else OK_COLOR
		for tile in Building.footprint(type_id, origin):
			draw_colored_polygon(Iso.tile_polygon(tile), Color(color, FILL_ALPHA))
		var paths := sprite_paths(type_id, origin)
		if paths.is_empty():
			_draw_ghost_block(type_id, origin, color)
		else:
			var center := (Iso.tile_to_world(origin) + Iso.tile_to_world(Building.last_tile_of(type_id, origin))) * 0.5
			for path in paths:
				if not _textures.has(path):
					_textures[path] = load(path)
				var texture := _textures[path]
				var image_size := texture.get_size() * BuildingView.SPRITE_SCALE
				draw_texture_rect(texture, Rect2(center - image_size * 0.5, image_size), false, Color(color, BLOCK_ALPHA))
		if _demolish or not Building.has_entrance_type(type_id):
			continue
		var front := Iso.tile_polygon(Building.front_of_entrance(type_id, origin))
		front.append(front[0])
		draw_polyline(front, FRONT_COLOR, 2.0, true)


## Umriss des späteren Blocks, damit Größe und Höhe erkennbar sind.
func _draw_ghost_block(type_id: String, origin: Vector2i, color: Color) -> void:
	var base := BuildingView.footprint_corners(type_id, origin, Vector2.ZERO, BuildingView.INSET)
	var faces := BuildingView.block_faces(base, float(GameDefs.get_instance().buildings[type_id]["height"]))
	var faded := Color(color, BLOCK_ALPHA)
	draw_colored_polygon(faces[0], faded.darkened(0.2))
	draw_colored_polygon(faces[1], faded.darkened(0.35))
	draw_colored_polygon(faces[2], faded)
