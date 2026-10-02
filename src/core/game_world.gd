class_name GameWorld
extends RefCounted
## Die Spielwelt: Wurzel des gesamten Spielzustands einer Partie.
## Besitzt Karte, Gebäude, Lager, Bewohner, Taktzähler und den einzigen Zufallsgenerator der Simulation.
## Schreitet nur über step() voran – wer wie oft step() aufruft, liegt außerhalb des Kerns.
## Spielereingaben kommen als Befehl über execute() hinein und wirken sofort, auch ohne Takt.
##
## Eine neue Spielwelt ist in Gründung: Es vergehen keine Takte und nur der Gründungsbefehl
## ist erlaubt. Er setzt den Bergfried mit seinen Begleitgebäuden (erstes Warenlager und
## erster Kornspeicher mit den Startwaren ihrer Lagerart, Lagerfeuer mit den Startbewohnern
## als Untätige drumherum).
##
## In jedem Takt bekommen Arbeitsstätten mit freien Stellen Untätige zugeteilt, dann laufen
## und arbeiten die Bewohner in ID-Reihenfolge einen Takt weiter: Arbeiter eines Sammlers
## bauen Vorkommen ab, verarbeiten die Ware in der Arbeitsstätte und tragen sie ins Lager.
## Ändert sich die Burg unter ihnen (Bau, Abriss, neue oder verschwundene Vorkommen),
## weichen sie aus bzw. planen neu.

signal deposit_added(tile: Vector2i)
signal deposit_removed(tile: Vector2i)
## Die Menge eines Vorkommens hat sich geändert (abgebaut, aber nicht erschöpft).
signal deposit_changed(tile: Vector2i)
signal day_started(day: int)
signal building_added(id: int)
signal building_removed(id: int)
## Der Inhalt eines Lagers hat sich geändert.
signal stock_changed(building_id: int)
signal resident_added(id: int)
## Tätigkeit oder getragene Ware eines Bewohners hat sich geändert (zugeteilt, angekommen,
## Abbau, Verarbeitung, abgeliefert, wieder untätig …).
signal resident_changed(id: int)
signal founded()

## Ein Tag dauert 600 Takte (bei 1× eine Minute).
const TICKS_PER_DAY := 600
## Formatversion des Spielstands; bei jeder inkompatiblen Änderung erhöhen.
const SAVE_VERSION := 5
## Gebäudetyp, mit dem die Burg gegründet wird.
const FOUNDING_TYPE := "keep"
## Steht für „keine passende Stelle“ (find_founding_site()).
const NO_SITE := Vector2i(-1, -1)
## Grund für jeden anderen Befehl während der Gründung.
const FOUNDING_FIRST := "Erst die Burg gründen: Bergfried setzen."

var map: MapData

var _scenario_id: String
var _seed: int
var _tick := 0
var _rng := RandomNumberGenerator.new()
var _founding := true
## Ware → Menge; kommt bei der Gründung ins erste Lager ihrer Lagerart.
var _start_goods: Dictionary[String, int] = {}
## So viele Untätige entstehen bei der Gründung am Lagerfeuer.
var _start_residents := 0
## Nach ID aufsteigend eingefügt, damit Durchläufe in fester Reihenfolge gehen (ADR 0001).
var _buildings: Dictionary[int, Building] = {}
var _next_building_id := 1
## Abgeleitet aus den Gebäuden, nicht gespeichert: Kachel → Gebäude-ID.
var _occupied: Dictionary[Vector2i, int] = {}
## Abgeleitet: Kacheln vor einem Eingang → Gebäude-ID.
var _entrance_fronts: Dictionary[Vector2i, int] = {}
## Nach ID aufsteigend eingefügt, wie die Gebäude.
var _residents: Dictionary[int, Resident] = {}
var _next_resident_id := 1


## Neue Partie aus einem gültigen Szenario. Der Seed kommt vom Aufrufer
## (meist scenario.resolve_seed(…), oder ein fester Seed von der Kommandozeile).
static func create(scenario: Scenario, world_seed: int) -> GameWorld:
	assert(scenario.error == "", scenario.error)
	var world := GameWorld.new()
	world._scenario_id = scenario.id
	world._seed = world_seed
	world._start_goods = scenario.start_goods.duplicate()
	world._start_residents = scenario.start_residents
	world._set_map(MapGenerator.generate(world_seed, scenario.map_size.x, scenario.map_size.y))
	# Eigener Zufall, getrennt von dem der Kartenerzeugung.
	world._rng.seed = hash([world_seed, "world"])
	return world


## Der gesamte Zustand als reine Daten (Dictionaries, Arrays, Zahlen, Texte) – ohne
## Darstellung. from_data() stellt daraus eine Spielwelt her, die genauso weiterläuft.
func to_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"scenario": _scenario_id,
		"seed": _seed,
		"tick": _tick,
		"rng": {"seed": _rng.seed, "state": _rng.state},
		"map": map.to_data(),
		"founding": _founding,
		"start_goods": _start_goods.duplicate(),
		"start_residents": _start_residents,
		"next_building_id": _next_building_id,
		"buildings": _buildings.values().map(func(building: Building) -> Dictionary: return building.to_data()),
		"next_resident_id": _next_resident_id,
		"residents": _residents.values().map(func(resident: Resident) -> Dictionary: return resident.to_data()),
	}


## Leer, wenn die Formatversion passt, sonst der Grund auf Deutsch.
## Prüft nur die Version – die Daten selbst stammen aus to_data().
static func data_error(data: Dictionary) -> String:
	if not data.has("version"):
		return "Das ist kein Spielstand (Formatversion fehlt)."
	if data["version"] != SAVE_VERSION:
		return "Spielstand hat Formatversion %s, unterstützt wird nur %d." % [str(data["version"]), SAVE_VERSION]
	return ""


