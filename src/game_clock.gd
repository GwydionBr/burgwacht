class_name GameClock
extends Node
## Treibt die Spielwelt an: sammelt die verstrichene Zeit und ruft passend oft step() auf.
## Spielgeschwindigkeit und Pause gehören hierher, nicht in die Spielwelt.
## Während der Gründung steht die Uhr und lässt sich nicht starten. Das Spielmenü hält sie
## an (hold()); danach gilt wieder die vorige Geschwindigkeit bzw. Pause.

signal speed_changed(speed: int, paused: bool)

## Takte pro Sekunde Echtzeit bei 1×.
const TICKS_PER_SECOND := 10
const SPEEDS: Array[int] = [1, 2, 4]
## Obergrenze pro Frame, damit ein Hänger keine Lawine an Takten auslöst.
const MAX_TICKS_PER_FRAME := 10
## Gleicht Rundungsfehler beim Aufsummieren kleiner Zeitschritte aus.
const EPSILON := 0.000001

## Beim Wechsel der Spielwelt verfällt ein noch angesammelter Zeitrest;
## eine Spielwelt in Gründung hält die Uhr an.
var world: GameWorld:
	set(value):
		world = value
		_pending_ticks = 0.0
		if world != null and world.is_founding() and not _paused:
			_paused = true
			speed_changed.emit(_speed, _paused)

var _speed := 1
var _paused := false
var _pending_ticks := 0.0
var _held := false


func _process(delta: float) -> void:
	if world == null:
		return
	for i in advance(delta):
		world.step()


## Verbucht delta Sekunden und gibt zurück, wie viele Takte jetzt fällig sind.
func advance(delta: float) -> int:
	if _paused or _held:
		return 0
	_pending_ticks += delta * TICKS_PER_SECOND * _speed
	var ticks := floori(_pending_ticks + EPSILON)
	if ticks > MAX_TICKS_PER_FRAME:
		_pending_ticks = 0.0
		return MAX_TICKS_PER_FRAME
	_pending_ticks -= ticks
	return ticks


## Bruchteil bis zum nächsten Takt (0 bis unter 1), damit die Darstellung zwischen zwei
## Takten interpolieren kann – auch im Zeitraffer.
func tick_fraction() -> float:
	return clampf(_pending_ticks, 0.0, 1.0)


func set_speed(speed: int) -> void:
	assert(speed in SPEEDS, "Unbekannte Geschwindigkeit %d" % speed)
	if _is_founding() or _held:
		return
	_speed = speed
	_paused = false
	speed_changed.emit(_speed, _paused)


func toggle_pause() -> void:
	if _is_founding() or _held:
		return
	_paused = not _paused
	speed_changed.emit(_speed, _paused)


## Hält die Zeit an, ohne Geschwindigkeit und Pause zu ändern; bis release() wirken auch
## set_speed() und toggle_pause() nicht.
func hold() -> void:
	_held = true


## Hebt hold() auf: Es gilt wieder die vorige Geschwindigkeit bzw. Pause.
func release() -> void:
	_held = false


func get_speed() -> int:
	return _speed


func is_paused() -> bool:
	return _paused


## Steht die Zeit? Ohne Spielwelt, in Gründung und Pause, im Spielmenü (hold()) und nach der
## Niederlage. Die Tonregie lässt dann keine Spielgeräusche entstehen.
func is_time_standing() -> bool:
	return world == null or _paused or _held or world.is_defeated()


func _is_founding() -> bool:
	return world != null and world.is_founding()
