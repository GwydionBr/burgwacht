extends TestCase
## Verdeckung von Figuren durch Gebäudeblöcke (BuildingView.covers_figure()). Bergfried (4×4) bei
## (10, 10); die Figur hat die Klickfläche von FigureView um ihren Fußpunkt.

const KEEP_ORIGIN := Vector2i(10, 10)


func _covers(type_id: String, tile: Vector2i, without_sprite: bool = false) -> bool:
	var definition: Dictionary = GameDefs.get_instance().buildings[type_id]
	var saved_sprite: Variant = definition.get("sprite")
	if without_sprite:
		definition.erase("sprite")
	var foot := Iso.tile_to_world(tile)
	var rect := Rect2(foot + FigureView.HIT_RECT.position, FigureView.HIT_RECT.size)
	var view := BuildingView.new()
	view.setup(Building.create(1, type_id, KEEP_ORIGIN))
	var covered := view.covers_figure(rect, foot.y)
	view.free()
	if without_sprite and saved_sprite != null:
		definition["sprite"] = saved_sprite
	return covered


func test_figure_behind_keep_is_covered() -> void:
	assert_true(_covers("keep", Vector2i(11, 9)), "hinter der Nordseite:")
	assert_true(_covers("keep", Vector2i(9, 11)), "hinter der Westseite:")


func test_figure_in_front_of_keep_is_not_covered() -> void:
	assert_true(not _covers("keep", Vector2i(12, 14)), "vor der linken Wand:")
	assert_true(not _covers("keep", Vector2i(14, 12)), "vor der rechten Wand:")


func test_figure_beside_keep_is_not_covered() -> void:
	assert_true(not _covers("keep", Vector2i(20, 8)), "weit rechts dahinter:")


func test_campfire_covers_nothing() -> void:
	assert_true(not _covers("campfire", Vector2i(10, 9)), "hinter dem Lagerfeuer:")


## Gebäude mit Sprite verdecken nach dem Umriss ihres Bilds, nicht nach dem Block: Über dem Block
## eines gleich großen Gebäudes ohne Sprite (Jäger) ragt das Dach des Wohnhauses noch auf.
func test_figure_behind_house_roof_is_covered() -> void:
	var behind_roof := Vector2i(8, 9)
	assert_true(_covers("house", behind_roof), "hinter dem Dach des Wohnhauses:")
	assert_false(_covers("hunter", behind_roof, true), "über dem Block des Jägers:")


func test_figure_in_front_of_house_is_not_covered() -> void:
	assert_false(_covers("house", Vector2i(11, 13)), "vor der linken Wand:")
	assert_false(_covers("house", Vector2i(13, 11)), "vor der rechten Wand:")


func test_house_shows_its_sprite_and_shadow() -> void:
	var shadows := Node2D.new()
	var view := BuildingView.new()
	view.setup(Building.create(1, "house", KEEP_ORIGIN), shadows)
	var sprite := view.get_sprite()
	assert_true(sprite != null, "Bild fehlt")
	assert_eq(sprite.texture.resource_path, "res://assets/sprites/buildings/house.png", "Bild:")
	assert_eq(sprite.global_position, Iso.point_to_world(Vector2(KEEP_ORIGIN) + Vector2(0.5, 0.5)), "Mitte des Bilds:")
	assert_eq(shadows.get_child_count(), 1, "Schatten in der Schattenschicht:")
	var shadow: Sprite2D = shadows.get_child(0)
	assert_eq(shadow.texture.resource_path, "res://assets/sprites/buildings/house_shadow.png", "Schatten:")
	assert_eq(shadow.global_position, sprite.global_position, "Schatten an derselben Stelle:")
	view.free()
	assert_true(shadow.is_queued_for_deletion(), "Schatten verschwindet mit dem Gebäude")
	shadows.free()


func test_type_without_sprite_has_no_sprite() -> void:
	var definition: Dictionary = GameDefs.get_instance().buildings["hunter"]
	var saved_sprite: Variant = definition.get("sprite")
	definition.erase("sprite")
	var view := BuildingView.new()
	view.setup(Building.create(1, "hunter", KEEP_ORIGIN))
	assert_true(view.get_sprite() == null, "Jäger ohne Sprite:")
	view.free()
	if saved_sprite != null:
		definition["sprite"] = saved_sprite


## Ein zweites setup() ersetzt Bild und Schatten, statt die alten liegen zu lassen.
func test_second_setup_replaces_shadow() -> void:
	var shadows := Node2D.new()
	var view := BuildingView.new()
	view.setup(Building.create(1, "house", KEEP_ORIGIN), shadows)
	var first_shadow: Sprite2D = shadows.get_child(0)
	var first_sprite := view.get_sprite()
	view.setup(Building.create(1, "house", KEEP_ORIGIN), shadows)
	assert_true(first_shadow.is_queued_for_deletion(), "alter Schatten verschwindet:")
	assert_true(first_sprite.is_queued_for_deletion(), "altes Bild verschwindet:")
	var remaining := 0
	for child in shadows.get_children():
		if not child.is_queued_for_deletion():
			remaining += 1
	assert_eq(remaining, 1, "ein Schatten in der Schattenschicht:")
	view.free()
	shadows.free()


## Fehlt die Bilddatei, erscheint der Block wie bei einem Typ ohne Sprite.
func test_missing_sprite_file_falls_back_to_block() -> void:
	var hunter: Dictionary = GameDefs.get_instance().buildings["hunter"]
	var saved_sprite: Variant = hunter.get("sprite")
	hunter["sprite"] = "buildings/gibt_es_nicht"
	var shadows := Node2D.new()
	var view := BuildingView.new()
	view.setup(Building.create(1, "hunter", KEEP_ORIGIN), shadows)
	var sprite := view.get_sprite()
	var shadow_count := shadows.get_child_count()
	view.free()
	shadows.free()
	var covered := _covers("hunter", Vector2i(9, 9))
	if saved_sprite != null:
		hunter["sprite"] = saved_sprite
	else:
		hunter.erase("sprite")
	assert_true(sprite == null, "kein Bild:")
	assert_eq(shadow_count, 0, "kein Schatten:")
	assert_true(covered, "der Block verdeckt die Figur dahinter:")


func test_wall_arm_changes_occlusion_after_neighbor_build_and_removal() -> void:
	var world := empty_world("gallery")
	assert_eq(world.execute(Command.found(Vector2i(1, 1))), "", "Gründung:")
	var building := world.get_building(place(world, "wall", KEEP_ORIGIN))
	var shadows := Node2D.new()
	var view := BuildingView.new()
	view.setup(building, shadows, null, world)
	var center := Iso.tile_to_world(KEEP_ORIGIN)
	var behind_arm := Rect2(center + Vector2(-25, -22), Vector2(3, 3))
	assert_false(view.covers_figure(behind_arm, center.y - 10), "ohne Arm:")
	var neighbor := place(world, "wall", KEEP_ORIGIN + Vector2i(-1, 1))
	view.refresh_connections()
	assert_true(view.covers_figure(behind_arm, center.y - 10), "Arm verdeckt ebenfalls:")
	assert_eq(world.execute(Command.demolish(neighbor)), "", "Abriss:")
	view.refresh_connections()
	assert_false(view.covers_figure(behind_arm, center.y - 10), "Armumriss nach Abriss entfernt:")
	view.free()
	shadows.free()
