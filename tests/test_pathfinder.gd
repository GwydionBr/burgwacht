extends TestCase
## Einzeltests der Wegfindung (A*, 8 Richtungen) auf einem kleinen Raster.
## Positionen sind Vector3i: Kachel (x, y) und Ebene (z).

const GROUND := Resident.Level.GROUND
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
