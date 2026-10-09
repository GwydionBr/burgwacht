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
## Raster, Begehbarkeit, Ebenenwechsel und verbotene Schritte beschreibt ein Graph. Er merkt sich die
## erlaubten Schritte je Position, sobald eine Suche sie zum ersten Mal braucht; wer ihn über
## mehrere Suchen behält, solange sich die Begehbarkeit nicht ändert, spart den größten Teil der
## Zeit. Intern rechnet die Suche mit dem Index einer Position im Raster (Graph.index_of()).

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


## Kürzester Weg von start nach goal im graph samt beiden Enden; leer, wenn goal nicht
## erreichbar ist. Der Start selbst muss nicht begehbar sein (wer dort festsitzt, kommt trotzdem
## weg). extra_cost(Vector3i, Vector3i) -> float sind nicht negative Zusatzkosten für den Schritt
## von der ersten auf die zweite Position (leer gelassen: keine).
static func find_path(start: Vector3i, goal: Vector3i, graph: Graph, extra_cost := Callable()) -> Array[Vector3i]:
	if start != goal and not graph.is_walkable(goal):
		var none: Array[Vector3i] = []
		return none
	return _search(start, Callable(), Callable(), goal, graph, extra_cost)


## Wie find_path(), aber zur nächsten Position (nach Kosten), für die is_goal(Vector3i) -> bool
## gilt. estimate(Vector3i) -> float ist eine untere Schranke der restlichen Kosten bis zu einem
## Ziel (leer gelassen: 0, dann sucht er gleichmäßig nach allen Seiten); bei gleichen Kosten
## entscheidet die feste Reihenfolge der Suche.
static func find_path_to_any(start: Vector3i, is_goal: Callable, graph: Graph, extra_cost := Callable(),
		estimate := Callable()) -> Array[Vector3i]:
	return _search(start, is_goal, estimate, Vector3i.ZERO, graph, extra_cost)


## Setzt die Zähler und Dauern (path_calls, distance_calls, path_us, distance_us) zurück.
static func reset_profile() -> void:
	path_calls = 0
	distance_calls = 0
	path_us = 0
	distance_us = 0


## A* von start bis zur ersten Position, für die is_goal gilt (leer gelassen: goal); Weg samt
## beiden Enden, leer, wenn es keine erreichbare gibt. Ohne is_goal schätzt free_length() bis goal.
static func _search(start: Vector3i, is_goal: Callable, estimate: Callable, goal: Vector3i, graph: Graph,
		extra_cost: Callable) -> Array[Vector3i]:
	path_calls += 1
	var started := Time.get_ticks_usec()
	var path := _search_uncounted(start, is_goal, estimate, goal, graph, extra_cost)
	path_us += Time.get_ticks_usec() - started
	return path


static func _search_uncounted(start: Vector3i, is_goal: Callable, estimate: Callable, goal: Vector3i,
		graph: Graph, extra_cost: Callable) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var to_goal := not is_goal.is_valid()
	var goal_index := graph.index_of(goal) if to_goal else -1
	var with_extra := extra_cost.is_valid()
	var width := graph.size.x
	var height := graph.size.y
	var cost_so_far := graph.new_costs()
	var came_from := PackedInt32Array()
	came_from.resize(cost_so_far.size())
	var closed := PackedByteArray()
	closed.resize(cost_so_far.size())
	var open := _Heap.new()
	var start_index := graph.index_of(start)
	cost_so_far[start_index] = 0.0
	var start_rest := free_length(start, goal) if to_goal else _estimate(estimate, start)
	open.push(start_rest, start_rest, start_index)
	var found := false
	var current := start_index
	while not open.is_empty():
		current = open.pop()
		var at_goal: bool = current == goal_index if to_goal else is_goal.call(graph.position_of(current))
		if at_goal:
			found = true
			break
		if closed[current] != 0:
			continue
		closed[current] = 1
		var current_cost := cost_so_far[current]
		var current_position := graph.position_of(current) if with_extra else Vector3i.ZERO
		for code: int in graph.steps_of(current, extra_cost):
			var next := code >> 1
			if closed[next] != 0:
				continue
			var cost := current_cost + (DIAGONAL_COST if code & 1 else 1.0)
			if with_extra:
				cost += extra_cost.call(current_position, graph.position_of(next))
			if cost_so_far[next] <= cost:
				continue
			cost_so_far[next] = cost
			came_from[next] = current
			var rest := 0.0
			if to_goal:
				# free_length() bis goal, ohne erst eine Position zu bauen.
				var dx := absi(goal.x - next % width)
				@warning_ignore("integer_division")
				var dy := absi(goal.y - next / width % height)
				rest = absi(dx - dy) + DIAGONAL_COST * mini(dx, dy)
			else:
				rest = _estimate(estimate, graph.position_of(next))
			open.push(cost + rest, rest, next)
	if not found:
		return path
	return _path_to(current, start, came_from, graph)


