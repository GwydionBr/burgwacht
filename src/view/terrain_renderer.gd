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
var _sprite_colors: Dictionary[String, Color] = {}


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
			# Die deckende Raute schließt subpixelbreite Nähte zwischen transparenten Bildrändern.
			draw_colored_polygon(poly, _tile_color(tile, Color(entry["color"])))
			_draw_sprite(tile, entry)
			if terrain_id == "water" and _tile_hash(tile) % 4 == 0:
				_draw_wave(Iso.tile_to_world(tile))
			_draw_map_edge(tile, poly)


## Kleine Helligkeitsunterschiede, damit der Boden nicht wie eine Fläche wirkt.
func _tile_color(tile: Vector2i, base: Color) -> Color:
	var shade := (_tile_hash(tile) % 1000) / 1000.0 - 0.5
	return base.lightened(shade * 0.08) if shade > 0 else base.darkened(-shade * 0.08)


func _draw_wave(center: Vector2) -> void:
	draw_line(center + Vector2(-9, 1), center + Vector2(-2, -1), WAVE_COLOR, 1.5, true)
	draw_line(center + Vector2(-2, -1), center + Vector2(5, 1), WAVE_COLOR, 1.5, true)


## Am vorderen Rand eine Erdkante zeichnen, damit die Karte wie eine Scholle wirkt.
func _draw_map_edge(tile: Vector2i, poly: PackedVector2Array) -> void:
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


func _draw_sprite(tile: Vector2i, entry: Dictionary) -> bool:
	if not entry.has("sprite"):
		return false
	var variant: int = variant_index(tile, int(entry.get("sprite_variants", 1)))
	var path: String = GameDefs.sprite_path(entry, variant)
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			return false
		_textures[path] = load(path) as Texture2D
		_sprite_colors[path] = _textures[path].get_image().get_pixel(int(SPRITE_CELL_SIZE.x / 2), int(SPRITE_CELL_SIZE.y / 2))
	var mask: int = transition_mask(_map, tile, str(entry["sprite_transition"])) if entry.has("sprite_transition") else 0
	draw_colored_polygon(Iso.tile_polygon(tile), _sprite_colors[path])
	var center: Vector2 = Iso.tile_to_world(tile)
	draw_texture_rect_region(_textures[path], Rect2(center - TILE_SIZE / 2, TILE_SIZE), Rect2(Vector2(mask * SPRITE_CELL_SIZE.x, 0), SPRITE_CELL_SIZE))
	return true