## Spielwelt aus den Daten von to_data(); null, wenn data_error() etwas meldet.
static func from_data(data: Dictionary) -> GameWorld:
	if data_error(data) != "":
		return null
	var world := GameWorld.new()
	world._scenario_id = str(data["scenario"])
	world._seed = int(data["seed"])
	world._tick = int(data["tick"])
	var rng_data: Dictionary = data["rng"]
	# Erst der Seed (setzt den Zustand zurück), dann der gespeicherte Zustand.
	world._rng.seed = int(rng_data["seed"])
	world._rng.state = int(rng_data["state"])
	world._set_map(MapData.from_data(data["map"]))
	world._founding = bool(data["founding"])
	var start_goods: Dictionary = data["start_goods"]
	for good: Variant in start_goods:
		world._start_goods[str(good)] = int(start_goods[good])
	world._start_residents = int(data["start_residents"])
	world._next_building_id = int(data["next_building_id"])
	for entry: Dictionary in data["buildings"]:
		var building := Building.from_data(entry)
		world._buildings[building.id] = building
	world._next_resident_id = int(data["next_resident_id"])
	for entry: Dictionary in data["residents"]:
		var resident := Resident.from_data(entry)
		world._residents[resident.id] = resident
	world._rebuild_index()
	return world


## Genau ein Takt; in Gründung steht die Zeit still.
func step() -> void:
	if _founding:
		return
	_tick += 1
	_spread_deposits()
	_assign_workers()
	_update_residents()
	if _tick % TICKS_PER_DAY == 0:
		day_started.emit(get_day())


## Führt einen Befehl sofort aus. Leer bei Erfolg, sonst der Grund auf Deutsch;
## ein abgelehnter Befehl ändert nichts.
func execute(command: Command) -> String:
	if command.kind == Command.Kind.FOUND:
		return _found(command.origin)
	if command.kind == Command.Kind.BUILD:
		return _build(command.building_type, command.origin)
	if command.kind == Command.Kind.DEMOLISH:
		return _demolish(command.building_id)
	if _founding:
		return FOUNDING_FIRST
	return "Dieser Befehl wird noch nicht unterstützt."


func is_founding() -> bool:
	return _founding


## Darf ein Gebäude vom Typ type_id mit diesem Ursprung stehen? Leer oder der Grund.
## Prüft in fester Reihenfolge, damit der Grund stabil ist: auf der Karte → Gelände
## bebaubar → keine Vorkommen → keine Gebäude → Kachel vor dem Eingang begehbar und frei.
func placement_error(type_id: String, origin: Vector2i) -> String:
	return _placement_error(type_id, origin, {})


## Darf der Befehl „Gebäude bauen“ jetzt Typ type_id mit diesem Ursprung bauen? Leer oder
## der Grund. Erst placement_error(), dann die Bauregeln des Typs, als letzte
## Prüfung „genug Waren“ (Kosten aus den Daten).
func build_error(type_id: String, origin: Vector2i) -> String:
	if _founding:
		return FOUNDING_FIRST
	if type_id == FOUNDING_TYPE:
		return "Der Bergfried entsteht nur bei der Gründung."
	if not is_buildable(type_id):
		return "„%s“ kann nicht gebaut werden." % type_id
	var placement := placement_error(type_id, origin)
	if placement != "":
		return placement
	var rules := _rules_error(type_id, origin)
	if rules != "":
		return rules
	var cost := _cost_of(type_id)
	for good: String in cost:
		if get_stock(good) < int(cost[good]):
			return "Zu wenig %s (%d nötig)" % [_good_name(good), int(cost[good])]
	return ""


## Darf der Befehl „Gebäude abreißen“ das Gebäude mit dieser ID jetzt abreißen? Leer oder
## der Grund. Typen mit "demolish_forbidden" in den Daten (Bergfried, Lagerfeuer) nie, ein
## Lager nur, wenn es leer ist.
func demolish_error(id: int) -> String:
	if _founding:
		return FOUNDING_FIRST
	var building := get_building(id)
	if building == null:
		return "Dieses Gebäude gibt es nicht"
	if building.def().has("demolish_forbidden"):
		return str(building.def()["demolish_forbidden"])
	if building.is_storage() and building.stored() > 0:
		return "%s ist nicht leer" % _building_name(building.type)
	return ""


## Darf der Spieler diesen Gebäudetyp bauen? Baubar ist, was in den Daten eine Taste für
## die Bauleiste hat; Bauleiste und Befehl richten sich beide danach.
static func is_buildable(type_id: String) -> bool:
	var def: Dictionary = GameDefs.get_instance().buildings.get(type_id, {})
	return def.has("hotkey")


## Gebäudetypen, die der Spieler bauen kann (is_buildable()), in Datenreihenfolge.
static func buildable_types() -> Array[String]:
	var result: Array[String] = []
	for type_id: String in GameDefs.get_instance().buildings:
		if is_buildable(type_id):
			result.append(type_id)
	return result


## Darf die Burg mit dem Bergfried an diesem Ursprung gegründet werden? Leer oder der
## Grund. Prüft der Reihe nach alle Gebäude der Gründung (founding_buildings()); die
## früheren gelten für die späteren als belegt, ebenso die Kacheln vor ihren Eingängen.
func founding_error(origin: Vector2i) -> String:
	if not _founding:
		return "Die Burg ist bereits gegründet."
	var blocked: Dictionary[Vector2i, String] = {}
	for part in founding_buildings(origin):
		var type_id: String = part[0]
		var part_origin: Vector2i = part[1]
		var error := _placement_error(type_id, part_origin, blocked)
		if error != "":
			return error if type_id == FOUNDING_TYPE else "%s: %s" % [_building_name(type_id), error]
		for tile in Building.footprint(type_id, part_origin):
			blocked[tile] = "%s im Weg" % _building_name(type_id)
		if Building.has_entrance_type(type_id):
			blocked[Building.front_of_entrance(type_id, part_origin)] = "Eingang ist versperrt"
	return ""


