class_name MapGenerator
extends RefCounted
## Erzeugt eine zufällige Karte aus einem Seed. Gleicher Seed ergibt die gleiche Karte.
## Die Landschaft besteht aus wenigen großen Flächen statt vieler Einzelstücke: einige Seen,
## zusammenhängende Wälder und Felsfelder, auf denen sich ein Steinbruch oder eine Mine lohnt.

## Um den Startpunkt bleibt Platz für den Bergfried.
const START_CLEAR_RADIUS := 7.0
## In diesem Umkreis gibt es garantiert Stein, Eisen und Wald.
const START_DEPOSIT_RADIUS := 22.0
## Unter dieser Höhe liegt Wasser, darunter bis SHORE_LEVEL Ufer.
const WATER_LEVEL := -0.38
const SHORE_LEVEL := -0.32
## Kleinere Seen (Kacheln) werden zu Erde, damit keine nutzlosen Pfützen bleiben.
const MIN_LAKE_SIZE := 60
## So weit (Kacheln) reicht das Ufer höchstens vom Wasser ins Land.
const SHORE_WIDTH := 2
## Wald: ab FOREST_EDGE steht Wald, mit Dichte von FOREST_DENSITY.x am Rand bis .y im Inneren (FOREST_CORE).
const FOREST_EDGE := 0.24
const FOREST_CORE := 0.45
const FOREST_DENSITY := Vector2(0.45, 0.92)
## Chance für einen einzelnen Baum außerhalb des Waldes.
const LONE_TREE_CHANCE := 0.0015
## Kleinere Baumgruppen (auch schräg verbunden) verschwinden, bis auf diesen Anteil.
const MIN_GROVE_SIZE := 4
const SMALL_GROVE_KEEP_CHANCE := 0.15
## So viele Bäume stehen mindestens im Startumkreis, sonst wächst dort ein Hain.
const START_TREES := 30
## Mindestabstand zwischen den Mitten zweier Felsfelder (Anzahl und Größe je Art: "field" in
## data/deposits.json).
const FIELD_SPACING := 12.0
## Das garantierte erste Feld jeder Art und ein fehlender Starthain liegen so weit vom Startpunkt (Kacheln).
const START_SITE_DISTANCE := Vector2(12.0, 19.0)
## So oft wird nach einem Platz für ein Feld oder einen Hain gesucht, bevor er entfällt.
const SITE_TRIES := 60
## Anteil der Kacheln eines Starthains, auf denen ein Baum steht (der Rest sind Lichtungen).
const START_GROVE_DENSITY := 0.92
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
	_add_terrain(map, _make_noise(map_seed, 0.022))
	# Felsen vor dem Wald, damit _rock_nearby() nur Felsen sieht.
	var deposit_defs := GameDefs.get_instance().deposits
	for type: String in deposit_defs:
		if deposit_defs[type].has("field"):
			_add_rock_fields(map, type, deposit_defs[type]["field"], rng)
	_add_forests(map, _make_noise(map_seed + 1, 0.035), rng)
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


## Gelände aus der Höhe; Seen unter MIN_LAKE_SIZE werden zu Erde, Ufer liegt nur an Seen.
static func _add_terrain(map: MapData, ground: FastNoiseLite) -> void:
	var start := map.center()
	var heights := PackedFloat32Array()
	heights.resize(map.width * map.height)
	for y in map.height:
		for x in map.width:
			var tile := Vector2i(x, y)
			var level := ground.get_noise_2d(x, y)
			heights[y * map.width + x] = level
			# Das Startgebiet liegt nie unter Wasser.
			var dry := Vector2(tile - start).length() <= START_CLEAR_RADIUS + 4
			map.set_terrain(tile, "water" if level < WATER_LEVEL and not dry else _land_for(level))
	for lake: Array in _regions(map, "water", EDGE_NEIGHBOURS):
		if lake.size() < MIN_LAKE_SIZE:
			for tile: Vector2i in lake:
				map.set_terrain(tile, "dirt")
	var near_water := _near(map, "water", SHORE_WIDTH)
	for y in map.height:
		for x in map.width:
			var tile := Vector2i(x, y)
			if map.get_terrain(tile) != "water" and near_water.has(tile) and heights[y * map.width + x] < SHORE_LEVEL:
				map.set_terrain(tile, "sand")


static func _land_for(level: float) -> String:
	if level > 0.28:
		return "meadow"
	if level < -0.25:
		return "dirt"
	return "grass"


## Zusammenhängende Gebiete mit diesem Gelände (über die angegebenen Nachbarn).
static func _regions(map: MapData, terrain_id: String, neighbours: Array[Vector2i]) -> Array[Array]:
	var seen: Dictionary[Vector2i, bool] = {}
	var regions: Array[Array] = []
	for y in map.height:
		for x in map.width:
			var first := Vector2i(x, y)
			if seen.has(first) or map.get_terrain(first) != terrain_id:
				continue
			seen[first] = true
			var region: Array[Vector2i] = [first]
			var i := 0
			while i < region.size():
				for offset in neighbours:
					var next := region[i] + offset
					if map.in_bounds(next) and not seen.has(next) and map.get_terrain(next) == terrain_id:
						seen[next] = true
						region.append(next)
				i += 1
			regions.append(region)
	return regions


## Alle Kacheln höchstens distance Schritte (auch schräg) von diesem Gelände entfernt.
static func _near(map: MapData, terrain_id: String, distance: int) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for y in map.height:
		for x in map.width:
			if map.get_terrain(Vector2i(x, y)) != terrain_id:
				continue
			for dy in range(-distance, distance + 1):
				for dx in range(-distance, distance + 1):
					result[Vector2i(x + dx, y + dy)] = true
	return result


