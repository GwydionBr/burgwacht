extends TestCase
## Die Spieldaten (GameDefs, data/*.json): das optionale Feld „sprite“ bei Gelände, Vorkommen,
## Gebäuden und Einheiten wird beim Laden geprüft; Fehler als deutscher Text.


func test_game_data_is_valid() -> void:
	assert_eq(GameDefs.get_instance().error, "", "Fehler der Spieldaten:")


func test_house_has_a_sprite_and_a_shadow() -> void:
	var house: Dictionary = GameDefs.get_instance().buildings["house"]
	assert_eq(GameDefs.sprite_path(house), "res://assets/sprites/buildings/house.png", "Bild:")
	assert_eq(GameDefs.shadow_path(house), "res://assets/sprites/buildings/house_shadow.png", "Schatten:")


func test_type_without_sprite_has_no_path() -> void:
	var keep: Dictionary = {"name": "Gebäude ohne Bild"}
	assert_eq(GameDefs.sprite_path(keep), "", "Bild:")
	assert_eq(GameDefs.shadow_path(keep), "", "Schatten:")


func test_missing_sprite_file_is_named() -> void:
	var entries := {"house": {"name": "Wohnhaus", "sprite": "buildings/gibt_es_nicht"}}
	assert_eq(GameDefs.sprites_error("buildings.json", entries),
			"buildings.json, „house“: Bild res://assets/sprites/buildings/gibt_es_nicht.png fehlt", "Fehler:")


func test_wrong_sprite_type_is_named() -> void:
	for value: Variant in [3, "", ["buildings/house"]]:
		var entries := {"tree": {"sprite": value}}
		assert_eq(GameDefs.sprites_error("deposits.json", entries),
				"deposits.json, „tree“: „sprite“ muss der Pfad eines Bilds sein (Text, ohne .png)", "Fehler bei %s:" % str(value))


func test_sprite_with_extension_is_rejected() -> void:
	var entries := {"house": {"sprite": "buildings/house.png"}}
	assert_eq(GameDefs.sprites_error("buildings.json", entries),
			"buildings.json, „house“: „sprite“ muss der Pfad eines Bilds sein (Text, ohne .png)", "Fehler:")


func test_entries_without_sprite_are_valid() -> void:
	assert_eq(GameDefs.sprites_error("terrain.json", {"grass": {"name": "Gras"}}), "", "Fehler:")
	assert_eq(GameDefs.sprites_error("buildings.json", {"house": {"sprite": "buildings/house"}}), "", "Fehler:")


func test_missing_shadow_file_is_named() -> void:
	# Das Schattenbild des Wohnhauses gibt es, seinen eigenen Schatten nicht.
	var entries := {"house": {"sprite": "buildings/house_shadow"}}
	assert_eq(GameDefs.sprites_error("buildings.json", entries),
			"buildings.json, „house“: Schatten res://assets/sprites/buildings/house_shadow_shadow.png fehlt", "Fehler:")


func test_sprite_variant_count_must_be_a_positive_integer() -> void:
	for value: Variant in [0, -1, 1.5, "4", true]:
		var entries := {"tree": {"sprite": "buildings/house", "sprite_variants": value}}
		assert_eq(GameDefs.sprites_error("deposits.json", entries),
				"deposits.json, „tree“: „sprite_variants“ muss eine positive ganze Zahl sein", "Fehler:")


func test_missing_variant_sprite_is_named() -> void:
	var entries := {"tree": {"sprite": "buildings/house", "sprite_variants": 3}}
	assert_eq(GameDefs.sprites_error("deposits.json", entries),
			"deposits.json, „tree“: Bild res://assets/sprites/buildings/house_2.png fehlt", "Fehler:")


func test_sprite_paths_choose_variant_and_wrap_seed() -> void:
	var entry := {"sprite": "deposits/tree", "sprite_variants": 4}
	assert_eq(GameDefs.sprite_path(entry, 5), "res://assets/sprites/deposits/tree_1.png", "Variante:")
	assert_eq(GameDefs.shadow_path(entry, 7), "res://assets/sprites/deposits/tree_3_shadow.png", "Schatten:")