## Der Weg von start nach index samt beiden Enden, rückwärts über came_from (Vorgänger je Index).
static func _path_to(index: int, start: Vector3i, came_from: PackedInt32Array, graph: Graph) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var start_index := graph.index_of(start)
	while index != start_index:
		path.append(graph.position_of(index))
		index = came_from[index]
	path.append(start)
	path.reverse()
	return path


## Die Schätzung der restlichen Kosten ab position (leer gelassen: 0).
static func _estimate(estimate: Callable, position: Vector3i) -> float:
	return estimate.call(position) if estimate.is_valid() else 0.0


## Weglänge von start zu jeder erreichbaren Position bis höchstens max_length (Dijkstra,
## gleiche Schritte und Kosten wie find_path(), samt Zusatzkosten); der Start selbst hat 0. Für
## die Suche nach dem nächsten Vorkommen oder Lager.
static func distances(start: Vector3i, graph: Graph, max_length := INF,
		extra_cost := Callable()) -> Dictionary[Vector3i, float]:
	distance_calls += 1
	var started := Time.get_ticks_usec()
	var result := _distances_uncounted(start, graph, max_length, extra_cost)
	distance_us += Time.get_ticks_usec() - started
	return result


static func _distances_uncounted(start: Vector3i, graph: Graph, max_length: float,
		extra_cost: Callable) -> Dictionary[Vector3i, float]:
	var result: Dictionary[Vector3i, float] = {}
	var cost_so_far := graph.new_costs()
	var done := PackedByteArray()
	done.resize(cost_so_far.size())
	var with_extra := extra_cost.is_valid()
	var limit := max_length + LENGTH_EPSILON
	var open := _Heap.new()
	var start_index := graph.index_of(start)
	cost_so_far[start_index] = 0.0
	open.push(0.0, 0.0, start_index)
	while not open.is_empty():
		var current := open.pop()
		if done[current] != 0:
			continue
		done[current] = 1
		var current_cost := cost_so_far[current]
		var current_position := graph.position_of(current)
		result[current_position] = current_cost
		for code: int in graph.steps_of(current, extra_cost):
			var next := code >> 1
			var cost := current_cost + (DIAGONAL_COST if code & 1 else 1.0)
			if with_extra:
				cost += extra_cost.call(current_position, graph.position_of(next))
			if done[next] != 0 or cost > limit or cost_so_far[next] <= cost:
				continue
			cost_so_far[next] = cost
			open.push(cost, 0.0, next)
	return result


## Welche Positionen man von einer der starts aus erreicht (Breitensuche, gleiche Schritte wie
## find_path()): je Index im graph 1 oder 0. Schneller als distances(), wenn die Weglänge egal ist.
static func reachable(starts: Array[Vector3i], graph: Graph) -> PackedByteArray:
	var reached := PackedByteArray()
	reached.resize(graph.size.x * graph.size.y * graph.size.z)
	var queue := PackedInt32Array()
	for start in starts:
		var index := graph.index_of(start)
		if reached[index] == 0:
			reached[index] = 1
			queue.append(index)
	var no_extra := Callable()
	var next_in_queue := 0
	while next_in_queue < queue.size():
		var current := queue[next_in_queue]
		next_in_queue += 1
		for code: int in graph.steps_of(current, no_extra):
			var next := code >> 1
			if reached[next] == 0:
				reached[next] = 1
				queue.append(next)
	return reached


## Weglängen von start zu den nächsten Positionen, für die is_goal(Vector3i) -> bool gilt: zur
## nächsten und zu allen, die höchstens LENGTH_EPSILON länger sind (gleich lang, same_length()).
## Gleiche Schritte wie distances(), hört aber auf, sobald diese feststehen; leer, wenn keine
## erreichbar ist. estimate(Vector3i) -> float ist eine untere Schranke der restlichen Weglänge bis
## zum nächsten Ziel, die bei jedem Schritt um höchstens dessen Kosten sinkt (leer gelassen: 0,
## dann sucht er gleichmäßig nach allen Seiten wie distances()).
static func nearest(start: Vector3i, is_goal: Callable, graph: Graph,
		estimate := Callable()) -> Dictionary[Vector3i, float]:
	distance_calls += 1
	var started := Time.get_ticks_usec()
	var result := _nearest_uncounted(start, is_goal, graph, estimate, PackedInt32Array())
	distance_us += Time.get_ticks_usec() - started
	return result


