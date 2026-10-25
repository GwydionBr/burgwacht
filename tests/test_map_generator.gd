extends TestCase

const SIZE := 60


func test_same_seed_gives_same_map() -> void:
	var a := MapGenerator.generate(42, SIZE, SIZE)
	var b := MapGenerator.generate(42, SIZE, SIZE)
	assert_eq(a.deposits.keys(), b.deposits.keys(), "Vorkommen-Positionen:")
	for y in SIZE:
		for x in SIZE:
			if a.get_terrain(Vector2i(x, y)) != b.get_terrain(Vector2i(x, y)):
				assert_true(false, "Gelände unterscheidet sich bei (%d, %d)" % [x, y])
				return


func test_start_area_is_free_and_dry() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		var start := map.center()
		for tile in map.deposits:
			assert_true(Vector2(tile - start).length() > MapGenerator.START_CLEAR_RADIUS,
				"Seed %d: Vorkommen im Startgebiet bei %s" % [map_seed, tile])
		for y in SIZE:
			for x in SIZE:
				var tile := Vector2i(x, y)
				if Vector2(tile - start).length() <= MapGenerator.START_CLEAR_RADIUS:
					assert_true(map.is_buildable(tile), "Seed %d: Startgebiet nicht bebaubar bei %s" % [map_seed, tile])


func test_no_deposits_on_water() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for tile in map.deposits:
			assert_true(map.get_terrain(tile) != "water", "Seed %d: Vorkommen im Wasser bei %s" % [map_seed, tile])


func test_stone_and_iron_near_start() -> void:
	for map_seed in range(1, 21):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for type: String in ["stone", "iron"]:
			var found := false
			for tile in map.deposits:
				if map.deposits[tile].type == type \
						and Vector2(tile - map.center()).length() <= MapGenerator.START_DEPOSIT_RADIUS:
					found = true
					break
			assert_true(found, "Seed %d: kein %s in Startnähe" % [map_seed, type])


func test_map_has_forests() -> void:
	var map := MapGenerator.generate(7, SIZE, SIZE)
	var trees := map.deposits.values().filter(func(deposit: Deposit) -> bool: return deposit.type == "tree")
	assert_true(trees.size() > 100, "Zu wenige Bäume: %d" % trees.size())


func _game_tiles(map: MapData) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in map.deposits:
		if map.deposits[tile].type == "game":
			tiles.append(tile)
	tiles.sort()
	return tiles


func test_game_only_on_grass() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		var tiles := _game_tiles(map)
		assert_true(not tiles.is_empty(), "Seed %d: kein Wild" % map_seed)
		for tile in tiles:
			assert_eq(map.get_terrain(tile), "grass", "Seed %d: Wild bei %s auf" % [map_seed, tile])


func test_game_comes_in_packs_of_three_to_six() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		var unvisited := _game_tiles(map)
		while not unvisited.is_empty():
			# Ein Rudel: alle verbundenen Wild-Kacheln, auch schräg – Rudel dürfen sich nicht einmal an Ecken berühren.
			var pack: Array[Vector2i] = [unvisited.pop_front()]
			var i := 0
			while i < pack.size():
				for offset in MapGenerator.ALL_NEIGHBOURS:
					var next := pack[i] + offset
					if unvisited.has(next):
						unvisited.erase(next)
						pack.append(next)
				i += 1
			assert_true(pack.size() >= 3 and pack.size() <= 6,
					"Seed %d: Rudel bei %s mit %d Kacheln" % [map_seed, pack[0], pack.size()])


func test_same_seed_gives_same_game() -> void:
	assert_eq(_game_tiles(MapGenerator.generate(42, SIZE, SIZE)), _game_tiles(MapGenerator.generate(42, SIZE, SIZE)),
			"Wild bei gleichem Seed:")
	assert_true(_game_tiles(MapGenerator.generate(42, SIZE, SIZE)) != _game_tiles(MapGenerator.generate(43, SIZE, SIZE)),
			"Anderer Seed sollte anderes Wild ergeben")


## Gebiete eines Typs (Gelände oder Vorkommen), auch schräg verbunden.
func _groups(tiles: Array[Vector2i]) -> Array[Array]:
	var unvisited: Dictionary[Vector2i, bool] = {}
	for tile in tiles:
		unvisited[tile] = true
	var groups: Array[Array] = []
	for first in tiles:
		if not unvisited.has(first):
			continue
		unvisited.erase(first)
		var group: Array[Vector2i] = [first]
		var i := 0
		while i < group.size():
			for offset in MapGenerator.ALL_NEIGHBOURS:
				var next := group[i] + offset
				if unvisited.has(next):
					unvisited.erase(next)
					group.append(next)
			i += 1
		groups.append(group)
	return groups


func _deposit_tiles(map: MapData, type: String) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in map.deposits:
		if map.deposits[tile].type == type:
			tiles.append(tile)
	return tiles


func _terrain_tiles(map: MapData, terrain_id: String) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.get_terrain(Vector2i(x, y)) == terrain_id:
				tiles.append(Vector2i(x, y))
	return tiles


func test_no_small_lakes() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, 100, 100)
		for lake in _groups(_terrain_tiles(map, "water")):
			# Schräg verbunden zählt hier mit; der Generator verbindet nur über Kanten, ein See ist
			# also mindestens so groß wie jeder seiner kantenverbundenen Teile.
			assert_true(lake.size() >= MapGenerator.MIN_LAKE_SIZE,
					"Seed %d: See bei %s mit %d Kacheln" % [map_seed, lake[0], lake.size()])


func test_shore_only_at_water() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for tile in _terrain_tiles(map, "sand"):
			var near_water := false
			for dy in range(-MapGenerator.SHORE_WIDTH, MapGenerator.SHORE_WIDTH + 1):
				for dx in range(-MapGenerator.SHORE_WIDTH, MapGenerator.SHORE_WIDTH + 1):
					var other := tile + Vector2i(dx, dy)
					if map.in_bounds(other) and map.get_terrain(other) == "water":
						near_water = true
			assert_true(near_water, "Seed %d: Ufer ohne Wasser bei %s" % [map_seed, tile])


## Stein und Eisen liegen in Feldern statt verstreut.
func test_rock_comes_in_fields() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for type: String in ["stone", "iron"]:
			for field in _groups(_deposit_tiles(map, type)):
				assert_true(field.size() >= 3, "Seed %d: %s bei %s mit %d Kacheln" % [map_seed, type, field[0], field.size()])


## Wald statt Streubäume: kaum ein Baum steht allein.
func test_few_lone_trees() -> void:
	for map_seed in range(1, 6):
		var map := MapGenerator.generate(map_seed, 100, 100)
		var trees := _deposit_tiles(map, "tree")
		var lone := _groups(trees).filter(func(group: Array) -> bool: return group.size() == 1).size()
		assert_true(lone * 100 <= trees.size(), "Seed %d: %d von %d Bäumen allein" % [map_seed, lone, trees.size()])


func test_forest_near_start() -> void:
	for map_seed in range(1, 21):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		var near := _deposit_tiles(map, "tree").filter(func(tile: Vector2i) -> bool:
			return Vector2(tile - map.center()).length() <= MapGenerator.START_DEPOSIT_RADIUS)
		assert_true(near.size() >= MapGenerator.START_TREES / 2,
				"Seed %d: nur %d Bäume in Startnähe" % [map_seed, near.size()])