## Die Gebäude, die bei einer Gründung mit dem Bergfried bei keep_origin entstehen, als
## Paare [Gebäudetyp, Ursprung]: zuerst der Bergfried, dann seine Begleitgebäude
## ("companions" in den Daten, z. B. erstes Warenlager, Lagerfeuer und erster Kornspeicher)
## mit festem Versatz.
func founding_buildings(keep_origin: Vector2i) -> Array[Array]:
	var result: Array[Array] = [[FOUNDING_TYPE, keep_origin]]
	var companions: Array = GameDefs.get_instance().buildings[FOUNDING_TYPE]["companions"]
	for companion: Dictionary in companions:
		var offset: Array = companion["offset"]
		result.append([str(companion["type"]), keep_origin + Vector2i(int(offset[0]), int(offset[1]))])
	return result


## Die passende Gründungsstelle, deren Bergfried der Kartenmitte am nächsten liegt;
## NO_SITE, wenn es keine gibt.
@warning_ignore("integer_division")
func find_founding_site() -> Vector2i:
	var half := Building.size_of(FOUNDING_TYPE) / 2
	var center := map.center()
	var candidates: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a + half - center).length_squared()
		var db := (b + half - center).length_squared()
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	for origin in candidates:
		if founding_error(origin) == "":
			return origin
	return NO_SITE


## Alle Gebäude nach ID aufsteigend.
func get_buildings() -> Array[Building]:
	var result: Array[Building] = []
	result.assign(_buildings.values())
	return result


## null, wenn es die ID nicht gibt.
func get_building(id: int) -> Building:
	return _buildings.get(id)


## Das Gebäude, dessen Grundfläche die Kachel belegt, sonst null.
func get_building_at(tile: Vector2i) -> Building:
	return _buildings.get(_occupied.get(tile, 0))


## Alle Bewohner nach ID aufsteigend.
func get_residents() -> Array[Resident]:
	var result: Array[Resident] = []
	result.assign(_residents.values())
	return result


## null, wenn es die ID nicht gibt.
func get_resident(id: int) -> Resident:
	return _residents.get(id)


## Die Bewohner auf dieser Kachel (jede Ebene), nach ID aufsteigend.
func get_residents_at(tile: Vector2i) -> Array[Resident]:
	var result: Array[Resident] = []
	for resident: Resident in _residents.values():
		if resident.tile == tile:
			result.append(resident)
	return result


## Die Arbeiter einer Arbeitsstätte nach ID aufsteigend (0: die Untätigen).
func get_workers(building_id: int) -> Array[Resident]:
	var result: Array[Resident] = []
	for resident: Resident in _residents.values():
		if resident.workplace_id == building_id:
			result.append(resident)
	return result


## Was ein Bewohner gerade tut, als Spieltext für die Kachel-Info,
## z. B. „Holzfäller – trägt 4 Holz“.
func activity_of(resident: Resident) -> String:
	if resident.is_idle():
		return "Untätig – geht zum Lagerfeuer" if resident.is_moving() else "Untätig"
	var workplace := get_building(resident.workplace_id)
	return "%s – %s" % [workplace.worker_name(), _task_text(resident, workplace)]


## Der Teil von activity_of() nach dem Namen des Arbeiters.
func _task_text(resident: Resident, workplace: Building) -> String:
	var deposit_name := Deposit.name_of(workplace.deposit_type()) if workplace.deposit_type() != "" else ""
	var carried := "%d %s" % [resident.carried_amount, _good_name(resident.carried_good)] \
			if resident.carried_amount > 0 else ""
	if resident.is_blocked():
		return "wartet: Weg versperrt"
	match resident.task:
		Resident.Task.TO_DEPOSIT:
			return "geht zum %s" % deposit_name
		Resident.Task.MINING:
			return "baut %s ab" % deposit_name
		Resident.Task.RETURNING, Resident.Task.TO_STORAGE:
			return "trägt %s" % carried
		Resident.Task.PROCESSING:
			return "verarbeitet %s" % carried
		Resident.Task.WAITING_FOR_DEPOSIT:
			return "geht zur Arbeitsstätte" if resident.is_moving() else "wartet: Kein %s erreichbar" % deposit_name
		Resident.Task.WAITING_FOR_STORAGE:
			return "trägt %s" % carried if resident.is_moving() else "wartet: Lager voll"
	return "geht zur Arbeitsstätte" if resident.is_moving() else "an der Arbeitsstätte"


## Wie viele Bewohner ohne Arbeitsstätte sind.
func get_idle_count() -> int:
	var count := 0
	for resident: Resident in _residents.values():
		if resident.is_idle():
			count += 1
	return count


## Wohnraum der Burg: Grundwohnraum des Bergfrieds plus Summe der Wohnhäuser.
func get_housing() -> int:
	var total := 0
	for building: Building in _buildings.values():
		total += building.housing()
	return total


## Kann ein Bewohner auf dieser Kachel und Ebene stehen? Am Boden: Gelände begehbar, kein
## nicht begehbares Vorkommen, keine Grundfläche – außer Eingängen und begehbaren Gebäuden
## (Lagerfeuer).
func is_walkable(tile: Vector2i, level: Resident.Level) -> bool:
	if level != Resident.Level.GROUND or not map.is_walkable(tile):
		return false
	var deposit := map.get_deposit(tile)
	if deposit != null and not deposit.is_walkable():
		return false
	var building := get_building_at(tile)
	if building == null:
		return true
	return building.is_walkable() or (building.has_entrance() and building.entrance() == tile)


## Bestand einer Ware: Summe über alle Lager ihrer Lagerart.
func get_stock(good: String) -> int:
	var total := 0
	for building in _storages(_storage_type_of(good)):
		total += building.contents.get(good, 0)
	return total


## Wie viel in allen Lagern dieser Lagerart liegt.
func get_storage_used(storage_type: String) -> int:
	var total := 0
	for building in _storages(storage_type):
		total += building.stored()
	return total


## Wie viel alle Lager dieser Lagerart zusammen fassen.
func get_storage_capacity(storage_type: String) -> int:
	var total := 0
	for building in _storages(storage_type):
		total += building.capacity()
	return total


func get_scenario_id() -> String:
	return _scenario_id


func get_seed() -> int:
	return _seed


func get_tick() -> int:
	return _tick


