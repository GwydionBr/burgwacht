class_name Pathfinder
extends RefCounted
## Wegfindung auf dem Kachelraster (A*). Positionen sind Vector3i: Kachel (x, y) und
## Ebene (z, ADR 0004). Die Ebene wechselt ein Weg nur über Ebenenwechsel (ascents, z. B. Treppen).
## Acht Richtungen: gerade kostet 1, schräg √2. Am Boden schräg nur, wenn beide Kacheln daneben
## (mit gemeinsamer Kante) begehbar sind – niemand schneidet Ecken von Hindernissen, eine
## diagonale Mauer ist dicht. Oben auf dem Wehrgang gilt diese Eckregel nicht, damit man auf
## diagonalen Mauern entlanggehen kann. Einzelne Schritte kann der Aufrufer verbieten (steppable).
## Optional kostet ein Schritt zusätzlich (extra_cost, abhängig von Herkunft und Ziel), z. B. für
## Feinde, die ein Gebäude erst durchbrechen müssen (ADR 0005). Eine Kachel, deren Betreten von hier
## aus zusätzlich kostet, zählt für die Eckregel als Hindernis, sonst schlüpfte man kostenlos schräg
## zwischen zwei Mauerkacheln hindurch.
## Deterministisch (ADR 0001): Nachbarn in fester Reihenfolge, bei gleicher Schätzung
## gewinnt die Kachel näher am Ziel, dann die früher gefundene.

const DIAGONAL_COST := sqrt(2.0)
## Weglängen, die sich um weniger unterscheiden, gelten als gleich (same_length()).
const LENGTH_EPSILON := 0.0001
## Aufrufe und Dauer der Suche seit reset_profile() (für tools/profile.sh).
static var path_calls := 0
static var distance_calls := 0
static var path_us := 0
static var distance_us := 0
## Erst gerade (oben, rechts, unten, links), dann schräg im Uhrzeigersinn ab oben rechts.
const STRAIGHT_STEPS: Array[Vector3i] = [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]
const DIAGONAL_STEPS: Array[Vector3i] = [Vector3i(1, -1, 0), Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(-1, -1, 0)]


## Kürzester Weg von start nach goal samt beiden Enden; leer, wenn goal nicht erreichbar
## ist. walkable(Vector3i) -> bool sagt, ob man auf einer Position stehen kann; der Start
## selbst muss es nicht sein (wer dort festsitzt, kommt trotzdem weg). ascents(Vector3i) ->
## Array[Vector3i] nennt die Positionen auf einer anderen Ebene, die man von einer Position aus
## mit einem geraden Schritt erreicht (leer gelassen: keine). steppable(Vector3i, Vector3i) -> bool
## sagt, ob man von einer begehbaren Position auf eine benachbarte treten darf (leer gelassen:
## immer), z. B. einen Eingang nur von vorn. extra_cost(Vector3i, Vector3i) -> float sind nicht
## negative Zusatzkosten für den Schritt von der ersten auf die zweite Position (leer gelassen: keine).
static func find_path(start: Vector3i, goal: Vector3i, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable()) -> Array[Vector3i]:
	if start != goal and not walkable.call(goal):
		var none: Array[Vector3i] = []
		return none
	return _search(start, func(position: Vector3i) -> bool: return position == goal,
			free_length.bind(goal), walkable, ascents, steppable, extra_cost)


## Wie find_path(), aber zur nächsten Position (nach Kosten), für die is_goal(Vector3i) -> bool
## gilt. estimate(Vector3i) -> float ist eine untere Schranke der restlichen Kosten bis zu einem
## Ziel (leer gelassen: 0, dann sucht er gleichmäßig nach allen Seiten); bei gleichen Kosten
## entscheidet die feste Reihenfolge der Suche.
static func find_path_to_any(start: Vector3i, is_goal: Callable, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable(), estimate := Callable()) -> Array[Vector3i]:
	var no_estimate := func(_position: Vector3i) -> float: return 0.0
	return _search(start, is_goal, estimate if estimate.is_valid() else no_estimate, walkable, ascents,
			steppable, extra_cost)


