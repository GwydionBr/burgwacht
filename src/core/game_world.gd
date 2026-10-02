class_name GameWorld
extends RefCounted
## Die Spielwelt: Wurzel des gesamten Spielzustands einer Partie.
## Besitzt Karte, Gebäude, Lager, Taktzähler und den einzigen Zufallsgenerator der Simulation.
## Schreitet nur über step() voran – wer wie oft step() aufruft, liegt außerhalb des Kerns.
## Spielereingaben kommen als Befehl über execute() hinein und wirken sofort, auch ohne Takt.
##
## Eine neue Spielwelt ist in Gründung: Es vergehen keine Takte und nur der Gründungsbefehl
## ist erlaubt. Er setzt den Bergfried und das erste Warenlager mit den Startwaren.

signal deposit_added(tile: Vector2i)
signal deposit_removed(tile: Vector2i)
signal day_started(day: int)
signal building_added(id: int)
signal building_removed(id: int)
## Der Inhalt eines Lagers hat sich geändert.
signal stock_changed(building_id: int)
signal founded()

## Ein Tag dauert 600 Takte (bei 1× eine Minute).
const TICKS_PER_DAY := 600
## Formatversion des Spielstands; bei jeder inkompatiblen Änderung erhöhen.
const SAVE_VERSION := 2
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
## Ware → Menge; kommt bei der Gründung ins erste Warenlager.
var _start_goods: Dictionary[String, int] = {}
## Nach ID aufsteigend eingefügt, damit Durchläufe in fester Reihenfolge gehen (ADR 0001).
var _buildings: Dictionary[int, Building] = {}
var _next_building_id := 1
## Abgeleitet aus den Gebäuden, nicht gespeichert: Kachel → Gebäude-ID.
var _occupied: Dictionary[Vector2i, int] = {}
## Abgeleitet: Kacheln vor einem Eingang → Gebäude-ID.
var _entrance_fronts: Dictionary[Vector2i, int] = {}


## Neue Partie aus einem gültigen Szenario. Der Seed kommt vom Aufrufer
## (meist scenario.resolve_seed(…), oder ein fester Seed von der Kommandozeile).
static func create(scenario: Scenario, world_seed: int) -> GameWorld:
	assert(scenario.error == "", scenario.error)
	var world := GameWorld.new()
	world._scenario_id = scenario.id
	world._seed = world_seed
	world._start_goods = scenario.start_goods.duplicate()
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
		"next_building_id": _next_building_id,
		"buildings": _buildings.values().map(func(building: Building) -> Dictionary: return building.to_data()),
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
	world._next_building_id = int(data["next_building_id"])
	for entry: Dictionary in data["buildings"]:
		var building := Building.from_data(entry)
		world._buildings[building.id] = building
	world._rebuild_index()
	return world


## Genau ein Takt; in Gründung steht die Zeit still.
func step() -> void:
	if _founding:
		return
	_tick += 1
	_spread_deposits()
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
## der Grund. Erst placement_error(), als letzte Prüfung „genug Waren“ (Kosten aus den Daten).
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
	var cost := _cost_of(type_id)
	for good: String in cost:
		if get_stock(good) < int(cost[good]):
			return "Zu wenig %s (%d nötig)" % [_good_name(good), int(cost[good])]
	return ""


