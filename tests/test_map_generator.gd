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
		for type in ["stone", "iron"]:
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
