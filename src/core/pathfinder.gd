class_name Pathfinder
extends RefCounted
## Wegfindung auf dem Kachelraster (A*). Positionen sind Vector3i: Kachel (x, y) und
## Ebene (z, ADR 0004). Die Ebene wechselt ein Weg nur über Aufgänge (ascents, z. B. Treppen).
## Acht Richtungen: gerade kostet 1, schräg √2. Am Boden schräg nur, wenn beide Kacheln daneben
## (mit gemeinsamer Kante) begehbar sind – niemand schneidet Ecken von Hindernissen, eine
## diagonale Mauer ist dicht. Oben auf dem Wehrgang gilt diese Eckregel nicht, damit man auf
## diagonalen Mauern entlanggehen kann.
## Deterministisch (ADR 0001): Nachbarn in fester Reihenfolge, bei gleicher Schätzung
## gewinnt die Kachel näher am Ziel, dann die früher gefundene.

const DIAGONAL_COST := sqrt(2.0)
## Weglängen, die sich um weniger unterscheiden, gelten als gleich (same_length()).
const LENGTH_EPSILON := 0.0001
## Ebene des Bodens; nur hier gilt die Eckregel.
const GROUND := 0
## Erst gerade (oben, rechts, unten, links), dann schräg im Uhrzeigersinn ab oben rechts.
const STRAIGHT_STEPS: Array[Vector3i] = [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]
const DIAGONAL_STEPS: Array[Vector3i] = [Vector3i(1, -1, 0), Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(-1, -1, 0)]


## Kürzester Weg von start nach goal samt beiden Enden; leer, wenn goal nicht erreichbar
## ist. walkable(Vector3i) -> bool sagt, ob man auf einer Position stehen kann; der Start
## selbst muss es nicht sein (wer dort festsitzt, kommt trotzdem weg). ascents(Vector3i) ->
## Array[Vector3i] nennt die Positionen auf einer anderen Ebene, die man von einer Position aus
## mit einem geraden Schritt erreicht (leer gelassen: keine).
static func find_path(start: Vector3i, goal: Vector3i, walkable: Callable, ascents := Callable()) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if start == goal:
		path.append(start)
		return path
	if not walkable.call(goal):
		return path
	var open := _Heap.new()
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var came_from: Dictionary[Vector3i, Vector3i] = {}
	var closed: Dictionary[Vector3i, bool] = {}
	open.push(_estimate(start, goal), _estimate(start, goal), start)
	while not open.is_empty():
		var current := open.pop()
		if current == goal:
			break
		if closed.has(current):
			continue
		closed[current] = true
		for next in neighbors(current, walkable, ascents):
			if closed.has(next):
				continue
			var cost := cost_so_far[current] + step_cost(current, next)
			if cost_so_far.has(next) and cost_so_far[next] <= cost:
				continue
			cost_so_far[next] = cost
			came_from[next] = current
			var rest := _estimate(next, goal)
			open.push(cost + rest, rest, next)
	if not came_from.has(goal):
		return path
	var position := goal
	while position != start:
		path.append(position)
		position = came_from[position]
	path.append(start)
	path.reverse()
	return path


## Weglänge von start zu jeder erreichbaren Position bis höchstens max_length (Dijkstra,
## gleiche Schritte und Kosten wie find_path()); der Start selbst hat 0. Für die Suche nach
## dem nächsten Vorkommen oder Lager.
static func distances(start: Vector3i, walkable: Callable, max_length := INF,
		ascents := Callable()) -> Dictionary[Vector3i, float]:
	var result: Dictionary[Vector3i, float] = {}
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var open := _Heap.new()
	open.push(0.0, 0.0, start)
	while not open.is_empty():
		var current := open.pop()
		if result.has(current):
			continue
		result[current] = cost_so_far[current]
		for next in neighbors(current, walkable, ascents):
			var cost := cost_so_far[current] + step_cost(current, next)
			if result.has(next) or cost > max_length + LENGTH_EPSILON \
					or (cost_so_far.has(next) and cost_so_far[next] <= cost):
				continue
			cost_so_far[next] = cost
			open.push(cost, 0.0, next)
	return result


## Sind zwei Weglängen gleich? Summen aus 1 und √2 können je nach Reihenfolge um
## Rundungsfehler abweichen.
static func same_length(a: float, b: float) -> bool:
	return absf(a - b) < LENGTH_EPSILON


## Die begehbaren Nachbarn einer Position in fester Reihenfolge (gerade vor schräg, dann die
## Aufgänge in ihrer Reihenfolge).
static func neighbors(position: Vector3i, walkable: Callable, ascents := Callable()) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for step in STRAIGHT_STEPS:
		if walkable.call(position + step):
			result.append(position + step)
	for step in DIAGONAL_STEPS:
		if walkable.call(position + step) and (position.z != GROUND
				or walkable.call(position + Vector3i(step.x, 0, 0)) and walkable.call(position + Vector3i(0, step.y, 0))):
			result.append(position + step)
	if ascents.is_valid():
		for next: Vector3i in ascents.call(position):
			if walkable.call(next):
				result.append(next)
	return result


## Kosten eines Schritts auf eine Nachbarkachel: 1 gerade, √2 schräg.
static func step_cost(from: Vector3i, to: Vector3i) -> float:
	return DIAGONAL_COST if from.x != to.x and from.y != to.y else 1.0


## Weglänge eines Weges aus find_path().
static func path_length(path: Array[Vector3i]) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += step_cost(path[i - 1], path[i])
	return length


## Untere Schranke der Weglänge ohne Hindernisse (Oktil-Abstand).
static func _estimate(from: Vector3i, to: Vector3i) -> float:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	return absi(dx - dy) + DIAGONAL_COST * mini(dx, dy)


## Vorrangwarteschlange (binärer Heap): kleinste Schätzung zuerst, dann kleinste
## Restschätzung, dann die zuerst eingefügte.
class _Heap:
	var _entries: Array[Array] = []
	var _count := 0

	func is_empty() -> bool:
		return _entries.is_empty()

	func push(priority: float, rest: float, position: Vector3i) -> void:
		_entries.append([priority, rest, _count, position])
		_count += 1
		var i := _entries.size() - 1
		while i > 0:
			@warning_ignore("integer_division")
			var parent := (i - 1) / 2
			if not _less(_entries[i], _entries[parent]):
				break
			_swap(i, parent)
			i = parent

	func pop() -> Vector3i:
		var top: Vector3i = _entries[0][3]
		var last: Array = _entries.pop_back()
		if not _entries.is_empty():
			_entries[0] = last
			var i := 0
			while true:
				var smallest := i
				for child: int in [2 * i + 1, 2 * i + 2]:
					if child < _entries.size() and _less(_entries[child], _entries[smallest]):
						smallest = child
				if smallest == i:
					break
				_swap(i, smallest)
				i = smallest
		return top

	func _less(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2]

	func _swap(i: int, j: int) -> void:
		var temp: Array = _entries[i]
		_entries[i] = _entries[j]
		_entries[j] = temp