## Setzt die Zähler von path_calls / distance_calls zurück.
static func reset_profile() -> void:
	path_calls = 0
	distance_calls = 0
	path_us = 0
	distance_us = 0


## A* von start bis zur ersten Position, für die is_goal gilt; Weg samt beiden Enden, leer, wenn
## es keine erreichbare gibt.
static func _search(start: Vector3i, is_goal: Callable, estimate: Callable, walkable: Callable,
		ascents: Callable, steppable: Callable, extra_cost: Callable) -> Array[Vector3i]:
	path_calls += 1
	var started := Time.get_ticks_usec()
	var path := _search_uncounted(start, is_goal, estimate, walkable, ascents, steppable, extra_cost)
	path_us += Time.get_ticks_usec() - started
	return path


static func _search_uncounted(start: Vector3i, is_goal: Callable, estimate: Callable, walkable: Callable,
		ascents: Callable, steppable: Callable, extra_cost: Callable) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var open := _Heap.new()
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var came_from: Dictionary[Vector3i, Vector3i] = {}
	var closed: Dictionary[Vector3i, bool] = {}
	var next_positions: Array[Vector3i] = []
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
		var current_cost: float = cost_so_far[current]
		_collect_neighbors(current, walkable, ascents, steppable, extra_cost, next_positions)
		for next in next_positions:
			if closed.has(next):
				continue
			var cost := current_cost + step_cost(current, next) + _extra(extra_cost, current, next)
			if cost_so_far.get(next, INF) <= cost:
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
	distance_calls += 1
	var started := Time.get_ticks_usec()
	var result := _distances_uncounted(start, walkable, max_length, ascents, steppable, extra_cost)
	distance_us += Time.get_ticks_usec() - started
	return result


static func _distances_uncounted(start: Vector3i, walkable: Callable, max_length: float,
		ascents: Callable, steppable: Callable, extra_cost: Callable) -> Dictionary[Vector3i, float]:
	var result: Dictionary[Vector3i, float] = {}
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var next_positions: Array[Vector3i] = []
	var limit := max_length + LENGTH_EPSILON
	var open := _Heap.new()
	open.push(0.0, 0.0, start)
	while not open.is_empty():
		var current := open.pop()
		if result.has(current):
			continue
		var current_cost: float = cost_so_far[current]
		result[current] = current_cost
		_collect_neighbors(current, walkable, ascents, steppable, extra_cost, next_positions)
		for next in next_positions:
			var cost := current_cost + step_cost(current, next) + _extra(extra_cost, current, next)
			if result.has(next) or cost > limit or cost_so_far.get(next, INF) <= cost:
				continue
			cost_so_far[next] = cost
			open.push(cost, 0.0, next)
	return result


## Weglängen von start zu den nächsten Positionen, für die is_goal(Vector3i) -> bool gilt: zur
## nächsten und zu allen, die höchstens LENGTH_EPSILON länger sind (gleich lang, same_length()).
## Gleiche Schritte wie distances(), hört aber auf, sobald diese feststehen; leer, wenn keine
## erreichbar ist. estimate(Vector3i) -> float ist eine untere Schranke der restlichen Weglänge bis
## zum nächsten Ziel, die bei jedem Schritt um höchstens dessen Kosten sinkt (leer gelassen: 0,
## dann sucht er gleichmäßig nach allen Seiten wie distances()).
static func nearest(start: Vector3i, is_goal: Callable, walkable: Callable, ascents := Callable(),
		steppable := Callable(), estimate := Callable()) -> Dictionary[Vector3i, float]:
	distance_calls += 1
	var started := Time.get_ticks_usec()
	var result := _nearest_uncounted(start, is_goal, walkable, ascents, steppable, estimate)
	distance_us += Time.get_ticks_usec() - started
	return result


