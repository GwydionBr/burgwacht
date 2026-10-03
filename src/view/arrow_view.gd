class_name ArrowView
extends Node2D
## Ein Pfeil, der sichtbar vom Schützen zum Ziel fliegt und dann verschwindet. Nur Optik: Der
## Treffer zählt in der Spielwelt schon beim Schuss (GameWorld.shot_fired).

## Flugdauer in Sekunden (Echtzeit).
const FLIGHT_SECONDS := 0.35
## Höhe der Flugbahn über der Geraden in Pixeln, und Abschusshöhe (Brust der Figur).
const ARC_HEIGHT := 18.0
const LAUNCH_HEIGHT := 14.0
const LENGTH := 9.0
const SHAFT_COLOR := Color("#4a3622")
const TIP_COLOR := Color("#d8dee6")

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _elapsed := 0.0


## Von der Kachel from zur Kachel to (Kachelkoordinaten).
func setup(from: Vector2i, to: Vector2i) -> void:
	_from = Iso.tile_to_world(from) - Vector2(0, LAUNCH_HEIGHT)
	_to = Iso.tile_to_world(to) - Vector2(0, LAUNCH_HEIGHT)
	position = _point(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= FLIGHT_SECONDS:
		queue_free()
		return
	position = _point(_elapsed / FLIGHT_SECONDS)
	queue_redraw()


## Punkt auf der Flugbahn (Parabel über der Geraden) bei Anteil t.
func _point(t: float) -> Vector2:
	return _from.lerp(_to, t) - Vector2(0, ARC_HEIGHT * 4.0 * t * (1.0 - t))


func _draw() -> void:
	var t := _elapsed / FLIGHT_SECONDS
	var direction := (_point(minf(t + 0.05, 1.0)) - _point(maxf(t - 0.05, 0.0))).normalized()
	if direction == Vector2.ZERO:
		direction = (_to - _from).normalized()
	var tail := -direction * LENGTH * 0.5
	var tip := direction * LENGTH * 0.5
	draw_line(tail, tip, SHAFT_COLOR, 1.5)
	draw_line(tip, tip - direction * 2.5, TIP_COLOR, 2.0)
