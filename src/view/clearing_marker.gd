class_name ClearingMarker
extends Node2D
## Axtmarkierung über einem Baum; bleibt auch außerhalb des Roden-Werkzeugs sichtbar.

const BADGE_COLOR := Color("#29251e")
const MARK_COLOR := Color("#edc66c")
const HANDLE_COLOR := Color("#bd8d50")


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, BADGE_COLOR)
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, MARK_COLOR, 1.0, true)
	draw_axe(self, Vector2.ZERO)


## Dasselbe Axtsymbol auf der Markierung und auf der Werkzeugkarte.
static func draw_axe(canvas: CanvasItem, center: Vector2, scale_factor: float = 1.0) -> void:
	canvas.draw_line(center + Vector2(-5, 7) * scale_factor,
			center + Vector2(4, -6) * scale_factor, HANDLE_COLOR, 3.0 * scale_factor, true)
	var blade := PackedVector2Array()
	for point: Vector2 in [Vector2(0, -5), Vector2(4, -8), Vector2(9, -5), Vector2(7, 1), Vector2(3, -1)]:
		blade.append(center + point * scale_factor)
	canvas.draw_colored_polygon(blade, MARK_COLOR)
