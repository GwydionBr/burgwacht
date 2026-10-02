class_name MapGenerator
extends RefCounted
## Erzeugt eine zufällige Karte aus einem Seed. Gleicher Seed ergibt die gleiche Karte.

## Um den Startpunkt bleibt Platz für den Bergfried.
const START_CLEAR_RADIUS := 7.0
## In diesem Umkreis gibt es garantiert Stein und Eisen.
const START_DEPOSIT_RADIUS := 22.0


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

	for type in ["stone", "iron"]:
		_ensure_near_start(map, type, rng)
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
	if forest > 0.1 and rng.randf() < remap(forest, 0.1, 0.5, 0.4, 0.95):
		return "tree"
	if rng.randf() < 0.012:
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
