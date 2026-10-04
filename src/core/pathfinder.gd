class_name Pathfinder
extends RefCounted
## Wegfindung auf dem Kachelraster (A*). Positionen sind Vector3i: Kachel (x, y) und
## Ebene (z, ADR 0004). Die Ebene wechselt ein Weg nur über Ebenenwechsel (ascents, z. B. Treppen).
## Acht Richtungen: gerade kostet 1, schräg √2. Am Boden schräg nur, wenn beide Kacheln daneben
## (mit gemeinsamer Kante) begehbar sind – niemand schneidet Ecken von Hindernissen, eine
## diagonale Mauer ist dicht. Oben auf dem Wehrgang gilt diese Eckregel nicht, damit man auf
## diagonalen Mauern entlanggehen kann. Einzelne Schritte kann der Aufrufer verbieten (steppable).
## Optional kostet das Betreten einer Position zusätzlich (extra_cost), z. B. für Feinde, die ein
## Gebäude erst durchbrechen müssen (ADR 0005). Eine Kachel mit Zusatzkosten zählt für die Eckregel
## als Hindernis, sonst schlüpfte man kostenlos schräg zwischen zwei Mauerkacheln hindurch.
## Deterministisch (ADR 0001): Nachbarn in fester Reihenfolge, bei gleicher Schätzung
## gewinnt die Kachel näher am Ziel, dann die früher gefundene.

const DIAGONAL_COST := sqrt(2.0)
## Weglängen, die sich um weniger unterscheiden, gelten als gleich (same_length()).
const LENGTH_EPSILON := 0.0001
## Erst gerade (oben, rechts, unten, links), dann schräg im Uhrzeigersinn ab oben rechts.
const STRAIGHT_STEPS: Array[Vector3i] = [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]
const DIAGONAL_STEPS: Array[Vector3i] = [Vector3i(1, -1, 0), Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(-1, -1, 0)]


## Kürzester Weg von start nach goal samt beiden Enden; leer, wenn goal nicht erreichbar
## ist. walkable(Vector3i) -> bool sagt, ob man auf einer Position stehen kann; der Start
## selbst muss es nicht sein (wer dort festsitzt, kommt trotzdem weg). ascents(Vector3i) ->
## Array[Vector3i] nennt die Positionen auf einer anderen Ebene, die man von einer Position aus
## mit einem geraden Schritt erreicht (leer gelassen: keine). steppable(Vector3i, Vector3i) -> bool
## sagt, ob man von einer begehbaren Position auf eine benachbarte treten darf (leer gelassen:
## immer), z. B. einen Eingang nur von vorn. extra_cost(Vector3i) -> float sind nicht negative
## Zusatzkosten beim Betreten einer Position (leer gelassen: keine).
static func find_path(start: Vector3i, goal: Vector3i, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable()) -> Array[Vector3i]:
	if start != goal and not walkable.call(goal):
		var none: Array[Vector3i] = []
		return none
	return _search(start, func(position: Vector3i) -> bool: return position == goal,
			_estimate.bind(goal), walkable, ascents, steppable, extra_cost)


## Wie find_path(), aber zur nächsten Position (nach Kosten), für die is_goal(Vector3i) -> bool
## gilt. estimate(Vector3i) -> float ist eine untere Schranke der restlichen Kosten bis zu einem
## Ziel (leer gelassen: 0, dann sucht er gleichmäßig nach allen Seiten); bei gleichen Kosten
## entscheidet die feste Reihenfolge der Suche.
static func find_path_to_any(start: Vector3i, is_goal: Callable, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable(), estimate := Callable()) -> Array[Vector3i]:
	var no_estimate := func(_position: Vector3i) -> float: return 0.0
	return _search(start, is_goal, estimate if estimate.is_valid() else no_estimate, walkable, ascents,
			steppable, extra_cost)


