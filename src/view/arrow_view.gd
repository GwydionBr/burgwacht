class_name ArrowView
extends Node2D
## Ein Pfeil, der sichtbar vom Schützen zum Ziel fliegt und dann verschwindet. Nur Optik: Der
## Treffer zählt in der Spielwelt schon beim Schuss (GameWorld.shot_fired).

## Flugdauer in Spielsekunden.
const FLIGHT_SECONDS := 0.35
## Höhe der Flugbahn über der Geraden in Pixeln, und Abschusshöhe (Brust der Figur).
const ARC_HEIGHT := 18.0
const LAUNCH_HEIGHT := 14.0
const SPRITE_PATH := "res://assets/sprites/effects/arrow.png"

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _elapsed := 0.0
var _started := 0.0
var _clock: GameClock
var _texture: Texture2D


## Von der Position from zur Position to (Kachel + Ebene): Auf dem Wehrgang beginnt bzw. endet er
## so viel höher, wie die Figur dort steht (FigureView.wall_walk_height()).
func setup(from: Vector3i, to: Vector3i, clock: GameClock) -> void:
	_clock = clock
	_started = _seconds()
	_texture = load(SPRITE_PATH) as Texture2D
	_from = _launch_point(from)
	_to = _launch_point(to)
	position = _point(0.0)


## Brusthöhe einer Figur auf dieser Position, in Weltkoordinaten.
static func _launch_point(at: Vector3i) -> Vector2:
	var lift := LAUNCH_HEIGHT + FigureView.wall_walk_height() * at.z
	return Iso.tile_to_world(Vector2i(at.x, at.y)) - Vector2(0, lift)


func _seconds() -> float:
	return (_clock.world.get_tick() + _clock.tick_fraction()) / float(GameClock.TICKS_PER_SECOND)


func _process(_delta: float) -> void:
	_elapsed = _seconds() - _started
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
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_texture_rect(_texture, Rect2(-_texture.get_size() * 0.25, _texture.get_size() * 0.5), false)
