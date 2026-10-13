extends TestCase
## Trefferprüfung beim Roden: Die sichtbare vordere Baumkrone gewinnt vor der Bodenkachel.

const REAR := Vector2i(10, 10)
const FRONT := Vector2i(11, 11)
const CROWN_POINT := Vector2(-0.5, 308)


func _scene() -> MatchScene:
	var scene := MatchScene.new()
	# Diese Ansichten werden normalerweise in _ready() eingehängt; ohne Szene müssen sie
	# ebenfalls Kinder sein, damit free() alle beim Erzeugen angelegten Nodes freigibt.
	scene.add_child(scene._game_menu)
	scene.add_child(scene._settings_view)
	scene.add_child(scene._leave_dialog)
	scene.world = empty_world()
	assert_eq(scene.world.execute(Command.found(Vector2i(2, 2))), "")
	for tile: Vector2i in [REAR, FRONT]:
		add_deposit(scene.world, tile, "tree")
		var deposit := scene.world.map.get_deposit(tile)
		deposit.variant = 2
		var view := DepositView.new()
		view.setup(tile, deposit)
		scene.add_child(view)
		scene._deposit_views[tile] = view
	return scene


func test_visible_front_tree_wins_over_rear_ground_tile() -> void:
	var scene := _scene()
	assert_eq(Iso.world_to_tile(CROWN_POINT), REAR, "Bodenkachel hinter der Baumkrone:")
	assert_true(scene._deposit_views[FRONT].hit_rect().has_point(CROWN_POINT), "Klick trifft vordere Krone:")
	assert_eq(scene._clearing_tile_at(CROWN_POINT), FRONT, "Sichtbarer Baum muss beim Markieren und Entfernen gewinnen:")
	scene.free()


func test_ground_tile_remains_fallback_outside_tree_image() -> void:
	var scene := _scene()
	var point := Iso.tile_to_world(FRONT) + Vector2(24, 0)
	assert_eq(Iso.world_to_tile(point), FRONT)
	assert_false(scene._deposit_views[FRONT].hit_rect().has_point(point), "Neben dem schmalen Baumstamm:")
	assert_eq(scene._clearing_tile_at(point), FRONT, "Baum über seine Kachel weiterhin wählbar:")
	scene.free()


func test_empty_point_selects_no_tree() -> void:
	var scene := _scene()
	assert_eq(scene._clearing_tile_at(Vector2(400, 400)), GameWorld.NO_SITE)
	scene.free()
