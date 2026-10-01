class_name TileHighlight
extends Node2D
## Markiert die Kachel unter dem Mauszeiger.

const FILL_COLOR := Color(1, 1, 1, 0.12)
const LINE_COLOR := Color(1, 0.95, 0.7, 0.9)

var _tile := Vector2i.ZERO


func show_tile(tile: Vector2i) -> void:
	_tile = tile
	visible = true
	queue_redraw()


func _draw() -> void:
	var poly := Iso.tile_polygon(_tile)
	draw_colored_polygon(poly, FILL_COLOR)
	poly.append(poly[0])
	draw_polyline(poly, LINE_COLOR, 1.5, true)