## Der erste Tag ist Tag 1.
@warning_ignore("integer_division")
func get_day() -> int:
	return _tick / TICKS_PER_DAY + 1


func _found(origin: Vector2i) -> String:
	var error := founding_error(origin)
	if error != "":
		return error
	var campfire: Building = null
	for part in founding_buildings(origin):
		var building := _add_building(part[0], part[1])
		if campfire == null and building.is_campfire():
			campfire = building
	# Startwaren ins Lager ihrer Lagerart; was nicht passt, verfällt.
	var changed: Dictionary[int, bool] = {}
	for good: String in _start_goods:
		_store_goods(good, _start_goods[good], changed)
	_emit_stock_changed(changed)
	assert(campfire != null, "Unter den Begleitgebäuden des Bergfrieds fehlt das Lagerfeuer")
	_add_start_residents(campfire)
	_founding = false
	founded.emit()
	return ""


## Die Startbewohner als Untätige auf freien, begehbaren Kacheln um das Lagerfeuer: nächste
## Kacheln zuerst, bei gleichem Abstand im Uhrzeigersinn ab „oben“ (kleineres y). Passen
## nicht alle auf die Karte, entstehen nur so viele, wie Platz haben.
func _add_start_residents(campfire: Building) -> void:
	var placed := 0
	# Erst nahe Kacheln, bei Bedarf weiter hinaus (Radius verdoppeln, Reihenfolge wie
	# vorher); schon Besetzte zählen dann als belegt.
	var radius := 2
	while placed < _start_residents and radius <= 2 * maxi(map.width, map.height):
		for offset in _offsets_within(radius):
			if placed == _start_residents:
				break
			var tile := campfire.origin + offset
			# Nicht auf Eingänge oder das Lagerfeuer selbst, obwohl begehbar.
			if is_walkable(tile, Resident.Level.GROUND) and get_building_at(tile) == null \
					and get_residents_at(tile).is_empty():
				_add_resident(tile, Resident.Level.GROUND)
				placed += 1
		radius *= 2


## Alle Versätze bis zum Abstand radius (ohne (0, 0)): nächste zuerst, bei gleichem
## Abstand im Uhrzeigersinn ab „oben“.
static func _offsets_within(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var offset := Vector2i(x, y)
			if offset != Vector2i.ZERO and offset.length_squared() <= radius * radius:
				result.append(offset)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := a.length_squared()
		var db := b.length_squared()
		return da < db if da != db else _clockwise_angle(a) < _clockwise_angle(b))
	return result


## Winkel einer Richtung im Uhrzeigersinn ab „oben“ (0, -1), von 0 bis unter TAU.
static func _clockwise_angle(direction: Vector2i) -> float:
	return fposmod(atan2(float(direction.y), float(direction.x)) + PI / 2.0, TAU)


## Zuteilung: Arbeitsstätten in ID-Reihenfolge bekommen für jede freie Stelle den
## Untätigen mit der kleinsten ID, der einen Weg zum Eingang hat. Hat keiner einen, bleibt
## die Stelle frei, die Arbeitsstätte gilt als nicht erreichbar und wird erst nach der
## Wartezeit (Resident.retry_ticks()) erneut geprüft. Ohne Untätige gibt es nichts zu prüfen
## und keine gilt als nicht erreichbar.
func _assign_workers() -> void:
	for building: Building in _buildings.values():
		if not building.is_workplace() or _tick < building.retry_tick:
			continue
		var open_slots := building.worker_slots() - get_workers(building.id).size()
		while open_slots > 0:
			var idle := get_workers(0)
			var assigned := false
			for resident in idle:
				if _route_to(resident, Resident.ground(building.entrance())):
					resident.workplace_id = building.id
					resident.task = Resident.Task.TO_WORKPLACE
					# Ein Untätiger kann noch auf einen neuen Versuch zum Lagerfeuer warten.
					resident.timer = 0
					resident_changed.emit(resident.id)
					assigned = true
					break
			building.unreachable = not idle.is_empty() and not assigned
			if building.unreachable:
				building.retry_tick = _tick + Resident.retry_ticks()
			if not assigned:
				break
			open_slots -= 1


## Alle Bewohner laufen bzw. arbeiten in ID-Reihenfolge einen Takt weiter. Gemeldet wird
## höchstens einmal je Bewohner und Takt, wenn sich Tätigkeit, Ware oder Laufen geändert hat.
func _update_residents() -> void:
	for resident: Resident in _residents.values():
		var before := _visible_state(resident)
		if resident.is_targeting_deposit(resident.deposit_tile) \
				and not _has_deposit_for(resident.deposit_tile, get_building(resident.workplace_id)):
			# Das angesteuerte Vorkommen ist weg (erschöpft, ersetzt): gleich ein neues suchen.
			_seek_deposit(resident, get_building(resident.workplace_id))
		if resident.is_moving() and not _is_walkable_position(resident.path[0]):
			_reroute(resident)
		if resident.is_moving():
			# Wer nach versperrtem Weg auf einen neuen Versuch wartet, kommt nirgends an.
			if resident.advance() and resident.timer == 0:
				_arrive(resident)
		else:
			_work(resident)
		if _visible_state(resident) != before:
			resident_changed.emit(resident.id)


## Was sich an einem Bewohner von außen sehen lässt (für resident_changed).
func _visible_state(resident: Resident) -> Array:
	return [resident.workplace_id, resident.task, resident.carried_good, resident.carried_amount, resident.is_moving()]


## Ein Arbeiter ist am Ende seines Weges angekommen: der nächste Schritt im Arbeitsablauf.
func _arrive(resident: Resident) -> void:
	var workplace := get_building(resident.workplace_id)
	if workplace == null or workplace.deposit_type() == "":
		return
	match resident.task:
		Resident.Task.TO_WORKPLACE:
			_seek_deposit(resident, workplace)
		Resident.Task.TO_DEPOSIT:
			if not _has_deposit_for(resident.deposit_tile, workplace):
				_seek_deposit(resident, workplace)
			else:
				resident.task = Resident.Task.MINING
				resident.timer = workplace.mine_ticks()
		Resident.Task.RETURNING:
			resident.task = Resident.Task.PROCESSING
			resident.timer = workplace.process_ticks()
		Resident.Task.TO_STORAGE:
			_deliver(resident, workplace)


