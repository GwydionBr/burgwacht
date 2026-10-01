extends TestCase

const SIZE := 60


func test_same_seed_gives_same_map() -> void:
	var a := MapGenerator.generate(42, SIZE, SIZE)
	var b := MapGenerator.generate(42, SIZE, SIZE)
	assert_eq(a.resources.keys(), b.resources.keys(), "Rohstoff-Positionen:")
	for y in SIZE:
		for x in SIZE:
			if a.get_terrain(Vector2i(x, y)) != b.get_terrain(Vector2i(x, y)):
				assert_true(false, "Gelände unterscheidet sich bei (%d, %d)" % [x, y])
				return


func test_start_area_is_free_and_dry() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		var start := map.center()
		for tile in map.resources:
			assert_true(Vector2(tile - start).length() > MapGenerator.START_CLEAR_RADIUS,
				"Seed %d: Rohstoff im Startgebiet bei %s" % [map_seed, tile])
		for y in SIZE:
			for x in SIZE:
				var tile := Vector2i(x, y)
				if Vector2(tile - start).length() <= MapGenerator.START_CLEAR_RADIUS:
					assert_true(map.is_buildable(tile), "Seed %d: Startgebiet nicht bebaubar bei %s" % [map_seed, tile])


func test_no_resources_on_water() -> void:
	for map_seed in range(1, 11):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for tile in map.resources:
			assert_true(map.get_terrain(tile) != "water", "Seed %d: Rohstoff im Wasser bei %s" % [map_seed, tile])


func test_stone_and_iron_near_start() -> void:
	for map_seed in range(1, 21):
		var map := MapGenerator.generate(map_seed, SIZE, SIZE)
		for type in ["stone", "iron"]:
			var found := false
			for tile in map.resources:
				if map.resources[tile].type == type \
						and Vector2(tile - map.center()).length() <= MapGenerator.START_RESOURCE_RADIUS:
					found = true
					break
			assert_true(found, "Seed %d: kein %s in Startnähe" % [map_seed, type])


func test_map_has_forests() -> void:
	var map := MapGenerator.generate(7, SIZE, SIZE)
	var trees := map.resources.values().filter(func(r: ResourceNode) -> bool: return r.type == "tree")
	assert_true(trees.size() > 100, "Zu wenige Bäume: %d" % trees.size())