## Felsfelder je field["area"] Kacheln Kartenfläche mit field["size"] Kacheln; das erste liegt
## immer in Startnähe.
@warning_ignore("integer_division")
static func _add_rock_fields(map: MapData, type: String, field: Dictionary, rng: RandomNumberGenerator) -> void:
	var size := Vector2i(int(field["size"][0]), int(field["size"][1]))
	for i in maxi(1, map.width * map.height / int(field["area"])):
		for attempt in SITE_TRIES:
			var site: Vector2i
			if i == 0:
				site = _site_near_start(map, rng)
			else:
				site = Vector2i(rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
			if not _is_free_ground(map, site) or _rock_nearby(map, site):
				continue
			for tile in _grow_blob(map, site, rng.randi_range(size.x, size.y), rng):
				map.add_deposit(tile, Deposit.create(type, rng))
			break


## Ein zufälliger Platz im Abstand START_SITE_DISTANCE um den Startpunkt.
static func _site_near_start(map: MapData, rng: RandomNumberGenerator) -> Vector2i:
	var distance := rng.randf_range(START_SITE_DISTANCE.x, START_SITE_DISTANCE.y)
	return Vector2i((Vector2(map.center()) + Vector2.from_angle(rng.randf() * TAU) * distance).round())


## Ein anderes Felsfeld näher als FIELD_SPACING? (Bis hierher gibt es nur Felsen.)
static func _rock_nearby(map: MapData, site: Vector2i) -> bool:
	for tile: Vector2i in map.deposits:
		if Vector2(tile - site).length() < FIELD_SPACING:
			return true
	return false


## Begehbares Land ohne Vorkommen außerhalb des Startgebiets.
static func _is_free_ground(map: MapData, tile: Vector2i) -> bool:
	return map.in_bounds(tile) and map.is_buildable(tile) \
			and Vector2(tile - map.center()).length() > START_CLEAR_RADIUS + 1


## Ein kompakter Fleck aus bis zu size Kacheln freien Bodens um site: bevorzugt wächst er dort,
## wo schon viele Nachbarn dazugehören, damit er rund statt fransig wird.
static func _grow_blob(map: MapData, site: Vector2i, size: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var blob: Array[Vector2i] = [site]
	while blob.size() < size:
		var best: Array[Vector2i] = []
		var best_score := -1.0
		for tile in blob:
			for offset in EDGE_NEIGHBOURS:
				var next := tile + offset
				if blob.has(next) or best.has(next) or not _is_free_ground(map, next):
					continue
				var score := rng.randf() * 1.5
				for around in ALL_NEIGHBOURS:
					if blob.has(next + around):
						score += 1.0
				if score > best_score:
					best = [next]
					best_score = score
		if best.is_empty():
			break
		blob.append(best[0])
	return blob


## Wälder aus Rauschen, wenige Einzelbäume; kleine Grüppchen verschwinden wieder. Im Startumkreis
## steht immer Wald.
static func _add_forests(map: MapData, forest: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	var trees: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var tile := Vector2i(x, y)
			# Bäume stehen auch am Ufer, nur nicht im Wasser.
			if map.get_terrain(tile) == "water" or map.get_deposit(tile) != null \
					or Vector2(tile - map.center()).length() <= START_CLEAR_RADIUS + 1:
				continue
			var density := forest.get_noise_2d(x, y)
			var chance := LONE_TREE_CHANCE
			if density > FOREST_EDGE:
				chance = remap(clampf(density, FOREST_EDGE, FOREST_CORE), FOREST_EDGE, FOREST_CORE,
						FOREST_DENSITY.x, FOREST_DENSITY.y)
			if rng.randf() < chance:
				trees.append(tile)
	var planted: Dictionary[Vector2i, bool] = {}
	for tile in trees:
		planted[tile] = true
	for tile in trees:
		if planted.has(tile) and _group_size(planted, tile, MIN_GROVE_SIZE) < MIN_GROVE_SIZE \
				and rng.randf() >= SMALL_GROVE_KEEP_CHANCE:
			planted.erase(tile)
	for tile in trees:
		if planted.has(tile):
			map.add_deposit(tile, Deposit.create("tree", rng))
	_ensure_trees_near_start(map, rng)


## Größe der Gruppe um tile (auch schräg verbunden), aber höchstens limit – mehr muss keiner wissen.
static func _group_size(tiles: Dictionary[Vector2i, bool], tile: Vector2i, limit: int) -> int:
	var group: Array[Vector2i] = [tile]
	var i := 0
	while i < group.size() and group.size() < limit:
		for offset in ALL_NEIGHBOURS:
			var next := group[i] + offset
			if tiles.has(next) and not group.has(next):
				group.append(next)
		i += 1
	return group.size()


static func _ensure_trees_near_start(map: MapData, rng: RandomNumberGenerator) -> void:
	var start := map.center()
	var count := 0
	for tile in map.deposits:
		if map.deposits[tile].type == "tree" and Vector2(tile - start).length() <= START_DEPOSIT_RADIUS:
			count += 1
	if count >= START_TREES:
		return
	for attempt in SITE_TRIES:
		var site := _site_near_start(map, rng)
		if not _is_free_ground(map, site):
			continue
		for tile in _grow_blob(map, site, START_TREES, rng):
			# Lichtungen, damit der Hain wie Wald und nicht wie eine Hecke aussieht.
			if rng.randf() < START_GROVE_DENSITY:
				map.add_deposit(tile, Deposit.create("tree", rng))
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