## Ein Takt Arbeit oder Warten für einen stehenden Arbeiter.
func _work(resident: Resident) -> void:
	if resident.timer == 0:
		return
	resident.timer -= 1
	if resident.timer > 0:
		return
	var workplace := get_building(resident.workplace_id)
	match resident.task:
		Resident.Task.MINING:
			# Ist das Vorkommen weg, hat _update_residents() schon ein neues gesucht.
			resident.carried_good = map.get_deposit(resident.deposit_tile).good()
			resident.carried_amount = map.take_from_deposit(resident.deposit_tile, workplace.carry_load())
			_go(resident, workplace.entrance(), Resident.Task.RETURNING)
		Resident.Task.PROCESSING:
			_seek_storage(resident, workplace)
		_:
			_resume(resident)


## Nimmt den Arbeitsschritt wieder auf – nach der Wartezeit oder wenn der Weg versperrt und
## das Ziel nicht mehr erreichbar ist: Untätige gehen zum Lagerfeuer, Arbeiter suchen ihr
## Vorkommen bzw. Lager neu oder gehen (wieder) zur Arbeitsstätte. Ist auch das nicht
## erreichbar, greift die jeweilige Warteregel.
func _resume(resident: Resident) -> void:
	var workplace := get_building(resident.workplace_id)
	if workplace == null:
		_send_to_campfire(resident)
		return
	match resident.task:
		Resident.Task.TO_DEPOSIT, Resident.Task.WAITING_FOR_DEPOSIT:
			_seek_deposit(resident, workplace)
		Resident.Task.TO_STORAGE, Resident.Task.WAITING_FOR_STORAGE:
			_seek_storage(resident, workplace)
		_:
			_go(resident, workplace.entrance(), resident.task)


## Der Weg ist versperrt (Gebäude, Vorkommen): neuer Weg zum selben Ziel; gibt es keinen,
## nimmt er den Arbeitsschritt neu auf (_resume()). Ist schon die Kachel versperrt, auf die
## er gerade tritt, kehrt er auf seine zurück.
func _reroute(resident: Resident) -> void:
	if not _is_walkable_position(resident.path[0]):
		resident.step_progress = 0
	if not _route_to(resident, resident.path.back()):
		_resume(resident)


## Liegt auf der Kachel (noch) ein Vorkommen, das die Arbeitsstätte abbaut? Ein geteilter
## Felsen kann inzwischen erschöpft und dort ein Baum gewachsen sein.
func _has_deposit_for(tile: Vector2i, workplace: Building) -> bool:
	var deposit := map.get_deposit(tile)
	return deposit != null and deposit.type == workplace.deposit_type()


## Schickt einen Arbeiter mit diesem Auftrag zu tile. Steht er schon dort, kommt er sofort
## an; gibt es keinen Weg, bleibt er stehen und versucht es nach der Wartezeit erneut
## (_work() → _resume()).
func _go(resident: Resident, tile: Vector2i, task: Resident.Task) -> void:
	resident.task = task
	resident.timer = 0
	if not _route_to(resident, Resident.ground(tile)):
		resident.stop()
		resident.timer = Resident.retry_ticks()
	elif not resident.is_moving():
		_arrive(resident)


## Sucht das nächste passende Vorkommen und schickt den Arbeiter hin (exklusive sind damit
## reserviert); gibt es keins, wartet er in der Arbeitsstätte und sucht nach der Wartezeit erneut.
## Erreicht er sie nicht, wartet er, wo er ist, und geht danach erneut zur Arbeitsstätte.
func _seek_deposit(resident: Resident, workplace: Building) -> void:
	var found := _nearest_deposit(resident, workplace)
	if found.is_empty():
		_go(resident, workplace.entrance(), Resident.Task.WAITING_FOR_DEPOSIT)
		if resident.timer > 0:
			# Kein Weg (_go() hat die Wartezeit gesetzt): Er wartet sichtbar draußen und will
			# danach wieder zur Arbeitsstätte.
			resident.task = Resident.Task.TO_WORKPLACE
		resident.timer = Resident.retry_ticks()
		return
	resident.deposit_tile = found[0]
	_go(resident, found[1], Resident.Task.TO_DEPOSIT)


## Das nach Weglänge ab dem Eingang nächste Vorkommen vom Typ der Arbeitsstätte innerhalb
## ihres Suchradius (gemessen bis zur Kachel, von der aus abgebaut wird), das kein anderer
## reserviert hat, als [Kachel des Vorkommens, Kachel
## daneben zum Abbauen]; leer, wenn es keins gibt. Abgebaut wird von einer begehbaren Kachel
## mit gemeinsamer Kante. Bei gleicher Weglänge zuerst die kleinere Kachel (zeilenweise).
func _nearest_deposit(resident: Resident, workplace: Building) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_length := INF
	var distances := Pathfinder.distances(Resident.ground(workplace.entrance()), _is_walkable_position,
			workplace.gather_range())
	for position: Vector3i in distances:
		var stand := Vector2i(position.x, position.y)
		var length := distances[position]
		for step: Vector3i in Pathfinder.STRAIGHT_STEPS:
			var tile := stand + Vector2i(step.x, step.y)
			var deposit := map.get_deposit(tile)
			if deposit == null or deposit.type != workplace.deposit_type() or _is_reserved(tile, resident):
				continue
			var better := length < best_length and not Pathfinder.same_length(length, best_length)
			if not better and Pathfinder.same_length(length, best_length):
				better = _row_order(tile, best[0]) or (tile == best[0] and _row_order(stand, best[1]))
			if better:
				best = [tile, stand]
				best_length = length
	return best


## Liegt a zeilenweise vor b (erst kleineres y, dann kleineres x)?
static func _row_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y if a.y != b.y else a.x < b.x


