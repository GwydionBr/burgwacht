extends TestCase
## Verdeckung von Figuren durch Gebäudeblöcke (BuildingView.covers()). Bergfried (4×4) bei
## (10, 10); die Figur hat die Klickfläche von FigureView um ihren Fußpunkt.

const KEEP_ORIGIN := Vector2i(10, 10)


func _covers(type_id: String, tile: Vector2i) -> bool:
	var foot := Iso.tile_to_world(tile)
	var rect := Rect2(foot + FigureView.HIT_RECT.position, FigureView.HIT_RECT.size)
	return BuildingView.covers(type_id, KEEP_ORIGIN, rect, foot.y)


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
