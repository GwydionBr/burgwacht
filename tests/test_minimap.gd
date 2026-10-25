extends TestCase
## Minikarte: Farben je Kachel (Gebäude vor Vorkommen vor Gelände), Umrechnung zwischen Welt und
## Minikarte und das Verschieben der Ansicht per Linksklick. Leere Testkarte (nur Wiese).

const KEEP_ORIGIN := Vector2i(2, 2)
const TREE_TILE := Vector2i(15, 15)


func _minimap(world: GameWorld) -> Minimap:
	var minimap := Minimap.new()
	minimap.size = Minimap.SIZE
	minimap.show_world(world)
	return minimap


func _pixel(minimap: Minimap, tile: Vector2i) -> Color:
	return minimap.get("_image").get_pixelv(tile)


func _color(entry: Dictionary, key := "color") -> Color:
	return Color(str(entry[key]))


func test_tiles_show_terrain_deposits_and_buildings() -> void:
	var world := empty_world()
	world.execute(Command.found(KEEP_ORIGIN))
	add_deposit(world, TREE_TILE, "tree")
	var minimap := _minimap(world)
	var defs := GameDefs.get_instance()
	assert_true(_pixel(minimap, Vector2i(15, 5)).is_equal_approx(_color(defs.terrain["grass"])), "Wiese:")
	assert_true(_pixel(minimap, TREE_TILE).is_equal_approx(_color(defs.deposits["tree"], "minimap_color")), "Baum:")
	assert_true(_pixel(minimap, KEEP_ORIGIN).is_equal_approx(_color(defs.buildings["keep"])), "Bergfried:")
	minimap.free()


func test_tiles_follow_changes() -> void:
	var world := empty_world()
	world.execute(Command.found(KEEP_ORIGIN))
	var minimap := _minimap(world)
	var grass := _color(GameDefs.get_instance().terrain["grass"])
	add_deposit(world, TREE_TILE, "tree")
	assert_false(_pixel(minimap, TREE_TILE).is_equal_approx(grass), "neuer Baum:")
	world.map.remove_deposit(TREE_TILE)
	assert_true(_pixel(minimap, TREE_TILE).is_equal_approx(grass), "gefällter Baum:")
	var id := build(world, "woodcutter", Vector2i(12, 2))
	assert_false(_pixel(minimap, Vector2i(12, 2)).is_equal_approx(grass), "neues Gebäude:")
	world.execute(Command.demolish(id))
	assert_true(_pixel(minimap, Vector2i(12, 2)).is_equal_approx(grass), "abgerissen:")
	minimap.free()


func test_map_fills_minimap_from_above_and_converts_back() -> void:
	var world := empty_world()
	var minimap := _minimap(world)
	var last := Vector2i(world.map.width - 1, world.map.height - 1)
	# Gerade von oben: Kachel (0, 0) links oben, die letzte rechts unten; die breitere Seite (20 von
	# 20×16 Kacheln) füllt die Minikarte, die andere liegt mittig.
	var tile_size := Minimap.SIZE.x / world.map.width
	var top_left := Vector2(tile_size, Minimap.SIZE.y - (world.map.height - 1) * tile_size) * 0.5
	assert_true(minimap.to_minimap(Iso.tile_to_world(Vector2i.ZERO)).is_equal_approx(top_left), "links oben:")
	assert_true(minimap.to_minimap(Iso.tile_to_world(last)).is_equal_approx(Minimap.SIZE - top_left), "rechts unten:")
	var point := Iso.tile_to_world(Vector2i(7, 3))
	assert_true(minimap.to_world(minimap.to_minimap(point)).is_equal_approx(point), "hin und zurück:")
	minimap.free()


func test_left_click_requests_focus_on_world_point() -> void:
	var world := empty_world()
	var minimap := _minimap(world)
	var requested: Array[Vector2] = []
	minimap.focus_requested.connect(func(point: Vector2) -> void: requested.append(point))
	var target := Iso.tile_to_world(Vector2i(10, 10))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = minimap.to_minimap(target)
	minimap._gui_input(click)
	assert_eq(requested.size(), 1, "Anzahl:")
	assert_true(requested[0].is_equal_approx(target), "Weltpunkt: %s" % requested[0])
	minimap.free()