## Hat ein anderer Bewohner das exklusive Vorkommen auf der Kachel für sich?
func _is_reserved(tile: Vector2i, resident: Resident) -> bool:
	if not map.get_deposit(tile).is_exclusive():
		return false
	for other: Resident in _residents.values():
		if other != resident and other.is_targeting_deposit(tile):
			return true
	return false


## Schickt einen Arbeiter mit Ware zum nach Weglänge nächsten Lager ihrer Lagerart mit
## freiem Platz (bei gleicher Länge kleinere ID); gibt es keins, wartet er mit der Ware an
## der Arbeitsstätte und versucht es nach der Wartezeit erneut.
func _seek_storage(resident: Resident, workplace: Building) -> void:
	var distances := Pathfinder.distances(resident.plan_start(), _is_walkable_position)
	var best: Building = null
	var best_length := INF
	for storage in _storages(_storage_type_of(resident.carried_good)):
		var entrance := Resident.ground(storage.entrance())
		if storage.stored() >= storage.capacity() or not distances.has(entrance):
			continue
		# Lager kommen nach ID aufsteigend: bei gleicher Länge bleibt das frühere.
		if distances[entrance] < best_length and not Pathfinder.same_length(distances[entrance], best_length):
			best = storage
			best_length = distances[entrance]
	if best == null:
		_go(resident, workplace.entrance(), Resident.Task.WAITING_FOR_STORAGE)
		resident.timer = Resident.retry_ticks()
		return
	resident.storage_id = best.id
	_go(resident, best.entrance(), Resident.Task.TO_STORAGE)


## Am Lager: so viel einlagern, wie passt; den Rest zum nächsten Lager mit Platz, danach
## zurück zur Arbeitsstätte.
func _deliver(resident: Resident, workplace: Building) -> void:
	var storage := get_building(resident.storage_id)
	resident.storage_id = 0
	if storage != null and storage.is_storage():
		var stored := storage.store(resident.carried_good, resident.carried_amount)
		if stored > 0:
			resident.carried_amount -= stored
			stock_changed.emit(storage.id)
	if resident.carried_amount > 0:
		_seek_storage(resident, workplace)
		return
	resident.carried_good = ""
	_go(resident, workplace.entrance(), Resident.Task.TO_WORKPLACE)


## Plant den kürzesten Weg eines Bewohners zu goal und schickt ihn los; false (und nichts
## ändert sich), wenn es keinen Weg gibt. Mitten im Schritt geht er den erst zu Ende.
func _route_to(resident: Resident, goal: Vector3i) -> bool:
	var start := resident.plan_start()
	var path := Pathfinder.find_path(start, goal, _is_walkable_position)
	if path.is_empty():
		return false
	if resident.step_progress == 0:
		path.pop_front()
	resident.path = path
	return true


## Schickt einen Untätigen zu einer freien Kachel am Lagerfeuer (Reihenfolge wie bei den
## Startbewohnern); frei heißt: niemand steht dort oder ist dorthin unterwegs. Ist keine
## erreichbar, bleibt er, wo er ist, und versucht es nach der Wartezeit erneut (_work()).
func _send_to_campfire(resident: Resident) -> void:
	var campfire := _campfire()
	var taken: Dictionary[Vector2i, bool] = {}
	for other: Resident in _residents.values():
		if other != resident:
			taken[other.destination()] = true
	var ground := Resident.Level.GROUND
	# Erreicht er das Lagerfeuer gar nicht, braucht er die Kacheln drumherum nicht zu prüfen.
	if Pathfinder.find_path(resident.plan_start(), Resident.ground(campfire.origin), _is_walkable_position).is_empty():
		resident.stop()
		resident.timer = Resident.retry_ticks()
		return
	var radius := 2
	while radius <= 2 * maxi(map.width, map.height):
		for offset in _offsets_within(radius):
			var tile := campfire.origin + offset
			if not taken.has(tile) and is_walkable(tile, ground) and get_building_at(tile) == null \
					and _route_to(resident, Resident.ground(tile)):
				return
		radius *= 2
	resident.stop()
	resident.timer = Resident.retry_ticks()


## Das Lagerfeuer (entsteht bei der Gründung).
func _campfire() -> Building:
	for building: Building in _buildings.values():
		if building.is_campfire():
			return building
	assert(false, "Kein Lagerfeuer in der Spielwelt")
	return null


func _is_walkable_position(position: Vector3i) -> bool:
	return is_walkable(Vector2i(position.x, position.y), position.z as Resident.Level)


func _add_resident(tile: Vector2i, level: Resident.Level) -> Resident:
	var resident := Resident.create(_next_resident_id, tile, level)
	_next_resident_id += 1
	_residents[resident.id] = resident
	resident_added.emit(resident.id)
	return resident


func _build(type_id: String, origin: Vector2i) -> String:
	var error := build_error(type_id, origin)
	if error != "":
		return error
	var cost := _cost_of(type_id)
	var changed: Dictionary[int, bool] = {}
	for good: String in cost:
		_take_goods(good, int(cost[good]), changed)
	_emit_stock_changed(changed)
	_make_way(_add_building(type_id, origin))
	return ""


## Bewohner auf der Grundfläche eines neuen Gebäudes weichen auf die nächste begehbare
## Kachel aus, von der aus sie ihren Anker erreichen (_anchor_of()), sonst auf die nächste
## begehbare; wer unterwegs ist und nun über die Grundfläche müsste, plant neu. Wer dort
## abgebaut hat, sucht sein Vorkommen neu.
func _make_way(building: Building) -> void:
	# In diesem Abstand liegt von jeder Kachel der Grundfläche aus der ganze Rand um sie herum.
	var size := Building.size_of(building.type)
	var reach := ceili(Vector2(size).length())
	for resident: Resident in _residents.values():
		var before := _visible_state(resident)
		if not is_walkable(resident.tile, resident.level):
			resident.tile = _nearest_reachable(resident.tile, _anchor_of(resident), reach)
			resident.step_progress = 0
			if resident.is_moving():
				_reroute(resident)
			elif resident.task == Resident.Task.MINING:
				_seek_deposit(resident, get_building(resident.workplace_id))
		elif resident.is_moving() and _crosses(resident, building):
			_reroute(resident)
		if _visible_state(resident) != before:
			resident_changed.emit(resident.id)