## A* von start bis zur ersten Position, für die is_goal gilt; Weg samt beiden Enden, leer, wenn
## es keine erreichbare gibt.
static func _search(start: Vector3i, is_goal: Callable, estimate: Callable, walkable: Callable,
		ascents: Callable, steppable: Callable, extra_cost: Callable) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var open := _Heap.new()
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var came_from: Dictionary[Vector3i, Vector3i] = {}
	var closed: Dictionary[Vector3i, bool] = {}
	var start_rest: float = estimate.call(start)
	open.push(start_rest, start_rest, start)
	var found := false
	var current := start
	while not open.is_empty():
		current = open.pop()
		if is_goal.call(current):
			found = true
			break
		if closed.has(current):
			continue
		closed[current] = true
		for next in neighbors(current, walkable, ascents, steppable, extra_cost):
			if closed.has(next):
				continue
			var cost := cost_so_far[current] + step_cost(current, next) + _extra(extra_cost, next)
			if cost_so_far.has(next) and cost_so_far[next] <= cost:
				continue
			cost_so_far[next] = cost
			came_from[next] = current
			var rest: float = estimate.call(next)
			open.push(cost + rest, rest, next)
	if not found:
		return path
	var position := current
	while position != start:
		path.append(position)
		position = came_from[position]
	path.append(start)
	path.reverse()
	return path


## Weglänge von start zu jeder erreichbaren Position bis höchstens max_length (Dijkstra,
## gleiche Schritte und Kosten wie find_path(), samt Zusatzkosten); der Start selbst hat 0. Für
## die Suche nach dem nächsten Vorkommen oder Lager.
static func distances(start: Vector3i, walkable: Callable, max_length := INF,
		ascents := Callable(), steppable := Callable(), extra_cost := Callable()) -> Dictionary[Vector3i, float]:
	var result: Dictionary[Vector3i, float] = {}
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var open := _Heap.new()
	open.push(0.0, 0.0, start)
	while not open.is_empty():
		var current := open.pop()
		if result.has(current):
			continue
		result[current] = cost_so_far[current]
		for next in neighbors(current, walkable, ascents, steppable, extra_cost):
			var cost := cost_so_far[current] + step_cost(current, next) + _extra(extra_cost, next)
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


## Die begehbaren Nachbarn einer Position, die man von ihr aus betreten darf (steppable), in
## fester Reihenfolge (gerade vor schräg, dann die Ebenenwechsel in ihrer Reihenfolge). Schräg am
## Boden nur, wenn beide Kacheln daneben frei sind: begehbar und ohne Zusatzkosten (extra_cost).
static func neighbors(position: Vector3i, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable()) -> Array[Vector3i]:
	var candidates: Array[Vector3i] = []
	for step in STRAIGHT_STEPS:
		if walkable.call(position + step):
			candidates.append(position + step)
	for step in DIAGONAL_STEPS:
		if walkable.call(position + step) and (position.z != Figure.Level.GROUND
				or _is_free(position + Vector3i(step.x, 0, 0), walkable, extra_cost)
				and _is_free(position + Vector3i(0, step.y, 0), walkable, extra_cost)):
			candidates.append(position + step)
	if ascents.is_valid():
		for next: Vector3i in ascents.call(position):
			if walkable.call(next):
				candidates.append(next)
	if not steppable.is_valid():
		return candidates
	var result: Array[Vector3i] = []
	for next in candidates:
		if steppable.call(position, next):
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


## Zusatzkosten beim Betreten von position (0 ohne extra_cost).
static func _extra(extra_cost: Callable, position: Vector3i) -> float:
	return extra_cost.call(position) if extra_cost.is_valid() else 0.0


## Begehbar und ohne Zusatzkosten? Nur solche Kacheln lassen eine Ecke schräg passieren.
static func _is_free(position: Vector3i, walkable: Callable, extra_cost: Callable) -> bool:
	return walkable.call(position) and _extra(extra_cost, position) <= 0.0


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
