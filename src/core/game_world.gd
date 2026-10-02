class_name GameWorld
extends RefCounted
## Die Spielwelt: Wurzel des gesamten Spielzustands einer Partie.
## Besitzt Karte, Taktzähler und den einzigen Zufallsgenerator der Simulation.
## Schreitet nur über step() voran – wer wie oft step() aufruft, liegt außerhalb des Kerns.

signal deposit_removed(tile: Vector2i)
signal day_started(day: int)

## Takte pro Sekunde Spielzeit bei 1×.
const TICKS_PER_SECOND := 10
## Ein Tag dauert 60 Sekunden Spielzeit.
const TICKS_PER_DAY := 600

var map: MapData

var _tick := 0
var _rng := RandomNumberGenerator.new()


static func create(world_seed: int, width: int, height: int) -> GameWorld:
	var world := GameWorld.new()
	world.map = MapGenerator.generate(world_seed, width, height)
	world.map.deposit_removed.connect(world.deposit_removed.emit)
	# Eigener Zufall, getrennt von dem der Kartenerzeugung.
	world._rng.seed = hash([world_seed, "world"])
	return world


## Genau ein Takt.
func step() -> void:
	_tick += 1
	if _tick % TICKS_PER_DAY == 0:
		day_started.emit(get_day())


func get_tick() -> int:
	return _tick


## Der erste Tag ist Tag 1.
@warning_ignore("integer_division")
func get_day() -> int:
	return _tick / TICKS_PER_DAY + 1