static func _nearest_uncounted(start: Vector3i, is_goal: Callable, walkable: Callable, ascents: Callable,
		steppable: Callable, estimate: Callable) -> Dictionary[Vector3i, float]:
	var goals: Dictionary[Vector3i, float] = {}
	var cost_so_far: Dictionary[Vector3i, float] = {start: 0.0}
	var closed: Dictionary[Vector3i, bool] = {}
	var next_positions: Array[Vector3i] = []
	var no_extra := Callable()
	var limit := INF
	var open := _Heap.new()
	var start_rest: float = estimate.call(start) if estimate.is_valid() else 0.0
	open.push(start_rest, start_rest, start)
	while not open.is_empty():
		var current := open.pop()
		if closed.has(current):
			continue
		closed[current] = true
		var current_cost: float = cost_so_far[current]
		var current_rest: float = estimate.call(current) if estimate.is_valid() else 0.0
		# Alles Weitere ist länger als das nächste Ziel (Schranke steigt nie ab).
		if current_cost + current_rest > limit:
			break
		if is_goal.call(current):
			goals[current] = current_cost
			if is_inf(limit):
				limit = current_cost + LENGTH_EPSILON
		_collect_neighbors(current, walkable, ascents, steppable, no_extra, next_positions)
		for next in next_positions:
			if closed.has(next):
				continue
			var cost := current_cost + step_cost(current, next)
			if cost > limit or cost_so_far.get(next, INF) <= cost:
				continue
			cost_so_far[next] = cost
			var rest: float = estimate.call(next) if estimate.is_valid() else 0.0
			open.push(cost + rest, rest, next)
	return goals


## Weglänge von from nach to ohne Hindernisse (Oktil-Abstand): eine untere Schranke für jeden Weg
## dorthin, für estimate in nearest() und find_path_to_any().
static func free_length(from: Vector3i, to: Vector3i) -> float:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	return absi(dx - dy) + DIAGONAL_COST * mini(dx, dy)


## Sind zwei Weglängen gleich? Summen aus 1 und √2 können je nach Reihenfolge um
## Rundungsfehler abweichen.
static func same_length(a: float, b: float) -> bool:
	return absf(a - b) < LENGTH_EPSILON


## Die begehbaren Nachbarn einer Position, die man von ihr aus betreten darf (steppable), in
## fester Reihenfolge (gerade vor schräg, dann die Ebenenwechsel in ihrer Reihenfolge). Schräg am
## Boden nur, wenn beide Kacheln daneben frei sind: begehbar und von hier aus ohne Zusatzkosten
## (extra_cost).
static func neighbors(position: Vector3i, walkable: Callable, ascents := Callable(),
		steppable := Callable(), extra_cost := Callable()) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	_collect_neighbors(position, walkable, ascents, steppable, extra_cost, result)
	return result


## Wie neighbors(), schreibt aber in result (vorher geleert), damit die Suche nicht für jede
## Position neue Arrays anlegt. Jede Kachel daneben wird nur einmal auf walkable geprüft.
static func _collect_neighbors(position: Vector3i, walkable: Callable, ascents: Callable,
		steppable: Callable, extra_cost: Callable, result: Array[Vector3i]) -> void:
	result.clear()
	var up := position + Vector3i(0, -1, 0)
	var right := position + Vector3i(1, 0, 0)
	var down := position + Vector3i(0, 1, 0)
	var left := position + Vector3i(-1, 0, 0)
	var up_open: bool = walkable.call(up)
	var right_open: bool = walkable.call(right)
	var down_open: bool = walkable.call(down)
	var left_open: bool = walkable.call(left)
	if up_open:
		result.append(up)
	if right_open:
		result.append(right)
	if down_open:
		result.append(down)
	if left_open:
		result.append(left)
	var on_ground := position.z == Figure.Level.GROUND
	if on_ground and extra_cost.is_valid():
		# Eine Kachel mit Zusatzkosten lässt keine Ecke schräg passieren (wie eine gesperrte).
		up_open = up_open and _extra(extra_cost, position, up) <= 0.0
		right_open = right_open and _extra(extra_cost, position, right) <= 0.0
		down_open = down_open and _extra(extra_cost, position, down) <= 0.0
		left_open = left_open and _extra(extra_cost, position, left) <= 0.0
	# Reihenfolge wie DIAGONAL_STEPS: oben rechts, unten rechts, unten links, oben links.
	if (not on_ground or up_open and right_open) and walkable.call(position + Vector3i(1, -1, 0)):
		result.append(position + Vector3i(1, -1, 0))
	if (not on_ground or down_open and right_open) and walkable.call(position + Vector3i(1, 1, 0)):
		result.append(position + Vector3i(1, 1, 0))
	if (not on_ground or down_open and left_open) and walkable.call(position + Vector3i(-1, 1, 0)):
		result.append(position + Vector3i(-1, 1, 0))
	if (not on_ground or up_open and left_open) and walkable.call(position + Vector3i(-1, -1, 0)):
		result.append(position + Vector3i(-1, -1, 0))
	if ascents.is_valid():
		for next: Vector3i in ascents.call(position):
			if walkable.call(next):
				result.append(next)
	if not steppable.is_valid():
		return
	var kept := 0
	for i in result.size():
		if steppable.call(position, result[i]):
			result[kept] = result[i]
			kept += 1
	result.resize(kept)