func test_missing_figure_animation_frame_is_named() -> void:
	var entry := {"sprite": "buildings/house", "animations": {"idle": {"frames": 1, "fps": 1}, "walk": {"frames": 1, "fps": 1}}}
	assert_eq(GameDefs.sprites_error("units.json", {"resident": entry}),
		"units.json, „resident“: Animationsbild res://assets/sprites/buildings/house_idle_0_0.png fehlt", "Fehler:")


func test_terrain_transition_requires_a_known_neighbor_type() -> void:
	var entries: Dictionary = {"grass": {"sprite": "terrain/grass", "sprite_transition": "missing"}}
	assert_eq(GameDefs.sprites_error("terrain.json", entries),
			"terrain.json, „grass“: „sprite_transition“ muss ein anderes bekanntes Gelände nennen", "Fehler:")


func test_optional_attack_animation_is_validated() -> void:
	var resident: Dictionary = GameDefs.get_instance().units["resident"].duplicate(true)
	resident["animations"]["attack"] = {"frames": 1, "fps": 8}
	assert_eq(GameDefs.sprites_error("units.json", {"resident": resident}),
		"units.json, „resident“: Animationsbild res://assets/sprites/units/resident_attack_0_0.png fehlt", "Angriff wird geprüft:")


func test_missing_terrain_overlay_is_named() -> void:
	var entries: Dictionary = {"grass": {"sprite": "terrain/grass", "sprite_overlay": "terrain/missing"}}
	assert_eq(GameDefs.sprites_error("terrain.json", entries),
		"terrain.json, „grass“: Übergangsbild res://assets/sprites/terrain/missing.png fehlt", "Fehler:")


func test_wrong_terrain_overlay_type_is_named() -> void:
	var entries: Dictionary = {"grass": {"sprite": "terrain/grass", "sprite_overlay": 2}}
	assert_eq(GameDefs.sprites_error("terrain.json", entries),
		"terrain.json, „grass“: „sprite_overlay“ muss der Pfad eines Bilds sein (Text, ohne .png)", "Fehler:")


func test_terrain_priority_must_be_a_nonnegative_integer() -> void:
	for value: Variant in [-1, 0.5, "2", true]:
		var entries := {"grass": {"sprite": "terrain/grass", "sprite_priority": value}}
		assert_eq(GameDefs.sprites_error("terrain.json", entries),
			"terrain.json, „grass“: „sprite_priority“ muss eine nichtnegative ganze Zahl sein", "Fehler:")


func test_missing_building_flame_frame_is_named() -> void:
	var entry := {"sprite": "buildings/house", "sprite_animation": {"frames": 2, "fps": 6}}
	assert_eq(GameDefs.sprites_error("buildings.json", {"campfire": entry}),
		"buildings.json, „campfire“: Animationsbild res://assets/sprites/buildings/house_flame_0.png fehlt", "Fehler:")


func test_wall_sprite_requires_all_connection_images() -> void:
	var entries := {"missing_arms": {"sprite": "buildings/house", "sprite_connections": true}}
	assert_true(GameDefs.sprites_error("buildings.json", entries) != "", "Mauerarme fehlen:")


func test_sprite_walk_height_must_be_positive_finite_and_below_top() -> void:
	for floor_height: float in [-1.0, 0.0, 29.0, INF, NAN]:
		var entries := {"bad_floor": {"sprite": "buildings/wall", "height": 28, "sprite_walk_height": floor_height}}
		assert_true(GameDefs.sprites_error("buildings.json", entries) != "", "Ungültige Standhöhe:")


func test_goods_optional_sprite_is_validated_during_loading() -> void:
	var defs := GameDefs.get_instance()
	var saved: Dictionary = defs.goods["wood"].duplicate(true)
	defs.goods["wood"]["sprite"] = 17
	assert_eq(defs.validate_sprites(), "goods.json, „wood“: „sprite“ muss der Pfad eines Bilds sein (Text, ohne .png)", "Ungültiger Warenpfad:")
	defs.goods["wood"]["sprite"] = "goods/missing"
	assert_eq(defs.validate_sprites(), "goods.json, „wood“: Bild res://assets/sprites/goods/missing.png fehlt", "Fehlendes Warenbild:")
	defs.goods["wood"] = saved
