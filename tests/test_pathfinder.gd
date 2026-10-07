extends TestCase
## Einzeltests der Wegfindung (A*, 8 Richtungen) auf einem kleinen Raster.
## Positionen sind Vector3i: Kachel (x, y) und Ebene (z).

const GROUND := Figure.Level.GROUND
const SIZE := Vector2i(10, 10)

## Gesperrte Kacheln des Testrasters.
var _blocked: Dictionary[Vector2i, bool] = {}


func _walkable(position: Vector3i) -> bool:
	var tile := Vector2i(position.x, position.y)
	return position.z == GROUND and tile.x >= 0 and tile.y >= 0 and tile.x < SIZE.x and tile.y < SIZE.y \
			and not _blocked.has(tile)


func _path(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	return Pathfinder.find_path(Vector3i(from.x, from.y, GROUND), Vector3i(to.x, to.y, GROUND), _walkable)


func _tiles(path: Array[Vector3i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for position in path:
		result.append(Vector2i(position.x, position.y))
	return result


func _block(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		_blocked[tile] = true


func test_straight_line() -> void:
	var expected: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	assert_eq(_tiles(_path(Vector2i(1, 1), Vector2i(4, 1))), expected, "Gerader Weg:")


func test_diagonal_on_open_field() -> void:
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
	assert_eq(_tiles(_path(Vector2i(0, 0), Vector2i(3, 3))), expected, "Schräg:")


func test_start_is_goal() -> void:
	assert_eq(_tiles(_path(Vector2i(2, 2), Vector2i(2, 2))), [Vector2i(2, 2)] as Array[Vector2i], "Nur der Start:")


func test_detour_around_wall() -> void:
	# Mauer bei x = 3 von y = 0 bis 4; der Weg führt unten herum.
	_block([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	var path := _path(Vector2i(1, 1), Vector2i(5, 1))
	assert_eq(path.size(), 11, "Kacheln auf dem Umweg (samt Start):")
	assert_true(_tiles(path).has(Vector2i(3, 5)), "Umweg unter der Mauer hindurch")
	for tile in _tiles(path):
		assert_true(not _blocked.has(tile), "%s ist gesperrt" % str(tile))
	# Je 3 gerade + 1 schräg hinab und hinauf, 2 gerade unter der Mauer.
	var length := Pathfinder.path_length(path)
	assert_true(is_equal_approx(length, 8.0 + 2.0 * sqrt(2.0)), "Länge des Umwegs: %f" % length)


func test_no_corner_cutting() -> void:
	# Schräg von (1, 1) nach (2, 2) nur, wenn (2, 1) und (1, 2) frei sind.
	_block([Vector2i(2, 1)])
	var expected: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]
	assert_eq(_tiles(_path(Vector2i(1, 1), Vector2i(2, 2))), expected, "Um die Ecke statt schräg:")


func test_no_diagonal_between_two_blocked_tiles() -> void:
	# Zwei schräg aneinanderstoßende Hindernisse bilden eine dichte Wand.
	_block([Vector2i(1, 0), Vector2i(0, 1)])
	assert_eq(_path(Vector2i(0, 0), Vector2i(1, 1)).size(), 0, "Durch die Lücke:")


func test_unreachable_goal() -> void:
	# Ziel ringsum eingeschlossen.
	_block([
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(4, 5),
		Vector2i(6, 5), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
	])
	assert_eq(_path(Vector2i(0, 0), Vector2i(5, 5)).size(), 0, "Weg ins Eingeschlossene:")


func test_blocked_goal_is_unreachable() -> void:
	_block([Vector2i(5, 5)])
	assert_eq(_path(Vector2i(0, 0), Vector2i(5, 5)).size(), 0, "Weg auf ein Hindernis:")


func test_start_may_be_blocked() -> void:
	# Wer auf einer inzwischen gesperrten Kachel steht, kommt trotzdem weg.
	_block([Vector2i(1, 1)])
	assert_eq(_path(Vector2i(1, 1), Vector2i(3, 1)).size(), 3, "Weg von einer gesperrten Kachel:")


func test_tie_prefers_tile_closer_to_goal() -> void:
	# Schräg-dann-gerade und gerade-dann-schräg sind gleich lang; zuerst schräg, weil die
	# Kachel danach näher am Ziel liegt.
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)]
	assert_eq(_tiles(_path(Vector2i(0, 0), Vector2i(2, 1))), expected, "Bei Gleichstand:")


func test_same_query_gives_same_path() -> void:
	_block([Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(2, 7), Vector2i(6, 1)])
	var first := _path(Vector2i(0, 4), Vector2i(9, 4))
	for i in 5:
		assert_eq(_path(Vector2i(0, 4), Vector2i(9, 4)), first, "Durchlauf %d:" % i)


func test_path_carries_level() -> void:
	for position in _path(Vector2i(0, 0), Vector2i(3, 2)):
		assert_eq(position.z, GROUND, "Ebene von %s:" % str(position))


func _distances(from: Vector2i, max_length := INF) -> Dictionary[Vector3i, float]:
	return Pathfinder.distances(Vector3i(from.x, from.y, GROUND), _walkable, max_length)


func test_distances_match_path_lengths() -> void:
	_block([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	var distances := _distances(Vector2i(1, 1))
	assert_eq(distances[Vector3i(1, 1, GROUND)], 0.0, "Start:")
	assert_eq(distances[Vector3i(2, 1, GROUND)], 1.0, "Nachbar:")
	assert_true(is_equal_approx(distances[Vector3i(2, 2, GROUND)], sqrt(2.0)), "Schräg")
	var detour := Pathfinder.path_length(_path(Vector2i(1, 1), Vector2i(5, 1)))
	assert_true(is_equal_approx(distances[Vector3i(5, 1, GROUND)], detour), "Wie die Länge des Umwegs")
	assert_true(not distances.has(Vector3i(3, 1, GROUND)), "Gesperrte Kachel fehlt")


func test_distances_stop_at_max_length() -> void:
	var distances := _distances(Vector2i(0, 0), 2.0)
	assert_true(distances.has(Vector3i(2, 0, GROUND)), "Genau 2 entfernt ist dabei")
	assert_true(distances.has(Vector3i(1, 1, GROUND)), "√2 entfernt ist dabei")
	assert_true(not distances.has(Vector3i(3, 0, GROUND)), "3 entfernt fehlt")
	assert_true(not distances.has(Vector3i(2, 1, GROUND)), "1 + √2 entfernt fehlt")


func test_distances_skip_unreachable() -> void:
	_block([Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)])
	assert_eq(_distances(Vector2i(0, 0)).keys(), [Vector3i(0, 0, GROUND)], "Nur der Start:")


## Kachel (3, 1) wie ein Eingang: nur von (3, 2) aus zu betreten und nur dorthin zu verlassen.
func _steppable(from: Vector3i, to: Vector3i) -> bool:
	var entrance := Vector3i(3, 1, GROUND)
	var front := Vector3i(3, 2, GROUND)
	return (from != entrance or to == front) and (to != entrance or from == front)


func test_steppable_forbids_single_steps() -> void:
	var path := Pathfinder.find_path(Vector3i(2, 1, GROUND), Vector3i(4, 1, GROUND), _walkable, Callable(), _steppable)
	assert_true(not _tiles(path).has(Vector2i(3, 1)), "Nicht seitlich durch den Eingang: %s" % str(_tiles(path)))
	path = Pathfinder.find_path(Vector3i(2, 1, GROUND), Vector3i(3, 1, GROUND), _walkable, Callable(), _steppable)
	assert_eq(path[path.size() - 2], Vector3i(3, 2, GROUND), "Hinein nur von vorn:")
	var distances := Pathfinder.distances(Vector3i(2, 1, GROUND), _walkable, INF, Callable(), _steppable)
	assert_true(is_equal_approx(distances[Vector3i(3, 1, GROUND)], 1.0 + sqrt(2.0)), "Über die Kachel davor")
	assert_true(is_equal_approx(distances[Vector3i(4, 1, GROUND)], 2.0 * sqrt(2.0)), "Außen herum")


## Zusatzkosten beim Betreten (z. B. eine Mauer, die ein Feind durchbrechen kann): Diese Kacheln
## sind begehbar, kosten aber so viel mehr.
var _costs: Dictionary[Vector2i, float] = {}


## Sperrt die Kachel für _walkable() und macht sie für _walkable_or_costly() teuer.
func _set_cost(tile: Vector2i, cost: float) -> void:
	_blocked[tile] = true
	_costs[tile] = cost


func _walkable_or_costly(position: Vector3i) -> bool:
	return _walkable(position) or _costs.has(Vector2i(position.x, position.y))


## Zusatzkosten beim Schritt auf to: die Kosten dieser Kachel, egal woher.
func _extra_cost(_from: Vector3i, to: Vector3i) -> float:
	return _costs.get(Vector2i(to.x, to.y), 0.0)


func _costly_path(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	return Pathfinder.find_path(Vector3i(from.x, from.y, GROUND), Vector3i(to.x, to.y, GROUND), _walkable_or_costly,
			Callable(), Callable(), _extra_cost)


func _costly_distances(from: Vector2i) -> Dictionary[Vector3i, float]:
	return Pathfinder.distances(Vector3i(from.x, from.y, GROUND), _walkable_or_costly, INF, Callable(), Callable(),
			_extra_cost)


## Mauer bei x = 3 von y = 0 bis 4 (wie test_detour_around_wall), jede Kachel mit diesen Zusatzkosten.
func _costly_wall(cost: float) -> void:
	for y in 5:
		_set_cost(Vector2i(3, y), cost)


func test_cheap_extra_cost_breaks_through() -> void:
	_costly_wall(2.0)
	var path := _costly_path(Vector2i(1, 1), Vector2i(5, 1))
	var expected: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	assert_eq(_tiles(path), expected, "Gerade durch die Mauer:")
	assert_true(is_equal_approx(_costly_distances(Vector2i(1, 1))[Vector3i(5, 1, GROUND)], 6.0), "4 Schritte + 2")


func test_expensive_extra_cost_takes_the_detour() -> void:
	_costly_wall(10.0)
	var path := _costly_path(Vector2i(1, 1), Vector2i(5, 1))
	assert_true(_tiles(path).has(Vector2i(3, 5)), "Umweg unter der Mauer hindurch: %s" % str(_tiles(path)))
	assert_true(is_equal_approx(_costly_distances(Vector2i(1, 1))[Vector3i(5, 1, GROUND)], 8.0 + 2.0 * sqrt(2.0)),
			"Länge des Umwegs")


func test_equal_extra_costs_are_deterministic() -> void:
	# Ganze Spalte x = 3 dicht, zwei gleich teure Lücken symmetrisch zum Weg.
	for y in SIZE.y:
		_blocked[Vector2i(3, y)] = true
	_set_cost(Vector2i(3, 0), 3.0)
	_set_cost(Vector2i(3, 2), 3.0)
	var first := _costly_path(Vector2i(1, 1), Vector2i(5, 1))
	assert_true(_tiles(first).has(Vector2i(3, 0)) != _tiles(first).has(Vector2i(3, 2)), "Durch genau eine Lücke")
	for i in 3:
		assert_eq(_costly_path(Vector2i(1, 1), Vector2i(5, 1)), first, "Gleicher Weg:")
	# Gerade ist oben vor unten (Reihenfolge der Nachbarn): die obere Lücke.
	assert_true(_tiles(first).has(Vector2i(3, 0)), "Obere Lücke: %s" % str(_tiles(first)))


func test_costly_tiles_count_as_corners() -> void:
	# Zwei schräg aneinanderstoßende Mauerkacheln: Schräg hindurch ginge es kostenlos, das ist
	# verboten; eine von beiden muss durchbrochen werden.
	_set_cost(Vector2i(1, 0), 5.0)
	_set_cost(Vector2i(0, 1), 5.0)
	var path := _costly_path(Vector2i(0, 0), Vector2i(1, 1))
	assert_eq(path.size(), 3, "Über eine der Mauerkacheln: %s" % str(_tiles(path)))
	assert_true(is_equal_approx(_costly_distances(Vector2i(0, 0))[Vector3i(1, 1, GROUND)], 7.0), "2 Schritte + 5")


func test_extra_cost_depends_on_where_the_step_comes_from() -> void:
	# Ein Block x = 3..5, y = 0..4: Hinein kostet 3, innerhalb nichts (wie ein breites Gebäude, das
	# man nur einmal durchbricht). Gerade hindurch 6 + 3 = 9; der Umweg unten herum ≈ 12,8; je
	# Kachel berechnet wären es 6 + 9 = 15.
	var block: Dictionary[Vector2i, bool] = {}
	for x in range(3, 6):
		for y in 5:
			_set_cost(Vector2i(x, y), 3.0)
			block[Vector2i(x, y)] = true
	var entering := func(from: Vector3i, to: Vector3i) -> float:
		var inside := func(position: Vector3i) -> bool: return block.has(Vector2i(position.x, position.y))
		return 3.0 if inside.call(to) and not inside.call(from) else 0.0
	var path := Pathfinder.find_path(Vector3i(1, 1, GROUND), Vector3i(7, 1, GROUND), _walkable_or_costly,
			Callable(), Callable(), entering)
	var expected: Array[Vector2i] = []
	for x in range(1, 8):
		expected.append(Vector2i(x, 1))
	assert_eq(_tiles(path), expected, "Gerade durch den Block:")
	var distances := Pathfinder.distances(Vector3i(1, 1, GROUND), _walkable_or_costly, INF, Callable(), Callable(),
			entering)
	assert_true(is_equal_approx(distances[Vector3i(7, 1, GROUND)], 9.0), "6 Schritte + einmal 3")


func test_extra_cost_on_the_goal_counts() -> void:
	_set_cost(Vector2i(2, 0), 4.0)
	assert_true(is_equal_approx(_costly_distances(Vector2i(0, 0))[Vector3i(2, 0, GROUND)], 6.0), "2 Schritte + 4")


func test_path_to_any_goal_takes_the_cheapest_one() -> void:
	# Ziele links bei x = 0 und rechts bei x = 6; links liegt eine teure Kachel davor.
	_set_cost(Vector2i(1, 3), 10.0)
	for y in SIZE.y:
		if y != 3:
			_blocked[Vector2i(1, y)] = true
	var is_goal := func(position: Vector3i) -> bool: return position.x == 0 or position.x == 6
	var path := Pathfinder.find_path_to_any(Vector3i(2, 3, GROUND), is_goal, _walkable_or_costly, Callable(),
			Callable(), _extra_cost)
	assert_eq(path.back(), Vector3i(6, 3, GROUND), "Das rechte Ziel, 4 statt 2 + 10:")
	assert_eq(path.size(), 5, "Gerade hinüber:")
	_costs[Vector2i(1, 3)] = 1.0
	path = Pathfinder.find_path_to_any(Vector3i(2, 3, GROUND), is_goal, _walkable_or_costly, Callable(),
			Callable(), _extra_cost)
	assert_eq(path.back(), Vector3i(0, 3, GROUND), "Das linke Ziel, 2 + 1 statt 4:")
	var none := func(_position: Vector3i) -> bool: return false
	assert_eq(Pathfinder.find_path_to_any(Vector3i(2, 3, GROUND), none, _walkable).size(), 0, "Kein Ziel:")
	assert_eq(Pathfinder.find_path_to_any(Vector3i(6, 3, GROUND), is_goal, _walkable), [Vector3i(6, 3, GROUND)] as Array[Vector3i],
			"Schon am Ziel:")


func _nearest(from: Vector2i, is_goal: Callable, estimate := Callable()) -> Dictionary[Vector3i, float]:
	return Pathfinder.nearest(Vector3i(from.x, from.y, GROUND), is_goal, _walkable, Callable(), Callable(), estimate)


func test_nearest_gives_only_the_closest_goal() -> void:
	# Ziele sind die Spalten x = 0 und x = 6; von (2, 3) ist links näher.
	var is_goal := func(position: Vector3i) -> bool: return position.x == 0 or position.x == 6
	var found := _nearest(Vector2i(2, 3), is_goal)
	assert_eq(found.keys(), [Vector3i(0, 3, GROUND)], "Nur das nächste Ziel:")
	assert_eq(found[Vector3i(0, 3, GROUND)], 2.0, "Seine Weglänge:")


func test_nearest_gives_all_equally_close_goals() -> void:
	var is_goal := func(position: Vector3i) -> bool: return position.x == 0 or position.x == 6
	var found := _nearest(Vector2i(3, 3), is_goal)
	assert_eq(found.size(), 2, "Links und rechts gleich weit: %s" % str(found))
	assert_true(found.has(Vector3i(0, 3, GROUND)) and found.has(Vector3i(6, 3, GROUND)), "Beide Ziele")


func test_nearest_matches_distances_around_obstacles() -> void:
	_block([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	var goal := Vector3i(5, 1, GROUND)
	var is_goal := func(position: Vector3i) -> bool: return position == goal
	var found := _nearest(Vector2i(1, 1), is_goal, Pathfinder.free_length.bind(goal))
	assert_true(Pathfinder.same_length(found[goal], _distances(Vector2i(1, 1))[goal]),
			"Mit Schätzung wie distances(): %s" % str(found))


func test_nearest_is_empty_without_reachable_goal() -> void:
	_block([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5),
			Vector2i(3, 6), Vector2i(3, 7), Vector2i(3, 8), Vector2i(3, 9)])
	var is_goal := func(position: Vector3i) -> bool: return position.x == 6
	assert_eq(_nearest(Vector2i(1, 1), is_goal).size(), 0, "Hinter der Mauer:")


func test_nearest_counts_the_start_as_goal() -> void:
	var is_goal := func(position: Vector3i) -> bool: return position.x == 2
	assert_eq(_nearest(Vector2i(2, 3), is_goal), {Vector3i(2, 3, GROUND): 0.0} as Dictionary[Vector3i, float],
			"Schon am Ziel:")
