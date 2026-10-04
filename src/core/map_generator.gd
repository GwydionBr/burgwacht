class_name MapGenerator
extends RefCounted
## Erzeugt eine zufällige Karte aus einem Seed. Gleicher Seed ergibt die gleiche Karte.

## Um den Startpunkt bleibt Platz für den Bergfried.
const START_CLEAR_RADIUS := 7.0
## In diesem Umkreis gibt es garantiert Stein und Eisen.
const START_DEPOSIT_RADIUS := 22.0
## Ein Wild-Rudel je so viele Kacheln Kartenfläche (mindestens eins).
const GAME_PACK_AREA := 900
## Kacheln je Rudel.
const GAME_PACK_SIZE := Vector2i(3, 6)
## So oft wird nach einem Platz am Waldrand gesucht, bevor jede freie Wiese genügt.
const GAME_SITE_TRIES := 40
## Nachbarn mit gemeinsamer Kante.
const EDGE_NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Alle acht Nachbarn, auch schräg.
const ALL_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i.UP, Vector2i(1, -1), Vector2i.LEFT,
	Vector2i.RIGHT, Vector2i(-1, 1), Vector2i.DOWN, Vector2i(1, 1),
]


static func generate(map_seed: int, width: int, height: int) -> MapData:
	var map := MapData.new(width, height)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var ground := _make_noise(map_seed, 0.045)
	var forest := _make_noise(map_seed + 1, 0.07)
	var rock := _make_noise(map_seed + 2, 0.11)
	var start := map.center()

	for y in height:
		for x in width:
			var tile := Vector2i(x, y)
			var dist := Vector2(tile - start).length()
			var terrain_id := _terrain_for(ground.get_noise_2d(x, y), dist)
			map.set_terrain(tile, terrain_id)
			if terrain_id == "water" or dist <= START_CLEAR_RADIUS:
				continue
			var deposit_type := _deposit_for(forest.get_noise_2d(x, y), rock.get_noise_2d(x, y), rng)
			if deposit_type != "":
				map.add_deposit(tile, Deposit.create(deposit_type, rng))

	for type: String in ["stone", "iron"]:
		_ensure_near_start(map, type, rng)
	# Eigener Zufall, damit Wild die übrige Karte eines Seeds nicht verändert.
	var game_rng := RandomNumberGenerator.new()
	game_rng.seed = map_seed + 3
	_add_game_packs(map, game_rng)
	return map


static func _make_noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	return noise


static func _terrain_for(height: float, dist_from_start: float) -> String:
	# Das Startgebiet liegt nie unter Wasser.
	if dist_from_start > START_CLEAR_RADIUS + 4:
		if height < -0.3:
			return "water"
		if height < -0.24:
			return "sand"
	if height > 0.28:
		return "meadow"
	if height < -0.18:
		return "dirt"
	return "grass"


static func _deposit_for(forest: float, rock: float, rng: RandomNumberGenerator) -> String:
	if rock > 0.38:
		return "iron" if rock > 0.5 and rng.randf() < 0.7 else "stone"
	if forest > 0.25 and rng.randf() < remap(forest, 0.25, 0.6, 0.35, 0.9):
		return "tree"
	if rng.randf() < 0.006:
		return "tree"
	return ""


static func _ensure_near_start(map: MapData, type: String, rng: RandomNumberGenerator) -> void:
	var start := map.center()
	for tile in map.deposits:
		if map.deposits[tile].type == type and Vector2(tile - start).length() <= START_DEPOSIT_RADIUS:
			return

	# Kein Vorkommen in Reichweite – eine kleine Gruppe in der Nähe platzieren.
	for attempt in 100:
		var dist := rng.randf_range(START_CLEAR_RADIUS + 4, START_DEPOSIT_RADIUS - 3)
		var center := start + Vector2i(Vector2.from_angle(rng.randf() * TAU) * dist)
		if not map.in_bounds(center) or map.get_terrain(center) == "water":
			continue
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.ONE]:
			var tile := center + offset
			if map.in_bounds(tile) and map.get_terrain(tile) != "water":
				map.add_deposit(tile, Deposit.create(type, rng))
		return


## Wild in Rudeln auf freier Wiese, bevorzugt am Waldrand; außerhalb des Startgebiets.
@warning_ignore("integer_division")
static func _add_game_packs(map: MapData, rng: RandomNumberGenerator) -> void:
	for i in maxi(1, map.width * map.height / GAME_PACK_AREA):
		var site := _game_site(map, rng)
		if site.x < 0:
			continue
		var pack := _grow_pack(map, site, rng.randi_range(GAME_PACK_SIZE.x, GAME_PACK_SIZE.y), rng)
		if pack.size() < GAME_PACK_SIZE.x:
			continue
		for tile in pack:
			map.add_deposit(tile, Deposit.create("game", rng))


## Eine freie Wiese mit einem Baum in der Nähe, sonst irgendeine freie Wiese; (-1, -1), wenn keine gefunden.
static func _game_site(map: MapData, rng: RandomNumberGenerator) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for attempt in GAME_SITE_TRIES:
		var tile := Vector2i(rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
		if not _is_free_meadow(map, tile):
			continue
		if _is_near_forest(map, tile):
			return tile
		if fallback.x < 0:
			fallback = tile
	return fallback


static func _is_near_forest(map: MapData, tile: Vector2i) -> bool:
	for y in range(tile.y - 2, tile.y + 3):
		for x in range(tile.x - 2, tile.x + 3):
			if _deposit_type_at(map, Vector2i(x, y)) == "tree":
				return true
	return false


static func _deposit_type_at(map: MapData, tile: Vector2i) -> String:
	if not map.in_bounds(tile) or map.get_deposit(tile) == null:
		return ""
	return map.get_deposit(tile).type


## Frei für Wild: Gelände, auf dem es sich auch vermehrt ("spread" → "terrain"), ohne Vorkommen,
## außerhalb des Startgebiets und ohne fremdes Wild daneben (auch nicht schräg), damit Rudel getrennt bleiben.
static func _is_free_meadow(map: MapData, tile: Vector2i, pack: Array[Vector2i] = []) -> bool:
	var terrains := Deposit.spread_terrains_of("game")
	if not map.in_bounds(tile) or not (terrains.is_empty() or terrains.has(map.get_terrain(tile))) \
			or map.get_deposit(tile) != null or Vector2(tile - map.center()).length() <= START_CLEAR_RADIUS:
		return false
	for offset in ALL_NEIGHBOURS:
		if _deposit_type_at(map, tile + offset) == "game" and not pack.has(tile + offset):
			return false
	return true


## Wächst von site aus über Nachbarn mit gemeinsamer Kante bis zu size Kacheln freier Wiese.
static func _grow_pack(map: MapData, site: Vector2i, size: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var pack: Array[Vector2i] = [site]
	while pack.size() < size:
		var candidates: Array[Vector2i] = []
		for tile in pack:
			for offset in EDGE_NEIGHBOURS:
				var next := tile + offset
				if _is_free_meadow(map, next, pack) and not pack.has(next) and not candidates.has(next):
					candidates.append(next)
		if candidates.is_empty():
			break
		pack.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return pack
