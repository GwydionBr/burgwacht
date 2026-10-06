class_name TerrainRenderer
extends Node2D
## Zeichnet den Boden der Karte in einem Durchgang. Wird nur neu gezeichnet,
## wenn sich die Karte ändert – nicht in jedem Frame.

## Höhe der sichtbaren Erdkante am vorderen Kartenrand.
const EDGE_DEPTH := 18.0
## Doppelte Auflösung der gerenderten Kachel; eine Atlasspalte je Kantenmaske.
const SPRITE_CELL_SIZE := Vector2(128, 64)
const TILE_SIZE := Vector2(Iso.TILE_W, Iso.TILE_H)
const EDGE_COLOR := Color("#4a3a26")
const WAVE_COLOR := Color(1, 1, 1, 0.18)

var _map: MapData
var _textures: Dictionary[String, Texture2D] = {}


func show_map(map: MapData) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_map = map
	queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	var terrain_defs := GameDefs.get_instance().terrain
	for y in _map.height:
		for x in _map.width:
			var tile := Vector2i(x, y)
			var terrain_id := _map.get_terrain(tile)
			var poly := Iso.tile_polygon(tile)
			var entry: Dictionary = terrain_defs[terrain_id]
			if not _draw_sprite(tile, entry):
				draw_colored_polygon(poly, _tile_color(tile, Color(entry["color"])))
				if terrain_id == "water" and _tile_hash(tile) % 4 == 0:
					_draw_wave(Iso.tile_to_world(tile))
			_draw_map_edge(tile, poly, entry)



## Kleine Helligkeitsunterschiede, damit der Boden nicht wie eine Fläche wirkt.
func _tile_color(tile: Vector2i, base: Color) -> Color:
	var shade := (_tile_hash(tile) % 1000) / 1000.0 - 0.5
	return base.lightened(shade * 0.08) if shade > 0 else base.darkened(-shade * 0.08)


func _draw_wave(center: Vector2) -> void:
	draw_line(center + Vector2(-9, 1), center + Vector2(-2, -1), WAVE_COLOR, 1.5, true)
	draw_line(center + Vector2(-2, -1), center + Vector2(5, 1), WAVE_COLOR, 1.5, true)


## Am vorderen Rand eine Erdkante zeichnen, damit die Karte wie eine Scholle wirkt.
func _draw_map_edge(tile: Vector2i, poly: PackedVector2Array, entry: Dictionary) -> void:
	if entry.has("sprite_edge"):
		var texture: Texture2D = _texture("res://assets/sprites/" + str(entry["sprite_edge"]) + ".png")
		if texture != null:
			var center: Vector2 = Iso.tile_to_world(tile)
			for side: int in 2:
				if (side == 0 and tile.x == _map.width - 1) or (side == 1 and tile.y == _map.height - 1):
					draw_texture_rect_region(texture, Rect2(center - Vector2(32, 16), Vector2(64, 52)), Rect2(Vector2(side * 128, 0), Vector2(128, 104)))
			return
	var depth := Vector2(0, EDGE_DEPTH)
	if tile.x == _map.width - 1:
		draw_colored_polygon(PackedVector2Array([poly[1], poly[2], poly[2] + depth, poly[1] + depth]), EDGE_COLOR)
	if tile.y == _map.height - 1:
		draw_colored_polygon(PackedVector2Array([poly[2], poly[3], poly[3] + depth, poly[2] + depth]), EDGE_COLOR.darkened(0.25))


func _tile_hash(tile: Vector2i) -> int:
	return absi(hash(tile))


## Kantenmaske im Uhrzeigersinn: Norden, Osten, Süden, Westen; diagonale Nachbarn zählen nicht.
static func transition_mask(map: MapData, tile: Vector2i, neighbor_id: String) -> int:
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var mask: int = 0
	for index: int in offsets.size():
		var neighbor: Vector2i = tile + offsets[index]
		if map.in_bounds(neighbor) and map.get_terrain(neighbor) == neighbor_id:
			mask |= 1 << index
	return mask


## Rein aus der Kachelposition, ohne Zufall der Spielwelt oder Eintrag im Spielstand.
static func variant_index(tile: Vector2i, count: int) -> int:
	return posmod(tile.x * 17 + tile.y * 31 + tile.x * tile.y * 7, maxi(count, 1))


## Übergänge zu allen höherrangigen Nachbargeländen; Ecken schließen auch diagonale Berührungen.
## Bits 0–3: Nord, Ost, Süd, West; Bits 4–7: Nordost, Südost, Südwest, Nordwest.
static func transition_layers(map: MapData, tile: Vector2i) -> Dictionary[String, int]:
	var definitions: Dictionary = GameDefs.get_instance().terrain
	var source: Dictionary = definitions[map.get_terrain(tile)]
	var result: Dictionary[String, int] = {}
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for index: int in offsets.size():
		var neighbor: Vector2i = tile + offsets[index]
		if not map.in_bounds(neighbor):
			continue
		var target_id: String = map.get_terrain(neighbor)
		var target: Dictionary = definitions[target_id]
		if not target.has("sprite_overlay") or int(target.get("sprite_priority", 0)) <= int(source.get("sprite_priority", 0)):
			continue
		if index >= 4:
			var adjacent_mask: int = (1 << (index - 4)) | (1 << ((index - 3) % 4))
			if transition_mask(map, tile, target_id) & adjacent_mask:
				continue
		result[target_id] = result.get(target_id, 0) | (1 << index)
	return result


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			return null
		_textures[path] = load(path) as Texture2D
	return _textures[path]


func _draw_sprite(tile: Vector2i, entry: Dictionary) -> bool:
	if not entry.has("sprite"):
		return false
	var variant: int = variant_index(tile, int(entry.get("sprite_variants", 1)))
	var texture: Texture2D = _texture(GameDefs.sprite_path(entry, variant))
	if texture == null:
		return false
	var center: Vector2 = Iso.tile_to_world(tile)
	# Ein Viertelpixel Überstand schließt die Filternaht, ohne eine gezeichnete Raute unterzulegen.
	var destination := Rect2(center - TILE_SIZE / 2 - Vector2(0.25, 0.125), TILE_SIZE + Vector2(0.5, 0.25))
	draw_texture_rect_region(texture, destination, Rect2(Vector2.ZERO, SPRITE_CELL_SIZE))
	var layers: Dictionary[String, int] = transition_layers(_map, tile)
	var targets: Array[String] = []
	targets.assign(layers.keys())
	var definitions: Dictionary = GameDefs.get_instance().terrain
	targets.sort_custom(func(a: String, b: String) -> bool:
		return int(definitions[a]["sprite_priority"]) < int(definitions[b]["sprite_priority"]))
	# Die höchste Priorität liegt zuletzt und schließt Kreuzungen.
	for target_id: String in targets:
		var target: Dictionary = GameDefs.get_instance().terrain[target_id]
		var overlay_entry: Dictionary = {"sprite": target["sprite_overlay"], "sprite_variants": target.get("sprite_variants", 1)}
		var overlay: Texture2D = _texture(GameDefs.sprite_path(overlay_entry, variant_index(tile, int(target.get("sprite_variants", 1)))))
		if overlay == null:
			continue
		for direction: int in 8:
			if layers[target_id] & (1 << direction):
				draw_texture_rect_region(overlay, destination, Rect2(Vector2(direction * SPRITE_CELL_SIZE.x, 0), SPRITE_CELL_SIZE))
	return true
