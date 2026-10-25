extends TestCase
## Geländeübergänge und Varianten über die öffentliche Auswahl der Ansicht, ohne Grafik.


func test_transition_uses_edges_but_not_diagonal_neighbors() -> void:
	var map := MapData.new(3, 3)
	map.set_terrain(Vector2i(1, 0), "sand")
	map.set_terrain(Vector2i(2, 1), "sand")
	map.set_terrain(Vector2i(0, 2), "sand")
	assert_eq(TerrainRenderer.transition_mask(map, Vector2i(1, 1), "sand"), 3, "Obere und rechte Kante:")


func test_position_variants_survive_reload() -> void:
	var map := MapData.new(3, 3)
	var loaded := MapData.from_data(map.to_data())
	var before: Array[int] = []
	var after: Array[int] = []
	for y in map.height:
		for x in map.width:
			var tile := Vector2i(x, y)
			before.append(TerrainRenderer.variant_index(tile, 4))
	for y: int in loaded.height:
		for x: int in loaded.width:
			after.append(TerrainRenderer.variant_index(Vector2i(x, y), 4))
	assert_eq(before, [0, 1, 2, 3, 3, 3, 2, 1, 0], "Verteilte Varianten:")
	assert_eq(before, after, "Varianten nach Laden:")
	assert_eq(loaded.get_terrain(Vector2i(1, 1)), "grass", "Gelände:")
	assert_eq(TerrainRenderer.variant_index(Vector2i(0, 0), 4), 0, "Erste Variante:")
	assert_eq(TerrainRenderer.variant_index(Vector2i(1, 0), 4), 1, "Zweite Variante:")


func test_transition_includes_south_and_west_and_ignores_map_border() -> void:
	var map := MapData.new(2, 2)
	map.set_terrain(Vector2i(0, 1), "sand")
	map.set_terrain(Vector2i(1, 0), "sand")
	assert_eq(TerrainRenderer.transition_mask(map, Vector2i(1, 1), "sand"), 9, "Nord und West:")
	assert_eq(TerrainRenderer.transition_mask(map, Vector2i(0, 0), "sand"), 6, "Ost und Süd:")


func test_three_terrains_keep_each_transition_and_diagonal_corner() -> void:
	var map := MapData.new(3, 3)
	map.set_terrain(Vector2i(1, 0), "sand")
	map.set_terrain(Vector2i(2, 1), "water")
	map.set_terrain(Vector2i(0, 2), "dirt")
	var layers: Dictionary = TerrainRenderer.transition_layers(map, Vector2i(1, 1))
	assert_eq(layers.get("sand", 0), 1, "Ufer im Norden:")
	assert_eq(layers.get("water", 0), 2, "Wasser im Osten:")
	assert_eq(layers.get("dirt", 0), 64, "Erde an der südwestlichen Ecke:")


func test_transition_is_drawn_only_on_lower_priority_terrain() -> void:
	var map := MapData.new(2, 1)
	map.set_terrain(Vector2i(1, 0), "sand")
	assert_eq(TerrainRenderer.transition_layers(map, Vector2i(1, 0)), {}, "Keine doppelte Naht:")


## Der Boden ist in Blöcke geteilt, die jede Kachel genau einmal abdecken (auch am Rand, wenn die
## Karte kein Vielfaches der Blockgröße ist).
func test_chunks_cover_every_tile_once() -> void:
	var map := MapData.new(TerrainRenderer.CHUNK_SIZE * 2 + 3, TerrainRenderer.CHUNK_SIZE + 1)
	var terrain := TerrainRenderer.new()
	terrain.show_map(map)
	var covered: Dictionary[Vector2i, int] = {}
	for chunk: TerrainRenderer.Chunk in terrain.get_children():
		for y in range(chunk.tiles.position.y, chunk.tiles.end.y):
			for x in range(chunk.tiles.position.x, chunk.tiles.end.x):
				covered[Vector2i(x, y)] = covered.get(Vector2i(x, y), 0) + 1
	assert_eq(terrain.get_child_count(), 6, "Blöcke:")
	assert_eq(covered.size(), map.width * map.height, "Abgedeckte Kacheln:")
	assert_true(covered.values().all(func(count: int) -> bool: return count == 1), "Jede genau einmal")
	terrain.free()


## Die Zeichenschichten bleiben getrennt: alle Böden unter allen Übergängen, alles unter der Kartenkante.
func test_terrain_priorities_fit_between_the_layers() -> void:
	var terrain_defs := GameDefs.get_instance().terrain
	for terrain_id: String in terrain_defs:
		var priority := int(terrain_defs[terrain_id].get("sprite_priority", 0))
		assert_true(priority >= 0 and priority < -TerrainRenderer.BASE_LAYER,
				"%s: Rang %d unter %d" % [terrain_id, priority, -TerrainRenderer.BASE_LAYER])
		assert_true(priority < TerrainRenderer.EDGE_LAYER, "%s unter der Kartenkante" % terrain_id)