## Führt der restliche Weg des Bewohners über die Grundfläche des Gebäudes (außer dem Eingang)?
func _crosses(resident: Resident, building: Building) -> bool:
	for position in resident.path:
		var tile := Vector2i(position.x, position.y)
		if get_building_at(tile) == building and not is_walkable(tile, position.z as Resident.Level):
			return true
	return false


## Woran gemessen wird, ob ein verdrängter Bewohner nicht abgeschnitten ist: Arbeiter am
## Eingang ihrer Arbeitsstätte (von dort aus suchen sie Vorkommen und Lager), Untätige am
## Lagerfeuer.
func _anchor_of(resident: Resident) -> Vector3i:
	var workplace := get_building(resident.workplace_id)
	if workplace != null:
		return Resident.ground(workplace.entrance())
	return Resident.ground(_campfire().origin)


## Die nächste begehbare Kachel am Boden, von der aus anchor erreichbar ist: Suche nach
## außen, Reihenfolge wie am Lagerfeuer (_offsets_within()), bis zum Abstand reach.
## Abgeschlossene Taschen werden so übersprungen; ist anchor in der Nähe von keiner aus
## erreichbar, die nächste begehbare, gibt es gar keine, die Kachel selbst.
func _nearest_reachable(tile: Vector2i, anchor: Vector3i, reach: int) -> Vector2i:
	var nearest := tile
	var found := false
	# Meist erreicht schon die nächste begehbare Kachel den Anker (ein Weg). Sonst wird
	# einmal alles gemessen, was vom Anker aus erreichbar ist (selten, aber die ganze Burg).
	var reachable: Dictionary[Vector3i, float] = {}
	var radius := 2
	while radius <= 2 * maxi(map.width, map.height):
		for offset in _offsets_within(radius):
			var candidate := tile + offset
			if not is_walkable(candidate, Resident.Level.GROUND):
				continue
			if not found:
				found = true
				nearest = candidate
				if not Pathfinder.find_path(Resident.ground(candidate), anchor, _is_walkable_position).is_empty():
					return candidate
				reachable = Pathfinder.distances(anchor, _is_walkable_position)
			elif offset.length_squared() <= reach * reach and reachable.has(Resident.ground(candidate)):
				return candidate
		if found and radius >= reach:
			return nearest
		radius *= 2
	return nearest


func _demolish(id: int) -> String:
	var error := demolish_error(id)
	if error != "":
		return error
	var building: Building = _buildings[id]
	_buildings.erase(id)
	# Neu aufbauen statt austragen: Vor dem Eingang kann noch ein anderes Gebäude liegen.
	_rebuild_index()
	building_removed.emit(id)
	# Wer Ware zu diesem Lager trägt, sucht gleich ein anderes.
	for resident: Resident in _residents.values():
		if resident.task == Resident.Task.TO_STORAGE and resident.storage_id == id:
			var before := _visible_state(resident)
			_seek_storage(resident, get_building(resident.workplace_id))
			if _visible_state(resident) != before:
				resident_changed.emit(resident.id)
	# Die Arbeiter werden wieder Untätige und gehen zum Lagerfeuer.
	for worker in get_workers(id):
		worker.workplace_id = 0
		worker.clear_work()
		_send_to_campfire(worker)
		resident_changed.emit(worker.id)
	# Die Hälfte der Kosten je Ware (abgerundet) zurück; was nicht mehr passt, verfällt.
	var cost := _cost_of(building.type)
	var changed: Dictionary[int, bool] = {}
	for good: String in cost:
		@warning_ignore("integer_division")
		_store_goods(good, int(cost[good]) / 2, changed)
	_emit_stock_changed(changed)
	return ""


## Lagert bis zu amount einer Ware in die Lager ihrer Lagerart ein, ältestes zuerst; was
## nicht passt, verfällt. Betroffene Lager-IDs kommen in changed.
func _store_goods(good: String, amount: int, changed: Dictionary[int, bool]) -> void:
	var remaining := amount
	for storage in _storages(_storage_type_of(good)):
		if remaining == 0:
			break
		var stored := storage.store(good, remaining)
		if stored > 0:
			remaining -= stored
			changed[storage.id] = true


## Meldet die geänderten Lager nach ID aufsteigend.
func _emit_stock_changed(changed: Dictionary[int, bool]) -> void:
	var changed_ids: Array[int] = changed.keys()
	changed_ids.sort()
	for id in changed_ids:
		stock_changed.emit(id)


## Entnimmt amount einer Ware aus den Lagern ihrer Lagerart, ältestes zuerst; der Bestand
## muss reichen. Betroffene Lager-IDs kommen in changed.
func _take_goods(good: String, amount: int, changed: Dictionary[int, bool]) -> void:
	var remaining := amount
	for storage in _storages(_storage_type_of(good)):
		if remaining == 0:
			break
		var taken := mini(remaining, storage.contents.get(good, 0))
		if taken == 0:
			continue
		remaining -= taken
		storage.contents[good] -= taken
		if storage.contents[good] == 0:
			storage.contents.erase(good)
		changed[storage.id] = true
	assert(remaining == 0, "Zu wenig %s im Lager" % good)


func _add_building(type_id: String, origin: Vector2i) -> Building:
	var building := Building.create(_next_building_id, type_id, origin)
	_next_building_id += 1
	_buildings[building.id] = building
	_index_building(building)
	building_added.emit(building.id)
	return building


func _rebuild_index() -> void:
	_occupied.clear()
	_entrance_fronts.clear()
	for building: Building in _buildings.values():
		_index_building(building)


func _index_building(building: Building) -> void:
	for tile in building.tiles():
		_occupied[tile] = building.id
	if building.has_entrance():
		_entrance_fronts[building.entrance_front()] = building.id


