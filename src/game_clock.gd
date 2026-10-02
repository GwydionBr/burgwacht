class_name GameClock
extends Node
## Treibt die Spielwelt an: sammelt die verstrichene Zeit und ruft passend oft step() auf.
## Spielgeschwindigkeit und Pause gehören hierher, nicht in die Spielwelt.

signal speed_changed(speed: int, paused: bool)

const SPEEDS: Array[int] = [1, 2, 4]
## Obergrenze pro Frame, damit ein Hänger keine Lawine an Takten auslöst.
const MAX_TICKS_PER_FRAME := 10
## Gleicht Rundungsfehler beim Aufsummieren kleiner Zeitschritte aus.
const EPSILON := 0.000001

var world: GameWorld

var _speed := 1
var _paused := false
var _pending := 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	for i in advance(delta):
		world.step()


## Verbucht delta Sekunden und gibt zurück, wie viele Takte jetzt fällig sind.
func advance(delta: float) -> int:
	if _paused:
		return 0
	_pending += delta * GameWorld.TICKS_PER_SECOND * _speed
	var ticks := floori(_pending + EPSILON)
	if ticks > MAX_TICKS_PER_FRAME:
		_pending = 0.0
		return MAX_TICKS_PER_FRAME
	_pending -= ticks
	return ticks


func set_speed(speed: int) -> void:
	assert(speed in SPEEDS, "Unbekannte Geschwindigkeit %d" % speed)
	_speed = speed
	_paused = false
	speed_changed.emit(_speed, _paused)


func toggle_pause() -> void:
	_paused = not _paused
	speed_changed.emit(_speed, _paused)


func get_speed() -> int:
	return _speed


func is_paused() -> bool:
	return _paused