## Wie nearest(), aber je Ziel der Weg dorthin samt beiden Enden (wie find_path()) statt seiner
## Länge (path_length() ergibt dieselbe). Spart die zweite Suche, wer zum gewählten Ziel auch gehen
## will; unter gleich langen Wegen dorthin ist es der, den diese Suche zuerst fand.
static func nearest_paths(start: Vector3i, is_goal: Callable, graph: Graph,
		estimate := Callable()) -> Dictionary[Vector3i, Array]:
	distance_calls += 1
	var started := Time.get_ticks_usec()
	var came_from := PackedInt32Array()
	var lengths := _nearest_uncounted(start, is_goal, graph, estimate, came_from)
	var result: Dictionary[Vector3i, Array] = {}
	for goal: Vector3i in lengths:
		result[goal] = _path_to(graph.index_of(goal), start, came_from, graph)
	distance_us += Time.get_ticks_usec() - started
	return result


## came_from bekommt je Index den Vorgänger auf dem kürzesten Weg (für _path_to()).
static func _nearest_uncounted(start: Vector3i, is_goal: Callable, graph: Graph,
		estimate: Callable, came_from: PackedInt32Array) -> Dictionary[Vector3i, float]:
	var goals: Dictionary[Vector3i, float] = {}
	var cost_so_far := graph.new_costs()
	came_from.resize(cost_so_far.size())
	var closed := PackedByteArray()
	closed.resize(cost_so_far.size())
	var no_extra := Callable()
	var limit := INF
	var open := _Heap.new()
	var start_index := graph.index_of(start)
	cost_so_far[start_index] = 0.0
	var start_rest := _estimate(estimate, start)
	open.push(start_rest, start_rest, start_index)
	while not open.is_empty():
		var current := open.pop()
		if closed[current] != 0:
			continue
		closed[current] = 1
		var current_cost := cost_so_far[current]
		var position := graph.position_of(current)
		# Alles Weitere ist länger als das nächste Ziel (Schranke steigt nie ab).
		if current_cost + _estimate(estimate, position) > limit:
			break
		if is_goal.call(position):
			goals[position] = current_cost
			if is_inf(limit):
				limit = current_cost + LENGTH_EPSILON
		for code: int in graph.steps_of(current, no_extra):
			var next := code >> 1
			if closed[next] != 0:
				continue
			var cost := current_cost + (DIAGONAL_COST if code & 1 else 1.0)
			if cost > limit or cost_so_far[next] <= cost:
				continue
			cost_so_far[next] = cost
			came_from[next] = current
			var rest := _estimate(estimate, graph.position_of(next))
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


## Die begehbaren Nachbarn einer Position im graph, die man von ihr aus betreten darf, in fester
## Reihenfolge (gerade vor schräg, dann die Ebenenwechsel in ihrer Reihenfolge); mit extra_cost wie
## in der Suche.
static func neighbors(position: Vector3i, graph: Graph, extra_cost := Callable()) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for code: int in graph.steps_of(graph.index_of(position), extra_cost):
		result.append(graph.position_of(code >> 1))
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


