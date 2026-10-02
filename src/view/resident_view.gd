class_name ResidentView
extends Node2D
## Zeichnet einen Bewohner als einfache Figur (Platzhalter).
## Liegt im y-sortierten Objekt-Container; die Position liest sie jeden Frame aus dem Zustand
## und interpoliert mit dem Bruchteil der Uhr zwischen zwei Takten. Getragene Ware als
## Bündel auf dem Rücken, beim Abbau wippt er, in der Arbeitsstätte ist er unsichtbar.

const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const OUTLINE_COLOR := Color(0, 0, 0, 0.45)
const SKIN_COLOR := Color("#e2b48c")
const LEG_COLOR := Color("#4a3b2a")
## Wippen beim Abbau: Höhe in Pixeln und Schläge pro Sekunde (Echtzeit, nur Optik).
const BOB_HEIGHT := 2.5
const BOB_RATE := 2.0

var _resident: Resident
var _clock: GameClock
var _color: Color


func setup(resident: Resident, clock: GameClock) -> void:
	_resident = resident
	_clock = clock
	_color = Color(str(GameDefs.get_instance().units["resident"]["color"]))
	_update_position()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_position()


func _update_position() -> void:
	position = Iso.point_to_world(_resident.tile_point(_clock.tick_fraction()))
	visible = not _resident.is_inside_building()
	queue_redraw()


## Versatz nach oben beim Abbau, sonst 0.
func _bob() -> float:
	if _resident.task != Resident.Task.MINING:
		return 0.0
	return BOB_HEIGHT * absf(sin(Time.get_ticks_msec() / 1000.0 * BOB_RATE * PI))


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, SHADOW_COLOR)
	draw_set_transform(Vector2(0, -_bob()))
	# Beine, Körper (Kittel), Kopf.
	draw_rect(Rect2(-3.5, -7, 2.5, 7), LEG_COLOR)
	draw_rect(Rect2(1, -7, 2.5, 7), LEG_COLOR)
	var body := PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(3.5, -18), Vector2(-3.5, -18)])
	draw_colored_polygon(body, _color)
	body.append(body[0])
	draw_polyline(body, OUTLINE_COLOR, 1.0, true)
	draw_circle(Vector2(0, -22), 4.0, SKIN_COLOR)
	draw_arc(Vector2(0, -22), 4.0, 0, TAU, 16, OUTLINE_COLOR, 1.0, true)
	if _resident.carried_amount > 0:
		_draw_bundle(Color(str(GameDefs.get_instance().goods[_resident.carried_good]["color"])))


## Bündel der getragenen Ware auf dem Rücken, über die Schulter ragend.
func _draw_bundle(color: Color) -> void:
	var bundle := Rect2(-8, -25, 9, 9)
	draw_rect(bundle, color)
	draw_rect(bundle, OUTLINE_COLOR, false, 1.0)
	draw_line(Vector2(-8, -20.5), Vector2(1, -20.5), OUTLINE_COLOR, 1.0)
