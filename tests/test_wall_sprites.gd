extends TestCase
## Mauerarme folgen allen benachbarten Wehrgangkacheln, auch den Außenkacheln eines Turms.


func test_corner_and_diagonal_neighbors_select_only_their_arms() -> void:
	var entry := {"sprite": "buildings/wall", "sprite_connections": true}
	var neighbors: Array[Vector2i] = [Vector2i(11, 10), Vector2i(10, 9), Vector2i(9, 11)]
	assert_eq(WallSprites.paths(entry, Vector2i(10, 10), neighbors), [
		"res://assets/sprites/buildings/wall.png",
		"res://assets/sprites/buildings/wall_arm_0.png",
		"res://assets/sprites/buildings/wall_arm_3.png",
		"res://assets/sprites/buildings/wall_arm_6.png",
	], "Ecke und diagonaler Anschluss:")


func test_cross_and_all_diagonals_connect_and_demolition_updates_selection() -> void:
	var world := empty_world("gallery")
	assert_eq(world.execute(Command.found(Vector2i(1, 1))), "", "Gründung:")
	place(world, "wall", Vector2i(10, 10))
	for tile: Vector2i in [Vector2i(11, 10), Vector2i(11, 11), Vector2i(10, 11), Vector2i(9, 11), Vector2i(9, 10), Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9)]:
		place(world, "wall", tile)
	var entry := {"sprite": "buildings/wall", "sprite_connections": true}
	assert_eq(WallSprites.paths(entry, Vector2i(10, 10), WallSprites.neighbors(world, Vector2i(10, 10))).size(), 9, "acht Arme und Pfeiler:")
	world.execute(Command.demolish(world.get_building_at(Vector2i(11, 10)).id))
	assert_false(WallSprites.paths(entry, Vector2i(10, 10), WallSprites.neighbors(world, Vector2i(10, 10))).has("res://assets/sprites/buildings/wall_arm_0.png"), "Arm verschwindet nach Abriss:")


func test_wall_connects_to_far_tile_of_tower_and_gate_but_not_stairs() -> void:
	var world := empty_world()
	place(world, "tower", Vector2i(8, 9))
	place(world, "gate", Vector2i(11, 10))
	place(world, "stairs", Vector2i(10, 11))
	var nearby := WallSprites.neighbors(world, Vector2i(10, 10))
	assert_true(nearby.has(Vector2i(9, 10)), "Turmkachel jenseits des Ursprungs:")
	assert_true(nearby.has(Vector2i(11, 10)), "Tor besitzt Wehrgang:")
	assert_false(nearby.has(Vector2i(10, 11)), "Treppe ist kein Wehrgang:")


func test_stairs_face_the_neighbor_walkway() -> void:
	var entry := {"sprite": "buildings/stairs", "sprite_variants": 8, "sprite_ramp": true}
	var nearby: Array[Vector2i] = [Vector2i(10, 11)]
	assert_eq(WallSprites.paths(entry, Vector2i(10, 10), nearby), ["res://assets/sprites/buildings/stairs_2.png"], "Aufstieg in Kachel-y:")
