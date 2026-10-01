class_name TerrainRenderer
extends Node2D
## Zeichnet den Boden der Karte in einem Durchgang. Wird nur neu gezeichnet,
## wenn sich die Karte ändert – nicht in jedem Frame.

## Höhe der sichtbaren Erdkante am vorderen Kartenrand.
const EDGE_DEPTH := 18.0
const EDGE_COLOR := Color("#4a3a26")
const WAVE_COLOR := Color(1, 1, 1, 0.18)

var _map: MapData


func show_map(map: MapData) -> void:
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
			draw_colored_polygon(poly, _tile_color(tile, Color(terrain_defs[terrain_id]["color"])))
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
