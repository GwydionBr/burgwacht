class_name SelectionBox
extends Node2D
## Rahmen beim Linksziehen: zeigt, welche Soldaten gleich ausgewählt werden (Weltkoordinaten).

const FILL_COLOR := Color(1, 0.95, 0.7, 0.12)
const LINE_COLOR := Color(1, 0.95, 0.7, 0.9)

var _rect := Rect2()


## Zeigt den Rahmen zwischen zwei Punkten (in beliebiger Reihenfolge).
func show_box(from: Vector2, to: Vector2) -> void:
	_rect = Rect2(from, to - from).abs()
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_rect(_rect, FILL_COLOR)
	# Breite -1: immer ein Pixel, unabhängig vom Zoom.
	draw_rect(_rect, LINE_COLOR, false, -1.0)