## Wie placement_error(); extra_blocked sind zusätzlich belegte Kacheln mit dem Grund,
## falls die Grundfläche sie trifft (für die Gründung).
func _placement_error(type_id: String, origin: Vector2i, extra_blocked: Dictionary[Vector2i, String]) -> String:
	var tiles := Building.footprint(type_id, origin)
	for tile in tiles:
		if not map.in_bounds(tile):
			return "Außerhalb der Karte"
	var terrain_defs := GameDefs.get_instance().terrain
	for tile in tiles:
		var terrain_def: Dictionary = terrain_defs[map.get_terrain(tile)]
		if not terrain_def["buildable"]:
			return "%s ist nicht bebaubar" % terrain_def["name"]
	for tile in tiles:
		var deposit := map.get_deposit(tile)
		if deposit != null:
			return "%s im Weg" % GameDefs.get_instance().deposits[deposit.type]["name"]
	for tile in tiles:
		if _occupied.has(tile):
			return "%s im Weg" % _building_name(_buildings[_occupied[tile]].type)
		if extra_blocked.has(tile):
			return extra_blocked[tile]
	if not Building.has_entrance_type(type_id):
		return ""
	var front := Building.front_of_entrance(type_id, origin)
	if not map.is_walkable(front) or map.get_deposit(front) != null \
			or _occupied.has(front) or extra_blocked.has(front):
		return "Eingang ist versperrt"
	return ""


## Die Bauregeln eines Gebäudetyps ("rules" in buildings.json) in Datenreihenfolge:
## leer, wenn alle gelten, sonst der Grund ("reason") der ersten verletzten.
func _rules_error(type_id: String, origin: Vector2i) -> String:
	var rules: Array = GameDefs.get_instance().buildings[type_id].get("rules", [])
	for rule: Dictionary in rules:
		if not _rule_holds(type_id, origin, rule):
			return str(rule["reason"])
	return ""


## Gilt eine Bauregel für ein Gebäude dieses Typs an diesem Ursprung? „Grenzen“ heißt:
## auf einer Kachel direkt neben der Grundfläche (Building.adjacent_tiles(), nicht schräg).
func _rule_holds(type_id: String, origin: Vector2i, rule: Dictionary) -> bool:
	var kind := str(rule["kind"])
	var adjacent := Building.adjacent_tiles(type_id, origin)
	if kind == "next_to_same_storage":
		# Gibt es gerade kein Lager dieser Lagerart, darf das neue überall stehen.
		var storage_type := Building.storage_type_of(type_id)
		assert(storage_type != "", "Bauregel „%s“ bei „%s“, das kein Lager ist" % [kind, type_id])
		if _storages(storage_type).is_empty():
			return true
		for tile in adjacent:
			var other := get_building_at(tile)
			if other != null and other.is_storage() and other.storage_type() == storage_type:
				return true
		return false
	if kind == "next_to_deposit":
		var deposit_type := str(rule["deposit"])
		for tile in adjacent:
			var deposit := map.get_deposit(tile)
			if deposit != null and deposit.type == deposit_type:
				return true
		return false
	assert(false, "Unbekannte Bauregel „%s“ bei „%s“" % [kind, type_id])
	return false


func _building_name(type_id: String) -> String:
	return str(GameDefs.get_instance().buildings[type_id]["name"])


## Baukosten eines Gebäudetyps: Ware → Menge.
func _cost_of(type_id: String) -> Dictionary:
	return GameDefs.get_instance().buildings[type_id]["cost"]


func _good_name(good: String) -> String:
	return str(GameDefs.get_instance().goods[good]["name"])


func _storage_type_of(good: String) -> String:
	return str(GameDefs.get_instance().goods[good]["storage"])


## Lager dieser Lagerart nach ID aufsteigend.
func _storages(storage_type: String) -> Array[Building]:
	var result: Array[Building] = []
	for building: Building in _buildings.values():
		if building.is_storage() and building.storage_type() == storage_type:
			result.append(building)
	return result


func _set_map(new_map: MapData) -> void:
	map = new_map
	map.deposit_added.connect(deposit_added.emit)
	map.deposit_removed.connect(deposit_removed.emit)
	map.deposit_changed.connect(deposit_changed.emit)


## Vorkommen mit "spread" in den Daten (z. B. Bäume) breiten sich in ihrem Rhythmus aus:
## Jede freie, bebaubare Kachel neben einem solchen Vorkommen bekommt mit der
## angegebenen Chance ein neues. Grundflächen, Kacheln vor Eingängen und Kacheln, auf denen
## ein Bewohner steht, bleiben frei. Typen und Kacheln in fester Reihenfolge (ADR 0001).
func _spread_deposits() -> void:
	var defs := GameDefs.get_instance().deposits
	var types: Array[String] = []
	types.assign(defs.keys())
	types.sort()
	for type: String in types:
		var deposit_def: Dictionary = defs[type]
		if not deposit_def.has("spread"):
			continue
		var spread: Dictionary = deposit_def["spread"]
		if _tick % int(spread["interval_ticks"]) == 0:
			_spread_type(type, float(spread["chance"]))


@warning_ignore("integer_division")
func _spread_type(type: String, chance: float) -> void:
	var standing: Dictionary[Vector2i, bool] = {}
	for resident: Resident in _residents.values():
		standing[resident.tile] = true
	# Kacheln neben einem Vorkommen dieses Typs markieren, dann zeilenweise würfeln.
	var near_mask := PackedByteArray()
	near_mask.resize(map.width * map.height)
	for tile: Vector2i in map.deposits:
		if map.deposits[tile].type != type:
			continue
		for y in range(maxi(tile.y - 1, 0), mini(tile.y + 2, map.height)):
			for x in range(maxi(tile.x - 1, 0), mini(tile.x + 2, map.width)):
				near_mask[y * map.width + x] = 1
	for i in near_mask.size():
		if near_mask[i] == 0:
			continue
		var tile := Vector2i(i % map.width, i / map.width)
		if map.is_buildable(tile) and not _occupied.has(tile) and not _entrance_fronts.has(tile) \
				and _rng.randf() < chance and not standing.has(tile):
			map.add_deposit(tile, Deposit.create(type, _rng))
