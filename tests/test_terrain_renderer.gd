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
