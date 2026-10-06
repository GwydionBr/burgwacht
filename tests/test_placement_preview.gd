extends TestCase
## Die Vorschau verbindet gültige Mauerstücke mit bestehenden Wehrgängen, nicht mit gesperrten Kacheln.


func test_line_connects_valid_planned_tiles_and_existing_walkways_only() -> void:
	var world := empty_world("gallery")
	place(world, "tower", Vector2i(8, 9))
	var preview := PlacementPreview.new()
	preview.world = world
	var plan: Dictionary[Vector2i, String] = {
		Vector2i(10, 10): "", Vector2i(11, 10): "", Vector2i(10, 11): "Belegt",
	}
	preview.show_line("wall", plan)
	assert_eq(preview.sprite_paths("wall", Vector2i(10, 10)), [
		"res://assets/sprites/buildings/wall.png",
		"res://assets/sprites/buildings/wall_arm_0.png",
		"res://assets/sprites/buildings/wall_arm_4.png",
		"res://assets/sprites/buildings/wall_arm_5.png",
	], "Gültige Nachbarn und beide Turmkacheln:")
	preview.free()


func test_preview_uses_position_variant_and_falls_back_without_sprite() -> void:
	var preview := PlacementPreview.new()
	preview.show_parts([["house", Vector2i(1, 0)]] as Array[Array], true)
	assert_eq(preview.sprite_paths("house", Vector2i(1, 0)), ["res://assets/sprites/buildings/house_1.png"], "Zweite Wohnhausvariante:")
	var entry: Dictionary = GameDefs.get_instance().buildings["house"]
	var original: String = entry["sprite"]
	entry.erase("sprite")
	assert_true(preview.sprite_paths("house", Vector2i(1, 0)).is_empty(), "Block ohne Sprite:")
	entry["sprite"] = "buildings/does_not_exist"
	assert_true(preview.sprite_paths("house", Vector2i(1, 0)).is_empty(), "Block bei fehlendem Bild:")
	entry["sprite"] = original
	preview.free()