## Das Raster für die Suche: size ist Breite, Höhe und Zahl der Ebenen; außerhalb ist nichts
## begehbar. walkable(Vector3i) -> bool sagt, ob man auf einer Position stehen kann.
## ascents(Vector3i) -> Array[Vector3i] nennt die Positionen auf einer anderen Ebene, die man von
## einer Position aus mit einem geraden Schritt erreicht (leer gelassen: keine).
## steppable(Vector3i, Vector3i) -> bool sagt, ob man von einer begehbaren Position auf eine
## benachbarte treten darf (leer gelassen: immer), z. B. einen Eingang nur von vorn.
## Merkt sich Begehbarkeit und erlaubte Schritte je Position; die Callables müssen also dieselben
## Antworten geben, bis der Aufrufer die betroffenen Kacheln mit forget() meldet.
class Graph:
	extends RefCounted

	## Einträge in _walkable_cache (0: noch nicht gefragt).
	const CACHED_WALKABLE := 1
	const CACHED_BLOCKED := 2

	var size: Vector3i
	var _walkable: Callable
	var _ascents: Callable
	var _steppable: Callable
	var _walkable_cache := PackedByteArray()
	## Je Index die erlaubten Schritte ohne Zusatzkosten (steps_of()); leer, solange nicht berechnet.
	var _steps: Array[PackedInt32Array] = []
	var _steps_known := PackedByteArray()
	## Bis hierher hat warm() die Indizes schon durchgesehen.
	var _warm_cursor := 0
	## Indizes, deren Schritte forget() vergessen hat, nachdem warm() an ihnen vorbei war.
	var _forgotten := PackedInt32Array()

	func _init(grid_size: Vector3i, walkable: Callable, ascents := Callable(), steppable := Callable()) -> void:
		size = grid_size
		_walkable = walkable
		_ascents = ascents
		_steppable = steppable
		var count := size.x * size.y * size.z
		_walkable_cache.resize(count)
		_steps.resize(count)
		_steps_known.resize(count)

	func contains(position: Vector3i) -> bool:
		return position.x >= 0 and position.y >= 0 and position.z >= 0 \
				and position.x < size.x and position.y < size.y and position.z < size.z

	## Index von position im Raster; position muss darin liegen (contains()).
	func index_of(position: Vector3i) -> int:
		assert(contains(position), "Position außerhalb des Rasters")
		return (position.z * size.y + position.y) * size.x + position.x

	@warning_ignore("integer_division")
	func position_of(index: int) -> Vector3i:
		var row := index / size.x
		return Vector3i(index % size.x, row % size.y, row / size.y)

	func is_walkable(position: Vector3i) -> bool:
		return _is_walkable_at(position.x, position.y, position.z)

	## Die Begehbarkeit dieser Kacheln (auf allen Ebenen) hat sich geändert: Vergisst sie und die
	## Schritte von allen Positionen, deren Schritte davon abhängen können – die Kacheln selbst und
	## alle mit gemeinsamer Kante oder Ecke, auf allen Ebenen (Ebenenwechsel gehen nur zu
	## Nachbarkacheln, steppable fragt nur nach Herkunft und Ziel eines Schritts).
	func forget(tiles: Array[Vector2i]) -> void:
		for tile in tiles:
			for z in size.z:
				for y in range(maxi(tile.y - 1, 0), mini(tile.y + 2, size.y)):
					for x in range(maxi(tile.x - 1, 0), mini(tile.x + 2, size.x)):
						var index := (z * size.y + y) * size.x + x
						if _steps_known[index] != 0 and index < _warm_cursor:
							_forgotten.append(index)
						_steps_known[index] = 0
				if contains(Vector3i(tile.x, tile.y, z)):
					_walkable_cache[(z * size.y + tile.y) * size.x + tile.x] = 0

	## Berechnet im Voraus die Schritte begehbarer Positionen, bis Time.get_ticks_usec() deadline
	## erreicht; true, wenn alle durchgesehen sind. Ändert kein Ergebnis, nur wie lange spätere
	## Suchen rechnen. Was forget() vergessen hat, kommt zuerst dran.
	func warm(deadline: int) -> bool:
		while not _forgotten.is_empty():
			if Time.get_ticks_usec() >= deadline:
				return false
			var forgotten := _forgotten[_forgotten.size() - 1]
			_forgotten.resize(_forgotten.size() - 1)
			_warm_index(forgotten)
		var count := _steps_known.size()
		while _warm_cursor < count:
			# Die Uhr nur ab und zu fragen, sie kostet selbst.
			if _warm_cursor % 64 == 0 and Time.get_ticks_usec() >= deadline:
				return false
			_warm_cursor += 1
			_warm_index(_warm_cursor - 1)
		return true

	func _warm_index(index: int) -> void:
		if _steps_known[index] == 0:
			var position := position_of(index)
			if _is_walkable_at(position.x, position.y, position.z):
				_compute_steps(index)

	## Kosten je Index für eine Suche, alle noch unendlich.
	func new_costs() -> PackedFloat64Array:
		var costs := PackedFloat64Array()
		costs.resize(_walkable_cache.size())
		costs.fill(INF)
		return costs

	## Die erlaubten Schritte von index aus in der Reihenfolge von neighbors(), je als
	## Zielindex * 2 + 1, wenn der Schritt schräg ist (sonst + 0). Mit extra_cost gilt die Eckregel
	## auch für Kacheln daneben, die von hier aus zusätzlich kosten; die Kosten selbst addiert die Suche.
	func steps_of(index: int, extra_cost: Callable) -> PackedInt32Array:
		if _steps_known[index] == 0:
			_compute_steps(index)
		var steps := _steps[index]
		if not extra_cost.is_valid():
			return steps
		var position := position_of(index)
		if position.z != Figure.Level.GROUND:
			return steps
		var result := PackedInt32Array()
		for code in steps:
			if code & 1:
				# Am Boden sind beide Kacheln neben einem erlaubten schrägen Schritt begehbar.
				var corner := position_of(code >> 1)
				if extra_cost.call(position, Vector3i(corner.x, position.y, position.z)) > 0.0 \
						or extra_cost.call(position, Vector3i(position.x, corner.y, position.z)) > 0.0:
					continue
			result.append(code)
		return result

	## Berechnet die erlaubten Schritte von index aus und merkt sie sich.
	func _compute_steps(index: int) -> void:
		var position := position_of(index)
		var x := position.x
		var y := position.y
		var z := position.z
		var width := size.x
		var up := _is_walkable_at(x, y - 1, z)
		var right := _is_walkable_at(x + 1, y, z)
		var down := _is_walkable_at(x, y + 1, z)
		var left := _is_walkable_at(x - 1, y, z)
		var steps := PackedInt32Array()
		# Reihenfolge wie STRAIGHT_STEPS, dann wie DIAGONAL_STEPS.
		_add_step(steps, position, up, index - width, 0)
		_add_step(steps, position, right, index + 1, 0)
		_add_step(steps, position, down, index + width, 0)
		_add_step(steps, position, left, index - 1, 0)
		var on_ground := z == Figure.Level.GROUND
		_add_step(steps, position, (not on_ground or up and right) and _is_walkable_at(x + 1, y - 1, z),
				index - width + 1, 1)
		_add_step(steps, position, (not on_ground or down and right) and _is_walkable_at(x + 1, y + 1, z),
				index + width + 1, 1)
		_add_step(steps, position, (not on_ground or down and left) and _is_walkable_at(x - 1, y + 1, z),
				index + width - 1, 1)
		_add_step(steps, position, (not on_ground or up and left) and _is_walkable_at(x - 1, y - 1, z),
				index - width - 1, 1)
		if _ascents.is_valid():
			for next: Vector3i in _ascents.call(position):
				_add_step(steps, position, is_walkable(next), index_of(next) if contains(next) else 0, 0)
		_steps[index] = steps
		_steps_known[index] = 1

	## Hängt den Schritt nach next an steps, wenn next offen ist und steppable ihn erlaubt.
	func _add_step(steps: PackedInt32Array, from: Vector3i, open: bool, next: int, diagonal: int) -> void:
		if open and (not _steppable.is_valid() or _steppable.call(from, position_of(next))):
			steps.append(next * 2 + diagonal)

	func _is_walkable_at(x: int, y: int, z: int) -> bool:
		if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z:
			return false
		var index := (z * size.y + y) * size.x + x
		var open := _walkable_cache[index]
		if open == 0:
			open = CACHED_WALKABLE if _walkable.call(Vector3i(x, y, z)) else CACHED_BLOCKED
			_walkable_cache[index] = open
		return open == CACHED_WALKABLE


