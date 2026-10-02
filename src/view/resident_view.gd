class_name ResidentView
extends Node2D
## Zeichnet einen Bewohner als einfache Figur (Platzhalter) auf der Mitte seiner Kachel.
## Liegt im y-sortierten Objekt-Container; die Position liest sie jeden Frame aus dem Zustand.

const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const OUTLINE_COLOR := Color(0, 0, 0, 0.45)
const SKIN_COLOR := Color("#e2b48c")
const LEG_COLOR := Color("#4a3b2a")

var _resident: Resident
var _color: Color


func setup(resident: Resident) -> void:
	_resident = resident
	_color = Color(str(GameDefs.get_instance().units["resident"]["color"]))
	position = Iso.tile_to_world(resident.tile)
	queue_redraw()


func _process(_delta: float) -> void:
	position = Iso.tile_to_world(_resident.tile)


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	# Beine, Körper (Kittel), Kopf.
	draw_rect(Rect2(-3.5, -7, 2.5, 7), LEG_COLOR)
	draw_rect(Rect2(1, -7, 2.5, 7), LEG_COLOR)
	var body := PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(3.5, -18), Vector2(-3.5, -18)])
	draw_colored_polygon(body, _color)
	body.append(body[0])
	draw_polyline(body, OUTLINE_COLOR, 1.0, true)
	draw_circle(Vector2(0, -22), 4.0, SKIN_COLOR)
	draw_arc(Vector2(0, -22), 4.0, 0, TAU, 16, OUTLINE_COLOR, 1.0, true)
