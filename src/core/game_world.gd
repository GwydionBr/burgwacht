class_name GameWorld
extends RefCounted
## Die Spielwelt: Wurzel des gesamten Spielzustands einer Partie.
## Besitzt Karte, Taktzähler und den einzigen Zufallsgenerator der Simulation.
## Schreitet nur über step() voran – wer wie oft step() aufruft, liegt außerhalb des Kerns.

signal deposit_added(tile: Vector2i)
signal deposit_removed(tile: Vector2i)
signal day_started(day: int)

## Ein Tag dauert 600 Takte (bei 1× eine Minute).
const TICKS_PER_DAY := 600

var map: MapData

var _scenario_id: String
var _seed: int
var _tick := 0
var _rng := RandomNumberGenerator.new()


## Neue Partie aus einem gültigen Szenario. Der Seed kommt vom Aufrufer
## (meist scenario.resolve_seed(…), oder ein fester Seed von der Kommandozeile).
static func create(scenario: Scenario, world_seed: int) -> GameWorld:
	assert(scenario.error == "", scenario.error)
	var world := GameWorld.new()
	world._scenario_id = scenario.id
	world._seed = world_seed
	world.map = MapGenerator.generate(world_seed, scenario.map_size.x, scenario.map_size.y)
	world.map.deposit_added.connect(world.deposit_added.emit)
	world.map.deposit_removed.connect(world.deposit_removed.emit)
	# Eigener Zufall, getrennt von dem der Kartenerzeugung.
	world._rng.seed = hash([world_seed, "world"])
	return world


## Genau ein Takt.
func step() -> void:
	_tick += 1
	_spread_deposits()
	if _tick % TICKS_PER_DAY == 0:
		day_started.emit(get_day())


func get_scenario_id() -> String:
	return _scenario_id


func get_seed() -> int:
	return _seed


func get_tick() -> int:
	return _tick


## Der erste Tag ist Tag 1.
@warning_ignore("integer_division")
func get_day() -> int:
	return _tick / TICKS_PER_DAY + 1


## Vorkommen mit "spread" in den Daten (z. B. Bäume) breiten sich in ihrem Rhythmus aus:
## Jede freie, bebaubare Kachel neben einem solchen Vorkommen bekommt mit der
## angegebenen Chance ein neues. Typen und Kacheln in fester Reihenfolge (ADR 0001).
func _spread_deposits() -> void:
	var defs := GameDefs.get_instance().deposits
	var types: Array[String] = []
	types.assign(defs.keys())
	types.sort()
	for type: String in types:
		var deposit_def: Dictionary = defs[type]
		if not deposit_def.has("spread"):
			continue
		var spread: Dictionary = deposit_def["spread"]
		if _tick % int(spread["interval_ticks"]) == 0:
			_spread_type(type, float(spread["chance"]))


@warning_ignore("integer_division")
func _spread_type(type: String, chance: float) -> void:
	# Kacheln neben einem Vorkommen dieses Typs markieren, dann zeilenweise würfeln.
	var near_mask := PackedByteArray()
	near_mask.resize(map.width * map.height)
	for tile: Vector2i in map.deposits:
		if map.deposits[tile].type != type:
			continue
		for y in range(maxi(tile.y - 1, 0), mini(tile.y + 2, map.height)):
			for x in range(maxi(tile.x - 1, 0), mini(tile.x + 2, map.width)):
				near_mask[y * map.width + x] = 1
	for i in near_mask.size():
		if near_mask[i] == 0:
			continue
		var tile := Vector2i(i % map.width, i / map.width)
		if map.is_buildable(tile) and _rng.randf() < chance:
			map.add_deposit(tile, Deposit.create(type, _rng))