## Vorrangwarteschlange (4-ärer Heap) über Indizes: kleinste Schätzung zuerst, dann kleinste
## Restschätzung, dann der zuerst eingefügte. Gepackte Arrays statt eines Arrays je Eintrag und
## Vergleiche ohne Hilfsfunktion, weil die Suche fast ihre ganze Zeit hier verbringt; vier Kinder
## je Knoten halbieren die Tiefe, das spart beim Absinken mehr, als die Vergleiche kosten.
class _Heap:
	var _priorities := PackedFloat64Array()
	var _rests := PackedFloat64Array()
	var _orders := PackedInt64Array()
	var _positions := PackedInt32Array()
	var _size := 0
	var _count := 0

	func is_empty() -> bool:
		return _size == 0

	func push(priority: float, rest: float, position: int) -> void:
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
			var parent := (i - 1) / 4
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

	func pop() -> int:
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
			var best := 4 * i + 1
			if best >= size:
				break
			var best_priority := _priorities[best]
			for child in range(best + 1, mini(best + 4, size)):
				var child_priority := _priorities[child]
				if child_priority < best_priority or child_priority == best_priority \
						and (_rests[child] < _rests[best] or _rests[child] == _rests[best] \
						and _orders[child] < _orders[best]):
					best = child
					best_priority = child_priority
			if priority < best_priority or priority == best_priority \
					and (rest < _rests[best] or rest == _rests[best] and order < _orders[best]):
				break
			_priorities[i] = best_priority
			_rests[i] = _rests[best]
			_orders[i] = _orders[best]
			_positions[i] = _positions[best]
			i = best
		_priorities[i] = priority
		_rests[i] = rest
		_orders[i] = order
		_positions[i] = position
		return top