## Kosten eines Schritts auf eine Nachbarkachel: 1 gerade, √2 schräg.
static func step_cost(from: Vector3i, to: Vector3i) -> float:
	return DIAGONAL_COST if from.x != to.x and from.y != to.y else 1.0


## Weglänge eines Weges aus find_path().
static func path_length(path: Array[Vector3i]) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += step_cost(path[i - 1], path[i])
	return length


## Zusatzkosten für den Schritt von from auf to (0 ohne extra_cost).
static func _extra(extra_cost: Callable, from: Vector3i, to: Vector3i) -> float:
	return extra_cost.call(from, to) if extra_cost.is_valid() else 0.0


## Vorrangwarteschlange (binärer Heap): kleinste Schätzung zuerst, dann kleinste
## Restschätzung, dann die zuerst eingefügte. Gepackte Arrays statt eines Arrays je Eintrag und
## Vergleiche ohne Hilfsfunktion, weil die Suche fast ihre ganze Zeit hier verbringt.
class _Heap:
	var _priorities := PackedFloat64Array()
	var _rests := PackedFloat64Array()
	var _orders := PackedInt64Array()
	var _positions: Array[Vector3i] = []
	var _size := 0
	var _count := 0

	func is_empty() -> bool:
		return _size == 0

	func push(priority: float, rest: float, position: Vector3i) -> void:
		var order := _count
		_count += 1
		if _size == _positions.size():
			_priorities.append(priority)
			_rests.append(rest)
			_orders.append(order)
			_positions.append(position)
		var i := _size
		_size += 1
		# Das Loch wandert nach oben, solange der Elternknoten später drankommt.
		while i > 0:
			@warning_ignore("integer_division")
			var parent := (i - 1) / 2
			var parent_priority := _priorities[parent]
			if parent_priority < priority or parent_priority == priority \
					and (_rests[parent] < rest or _rests[parent] == rest and _orders[parent] < order):
				break
			_priorities[i] = parent_priority
			_rests[i] = _rests[parent]
			_orders[i] = _orders[parent]
			_positions[i] = _positions[parent]
			i = parent
		_priorities[i] = priority
		_rests[i] = rest
		_orders[i] = order
		_positions[i] = position

	func pop() -> Vector3i:
		var top := _positions[0]
		_size -= 1
		var size := _size
		if size == 0:
			return top
		# Der letzte Eintrag kommt in das Loch an der Spitze und sinkt ab.
		var priority := _priorities[size]
		var rest := _rests[size]
		var order := _orders[size]
		var position := _positions[size]
		var i := 0
		while true:
			var child := 2 * i + 1
			if child >= size:
				break
			var right := child + 1
			if right < size:
				var child_priority := _priorities[child]
				var right_priority := _priorities[right]
				if right_priority < child_priority or right_priority == child_priority \
						and (_rests[right] < _rests[child] or _rests[right] == _rests[child] \
						and _orders[right] < _orders[child]):
					child = right
			var best_priority := _priorities[child]
			if priority < best_priority or priority == best_priority \
					and (rest < _rests[child] or rest == _rests[child] and order < _orders[child]):
				break
			_priorities[i] = best_priority
			_rests[i] = _rests[child]
			_orders[i] = _orders[child]
			_positions[i] = _positions[child]
			i = child
		_priorities[i] = priority
		_rests[i] = rest
		_orders[i] = order
		_positions[i] = position
		return top
