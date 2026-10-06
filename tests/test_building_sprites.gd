extends TestCase
## Varianten aus Kachelpositionen und Flammenbilder aus Spielzeit, ohne Zeichnen.


func test_house_variants_are_stable_and_both_occur() -> void:
	assert_eq(BuildingSprites.variant(Vector2i(10, 10), 2), 0, "gleiche Kachel:")
	assert_eq(BuildingSprites.variant(Vector2i(11, 10), 2), 1, "benachbarte Kachel:")
	assert_eq(BuildingSprites.variant(Vector2i(10, 10), 2), 0, "unverändert:")


func test_flame_loops_from_simulation_seconds() -> void:
	var entry := {"sprite": "buildings/campfire", "sprite_animation": {"frames": 4, "fps": 6}}
	assert_eq(BuildingSprites.animation_path(entry, 0.0), "res://assets/sprites/buildings/campfire_flame_0.png", "Start:")
	assert_eq(BuildingSprites.animation_path(entry, 0.5), "res://assets/sprites/buildings/campfire_flame_3.png", "Spielzeit:")
	assert_eq(BuildingSprites.animation_path(entry, 0.5), "res://assets/sprites/buildings/campfire_flame_3.png", "Pause:")
	assert_eq(BuildingSprites.animation_path(entry, 1.0), "res://assets/sprites/buildings/campfire_flame_2.png", "Zeitraffer:")


func test_walkway_uses_rendered_floor_and_block_height_without_sprite() -> void:
	var entry := {"sprite": "buildings/wall", "height": 28, "sprite_walk_height": 25.221374}
	assert_eq(BuildingSprites.walk_height(entry), 25.221374, "Standfläche unter den Zinnen:")
	entry["sprite"] = "buildings/missing_wall"
	assert_eq(BuildingSprites.walk_height(entry), 28.0, "Block ohne Bild:")
	entry.erase("sprite_walk_height")
	assert_eq(BuildingSprites.walk_height(entry), 28.0, "Bisherige Daten:")
