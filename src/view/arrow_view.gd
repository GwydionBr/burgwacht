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


## Von der Position from zur Position to (Kachel + Ebene): Auf dem Wehrgang beginnt bzw. endet er
## so viel höher, wie die Figur dort steht (FigureView.wall_walk_height()).
func setup(from: Vector3i, to: Vector3i) -> void:
	_from = _launch_point(from)
	_to = _launch_point(to)
	position = _point(0.0)


## Brusthöhe einer Figur auf dieser Position, in Weltkoordinaten.
static func _launch_point(at: Vector3i) -> Vector2:
	var lift := LAUNCH_HEIGHT + FigureView.wall_walk_height() * at.z
	return Iso.tile_to_world(Vector2i(at.x, at.y)) - Vector2(0, lift)


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
