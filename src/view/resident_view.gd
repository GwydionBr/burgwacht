class_name ResidentView
extends Node2D
## Zeichnet einen Bewohner als einfache Figur (Platzhalter).
## Liegt im y-sortierten Objekt-Container; die Position liest sie jeden Frame aus dem Zustand
## und interpoliert mit dem Bruchteil der Uhr zwischen zwei Takten. Getragene Ware als
## Bündel auf dem Rücken, beim Abbau wippt er, in der Arbeitsstätte ist er unsichtbar.
## Soldaten tragen die Farbe ihres Soldatentyps (units.json) und ihre Waffe (Schwert bzw. Bogen);
## ausgewählte stehen in einem Ring.

const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const OUTLINE_COLOR := Color(0, 0, 0, 0.45)
const SKIN_COLOR := Color("#e2b48c")
const LEG_COLOR := Color("#4a3b2a")
## Wippen beim Abbau: Höhe in Pixeln und Schläge pro Sekunde (Echtzeit, nur Optik).
const BOB_HEIGHT := 2.5
const BOB_RATE := 2.0
## Klinge des Schwerts.
const BLADE_COLOR := Color("#d8dee6")
## Bogen und Schwertgriff.
const WOOD_COLOR := Color("#6b4423")
## Ring um ausgewählte Soldaten.
const RING_COLOR := Color(1, 0.95, 0.7, 0.95)
## Fläche der Figur um den Fußpunkt, in der ein Klick sie trifft.
const HIT_RECT := Rect2(-8, -27, 16, 30)

## Ist er ausgewählt? Dann steht er in einem Ring.
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _resident: Resident
var _clock: GameClock


func setup(resident: Resident, clock: GameClock) -> void:
	_resident = resident
	_clock = clock
	_update_position()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_position()


## Die Fläche der Figur in Weltkoordinaten (für Klick und Rahmen).
func hit_rect() -> Rect2:
	return Rect2(position + HIT_RECT.position, HIT_RECT.size)


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
	if selected:
		draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, RING_COLOR, 2.0, true)
	draw_set_transform(Vector2(0, -_bob()))
	# Beine, Körper (Kittel), Kopf.
	draw_rect(Rect2(-3.5, -7, 2.5, 7), LEG_COLOR)
	draw_rect(Rect2(1, -7, 2.5, 7), LEG_COLOR)
	var body := PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(3.5, -18), Vector2(-3.5, -18)])
	draw_colored_polygon(body, _body_color())
	body.append(body[0])
	draw_polyline(body, OUTLINE_COLOR, 1.0, true)
	draw_circle(Vector2(0, -22), 4.0, SKIN_COLOR)
	draw_arc(Vector2(0, -22), 4.0, 0, TAU, 16, OUTLINE_COLOR, 1.0, true)
	if _resident.carried_amount > 0:
		_draw_bundle(Color(str(GameDefs.get_instance().goods[_resident.carried_good]["color"])))
	if _resident.is_soldier():
		_draw_weapon()


## Kittel in der Farbe des Soldatentyps, sonst in der des Bewohners. Jedes Mal neu gelesen:
## Ein Untätiger kann jederzeit Soldat werden.
func _body_color() -> Color:
	if _resident.is_soldier():
		return SoldierType.color_of(_resident.soldier_type)
	return Color(str(GameDefs.get_instance().units["resident"]["color"]))


## Waffe neben dem Körper: Nahkämpfer mit erhobener Klinge, Fernkämpfer mit Bogen.
func _draw_weapon() -> void:
	if SoldierType.is_melee(_resident.soldier_type):
		draw_line(Vector2(6, -8), Vector2(6, -24), BLADE_COLOR, 2.0)
		draw_line(Vector2(3, -11), Vector2(9, -11), WOOD_COLOR, 2.0)
	else:
		draw_arc(Vector2(3, -14), 9.0, -PI / 2.0 + 0.3, PI / 2.0 - 0.3, 10, WOOD_COLOR, 1.5, true)
		draw_line(Vector2(5.8, -22), Vector2(5.8, -6), OUTLINE_COLOR, 1.0)


## Bündel der getragenen Ware auf dem Rücken, über die Schulter ragend.
func _draw_bundle(color: Color) -> void:
	var bundle := Rect2(-8, -25, 9, 9)
	draw_rect(bundle, color)
	draw_rect(bundle, OUTLINE_COLOR, false, 1.0)
	draw_line(Vector2(-8, -20.5), Vector2(1, -20.5), OUTLINE_COLOR, 1.0)