## Darf der Befehl „Gebäude abreißen“ das Gebäude mit dieser ID jetzt abreißen? Leer oder
## der Grund. Der Bergfried nie, ein Lager nur, wenn es leer ist.
func demolish_error(id: int) -> String:
	if _founding:
		return FOUNDING_FIRST
	var building := get_building(id)
	if building == null:
		return "Dieses Gebäude gibt es nicht"
	if building.type == FOUNDING_TYPE:
		return "Der Bergfried kann nicht abgerissen werden."
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
## Grund. Prüft Bergfried und erstes Warenlager (founding_storage_origin()).
func founding_error(origin: Vector2i) -> String:
	if not _founding:
		return "Die Burg ist bereits gegründet."
	var keep_error := placement_error(FOUNDING_TYPE, origin)
	if keep_error != "":
		return keep_error
	var keep_tiles: Dictionary[Vector2i, int] = {}
	for tile in Building.footprint(FOUNDING_TYPE, origin):
		keep_tiles[tile] = 0
	var storage_type := founding_storage_type()
	var storage_origin := founding_storage_origin(origin)
	var storage_error := _placement_error(storage_type, storage_origin, keep_tiles)
	if storage_error != "":
		return "%s: %s" % [_building_name(storage_type), storage_error]
	if Building.front_of_entrance(FOUNDING_TYPE, origin) in Building.footprint(storage_type, storage_origin):
		return "Eingang ist versperrt"
	return ""


## Gebäudetyp des ersten Lagers, das mit dem Bergfried entsteht.
func founding_storage_type() -> String:
	return str(_founding_storage_def()["type"])


## Ursprung des ersten Lagers, wenn der Bergfried bei keep_origin steht.
func founding_storage_origin(keep_origin: Vector2i) -> Vector2i:
	var offset: Array = _founding_storage_def()["offset"]
	return keep_origin + Vector2i(int(offset[0]), int(offset[1]))


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
	_add_building(FOUNDING_TYPE, origin)
	var storage := _add_building(founding_storage_type(), founding_storage_origin(origin))
	# Was nicht ins erste Lager passt, verfällt.
	for good: String in _start_goods:
		var amount := mini(_start_goods[good], storage.capacity() - storage.stored())
		if amount > 0:
			storage.contents[good] = storage.contents.get(good, 0) + amount
	stock_changed.emit(storage.id)
	_founding = false
	founded.emit()
	return ""


func _build(type_id: String, origin: Vector2i) -> String:
	var error := build_error(type_id, origin)
	if error != "":
		return error
	var cost := _cost_of(type_id)
	var changed: Dictionary[int, bool] = {}
	for good: String in cost:
		_take_goods(good, int(cost[good]), changed)
	_emit_stock_changed(changed)
	_add_building(type_id, origin)
	return ""


func _demolish(id: int) -> String:
	var error := demolish_error(id)
	if error != "":
		return error
	var building: Building = _buildings[id]
	_buildings.erase(id)
	# Neu aufbauen statt austragen: Vor dem Eingang kann noch ein anderes Gebäude liegen.
	_rebuild_index()
	building_removed.emit(id)
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
		var stored := mini(remaining, storage.capacity() - storage.stored())
		if stored <= 0:
			continue
		remaining -= stored
		storage.contents[good] = storage.contents.get(good, 0) + stored
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
	_entrance_fronts[building.entrance_front()] = building.id


## Wie placement_error(); extra_blocked sind zusätzlich belegte Kacheln (für die Gründung).
func _placement_error(type_id: String, origin: Vector2i, extra_blocked: Dictionary[Vector2i, int]) -> String:
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
			return "%s im Weg" % _building_name(FOUNDING_TYPE)
	var front := Building.front_of_entrance(type_id, origin)
	if not map.is_walkable(front) or map.get_deposit(front) != null \
			or _occupied.has(front) or extra_blocked.has(front):
		return "Eingang ist versperrt"
	return ""


func _founding_storage_def() -> Dictionary:
	return GameDefs.get_instance().buildings[FOUNDING_TYPE]["first_storage"]


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


## Vorkommen mit "spread" in den Daten (z. B. Bäume) breiten sich in ihrem Rhythmus aus:
## Jede freie, bebaubare Kachel neben einem solchen Vorkommen bekommt mit der
## angegebenen Chance ein neues. Grundflächen und Kacheln vor Eingängen bleiben frei. Typen und Kacheln in fester Reihenfolge (ADR 0001).
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
				and _rng.randf() < chance:
			map.add_deposit(tile, Deposit.create(type, _rng))
