extends TestCase


func test_tile_world_roundtrip() -> void:
	for y in range(-5, 20):
		for x in range(-5, 20):
			var tile := Vector2i(x, y)
			assert_eq(Iso.world_to_tile(Iso.tile_to_world(tile)), tile, "Kachel %s:" % tile)


func test_points_inside_diamond_belong_to_tile() -> void:
	var tile := Vector2i(3, 7)
	var c := Iso.tile_to_world(tile)
	for offset in [Vector2(0, -15), Vector2(30, 0), Vector2(0, 15), Vector2(-30, 0), Vector2(14, 7)]:
		assert_eq(Iso.world_to_tile(c + offset), tile, "Versatz %s:" % offset)


func test_points_outside_diamond_belong_to_neighbours() -> void:
	var c := Iso.tile_to_world(Vector2i(3, 7))
	assert_eq(Iso.world_to_tile(c + Vector2(0, 17)), Vector2i(4, 8), "unten:")
	assert_eq(Iso.world_to_tile(c + Vector2(17, -9)), Vector2i(3, 6), "oben rechts:")
