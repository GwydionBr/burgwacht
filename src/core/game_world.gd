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
##
## Zu Beginn jedes Tags essen die Bewohner gemäß der Ration aus den Kornspeichern, zahlen gemäß
## dem Steuersatz Gold in den Schatz, und die Beliebtheit ändert sich um die Summe der Faktoren
## (Ration, Vielfalt, Steuersatz).
##
## Nach der Beliebtheit kommen und gehen Bewohner: Liegt sie über dem Gleichgewicht
## (population.json), kommt in regelmäßigem Abstand ein neuer vom Kartenrand zum Lagerfeuer,
## solange Wohnraum frei ist; liegt sie darunter, geht einer zum Kartenrand. Mehr Bewohner als
## Wohnraum: Die Überzähligen gehen sofort.

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
## Ein gehender Bewohner hat die Burg verlassen und ist fort.
signal resident_removed(id: int)
## Tätigkeit oder getragene Ware eines Bewohners hat sich geändert (zugeteilt, angekommen,
## Abbau, Verarbeitung, abgeliefert, wieder untätig …).
signal resident_changed(id: int)
signal founded()
## Die Beliebtheit hat sich geändert.
signal popularity_changed()
## Das Gold im Schatz hat sich geändert.
signal treasury_changed()
## Die Faktoren haben sich geändert (zu Tagesbeginn).
signal factors_changed()
## Eine Einstellung des Spielers (Ration, Steuersatz) hat sich geändert.
signal settings_changed()
## Eine Meldung für den Spieler, z. B. bei Nahrungsmangel.
signal notice(text: String)

## Ein Tag dauert 600 Takte (bei 1× eine Minute).
const TICKS_PER_DAY := 600
## Formatversion des Spielstands; bei jeder inkompatiblen Änderung erhöhen.
const SAVE_VERSION := 8
## Zuschlag vor dem Abrunden gegen Rundungsfehler der Kommazahlen (5 × 0,6 darf nicht 2,999… ergeben).
const ROUNDING_SLACK := 0.000001
## Gebäudetyp, mit dem die Burg gegründet wird.
const FOUNDING_TYPE := "keep"
## Steht für „keine passende Stelle“ (find_founding_site()).
const NO_SITE := Vector2i(-1, -1)
## Grund für jeden anderen Befehl während der Gründung.
const FOUNDING_FIRST := "Erst die Burg gründen: Bergfried setzen."
## Schlüssel in den Baukosten für Gold aus dem Schatz (keine Ware).
const GOLD := "gold"

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
## Wie gern die Bewohner in der Burg leben, 0–100.
var _popularity := Scenario.DEFAULT_POPULARITY
## Die eingestellte Ration (population.json).
var _ration := ""
## Der eingestellte Steuersatz (population.json).
var _tax_rate := ""
## Gold im Schatz; keine Ware, liegt in keinem Lager.
var _treasury := 0
## Die am letzten Tag tatsächlich gegessene Ration; leer vor dem ersten Tag.
var _eaten_ration := ""
## War sie am letzten Tag wegen Mangels kleiner als die damals eingestellte?
var _short_of_food := false
## Die Faktoren des letzten Tags; leer vor dem ersten Tag.
var _factors: Array[Factor] = []
## Takte seit der letzten Ankunft bzw. dem letzten Abgang; ruht, solange niemand kommen oder
## gehen kann.
var _migration_ticks := 0


## Was zu Tagesbeginn gegessen wird: die tatsächliche Ration und je Nahrungsware die Menge.
class Meal:
	var ration: String
	## Ware → Menge, nur verzehrte Sorten, in der Reihenfolge der Waren.
	var amounts: Dictionary[String, int] = {}


## Neue Partie aus einem gültigen Szenario. Der Seed kommt vom Aufrufer
## (meist scenario.resolve_seed(…), oder ein fester Seed von der Kommandozeile).
static func create(scenario: Scenario, world_seed: int) -> GameWorld:
	assert(scenario.error == "", scenario.error)
	var world := GameWorld.new()
	world._scenario_id = scenario.id
	world._seed = world_seed
	world._start_goods = scenario.start_goods.duplicate()
	world._start_residents = scenario.start_residents
	world._popularity = scenario.start_popularity
	world._ration = Population.default_ration()
	world._tax_rate = Population.default_tax_rate()
	world._treasury = scenario.start_gold
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
		"popularity": _popularity,
		"ration": _ration,
		"tax_rate": _tax_rate,
		"treasury": _treasury,
		"eaten_ration": _eaten_ration,
		"short_of_food": _short_of_food,
		"factors": _factors.map(func(factor: Factor) -> Dictionary: return factor.to_data()),
		"migration_ticks": _migration_ticks,
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
	world._popularity = int(data["popularity"])
	world._ration = str(data["ration"])
	world._tax_rate = str(data["tax_rate"])
	world._treasury = int(data["treasury"])
	world._eaten_ration = str(data["eaten_ration"])
	world._short_of_food = bool(data["short_of_food"])
	for entry: Dictionary in data["factors"]:
		world._factors.append(Factor.from_data(entry))
	world._migration_ticks = int(data["migration_ticks"])
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
	_migrate()
	if _tick % TICKS_PER_DAY == 0:
		_start_day()
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
	if command.kind == Command.Kind.SET_RATION:
		return _set_ration(command.ration)
	if command.kind == Command.Kind.SET_TAX_RATE:
		return _set_tax_rate(command.tax_rate)
	if command.kind == Command.Kind.TRADE:
		return _trade(command.good, command.buying)
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
## der Grund. Erst placement_error(), dann die Bauregeln des Typs, dann „genug Waren“ und
## als letzte Prüfung „genug Gold“ (Kosten aus den Daten).
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
	var cost := goods_cost_of(type_id)
	for good: String in cost:
		var stock := _stock_error(good, cost[good])
		if stock != "":
			return stock
	return _gold_error(gold_cost_of(type_id))


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


## Darf der Befehl „Handel“ jetzt die Menge je Handel dieser Ware kaufen (buying) bzw.
## verkaufen? Leer oder der Grund. Prüfreihenfolge: Markt vorhanden → Ware handelbar → beim
## Kauf Lager der Lagerart vorhanden, genug Gold, Platz für alles → beim Verkauf genug Bestand.
func trade_error(good: String, buying: bool) -> String:
	var market := market_error()
	if market != "":
		return market
	if not GameDefs.get_instance().goods.has(good):
		return "Diese Ware gibt es nicht"
	if not Market.is_tradable(good):
		return "%s ist nicht handelbar" % _good_name(good)
	var amount := Market.trade_amount()
	var storage_type := _storage_type_of(good)
	if not buying:
		return _stock_error(good, amount)
	if _storages(storage_type).is_empty():
		return Building.storage_missing_text(storage_type)
	var gold := _gold_error(amount * Market.buy_price(good))
	if gold != "":
		return gold
	if get_storage_capacity(storage_type) - get_storage_used(storage_type) < amount:
		return "Kein Platz im Lager"
	return ""


## Kann überhaupt gehandelt werden (steht ein Markt)? Leer oder der Grund.
func market_error() -> String:
	return "" if has_market() else "Kein Markt gebaut"


## Grund, wenn weniger als amount der Ware auf Lager ist (Bauen und Verkauf), sonst leer.
func _stock_error(good: String, amount: int) -> String:
	if get_stock(good) < amount:
		return "Zu wenig %s (%d nötig)" % [_good_name(good), amount]
	return ""


## Grund, wenn weniger als amount Gold im Schatz ist (Bauen und Kauf), sonst leer.
func _gold_error(amount: int) -> String:
	if _treasury < amount:
		return "Nicht genug Gold (%d nötig)" % amount
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


## Alle Bewohner nach ID aufsteigend – auch die gehenden, die nicht mehr mitzählen
## (get_population()).
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


## Die Arbeiter einer Arbeitsstätte nach ID aufsteigend (0: die Untätigen – ohne Ankommende
## und Gehende).
func get_workers(building_id: int) -> Array[Resident]:
	var result: Array[Resident] = []
	for resident: Resident in _residents.values():
		if resident.workplace_id == building_id and (building_id != 0 or resident.is_idle()):
			result.append(resident)
	return result


## Was ein Bewohner gerade tut, als Spieltext für die Kachel-Info,
## z. B. „Holzfäller – trägt 4 Holz“.
func activity_of(resident: Resident) -> String:
	if resident.is_arriving():
		return "kommt an – wartet: Weg versperrt" if resident.is_blocked() else "kommt an"
	if resident.is_leaving():
		return "verlässt die Burg"
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
			return Deposit.mining_text_of(workplace.deposit_type())
		Resident.Task.RETURNING, Resident.Task.TO_STORAGE:
			return "trägt %s" % carried
		Resident.Task.PROCESSING:
			return "verarbeitet %s" % carried
		Resident.Task.FARMING:
			return workplace.work_text()
		Resident.Task.WAITING_FOR_DEPOSIT:
			return "geht zur Arbeitsstätte" if resident.is_moving() else "wartet: Kein %s erreichbar" % deposit_name
		Resident.Task.WAITING_FOR_STORAGE:
			return "trägt %s" % carried if resident.is_moving() else "wartet: Lager voll"
	return "geht zur Arbeitsstätte" if resident.is_moving() else "an der Arbeitsstätte"


## Wie viele Bewohner die Burg hat: alle außer den gehenden, Ankommende ab ihrem Erscheinen.
func get_population() -> int:
	var count := 0
	for resident: Resident in _residents.values():
		if not resident.is_leaving():
			count += 1
	return count


## Wie viele Bewohner ohne Arbeitsstätte am Lagerfeuer sind (ohne Ankommende und Gehende).
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


## Beliebtheit, 0–100.
func get_popularity() -> int:
	return _popularity


## Takte seit der letzten Ankunft bzw. dem letzten Abgang (Zähler für Kommen und Gehen).
func get_migration_ticks() -> int:
	return _migration_ticks


## Die eingestellte Ration.
func get_ration() -> String:
	return _ration


## Der eingestellte Steuersatz.
func get_tax_rate() -> String:
	return _tax_rate


## Gold im Schatz.
func get_treasury() -> int:
	return _treasury


## Steht ein Markt (Gebäude mit Verhalten „market“)?
func has_market() -> bool:
	for building: Building in _buildings.values():
		if building.is_market():
			return true
	return false


## Die tatsächlich gegessene Ration des letzten Tags – bei Mangel kleiner als die
## eingestellte; vor dem ersten Tag die Vorschau aus Einstellung und Vorrat.
func get_eaten_ration() -> String:
	return _eaten_ration if _eaten_ration != "" else _plan_meal().ration


## Wurde am letzten Tag wegen Mangels weniger gegessen als eingestellt? Vor dem ersten Tag
## die Vorschau: Reicht der Vorrat nicht für die eingestellte Ration?
func is_short_of_food() -> bool:
	if _eaten_ration != "":
		return _short_of_food
	return _is_lower_ration(_plan_meal().ration, _ration)


## Die Faktoren der Beliebtheit (Ration, Vielfalt, Steuersatz) des letzten Tags; vor dem ersten Tag eine
## Vorschau aus Einstellung und Vorrat.
func get_factors() -> Array[Factor]:
	return _factors.duplicate() if not _factors.is_empty() else _factors_of(_plan_meal())


## Summe der Faktoren: um so viel ändert sich die Beliebtheit pro Tag (Tendenz).
func get_factor_sum() -> int:
	var total := 0
	for factor in get_factors():
		total += factor.value
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


func _set_ration(ration_id: String) -> String:
	if not Population.has_ration(ration_id):
		return "Unbekannte Ration „%s“" % ration_id
	_ration = ration_id
	settings_changed.emit()
	return ""


func _set_tax_rate(tax_rate_id: String) -> String:
	if not Population.has_tax_rate(tax_rate_id):
		return "Unbekannter Steuersatz „%s“" % tax_rate_id
	_tax_rate = tax_rate_id
	settings_changed.emit()
	return ""


## Tagesbeginn: Die Bewohner essen (_plan_meal()) aus den Kornspeichern in ID-Reihenfolge,
## bei Mangel mit Meldung; dann zahlen sie Steuern in den Schatz; danach ändert sich die
## Beliebtheit um die Summe der Faktoren, begrenzt auf 0–100.
func _start_day() -> void:
	var meal := _plan_meal()
	var changed: Dictionary[int, bool] = {}
	for good: String in meal.amounts:
		_take_goods(good, meal.amounts[good], changed)
	_emit_stock_changed(changed)
	_eaten_ration = meal.ration
	_short_of_food = _is_lower_ration(meal.ration, _ration)
	if _short_of_food:
		notice.emit("Nicht genug Nahrung – Ration: %s" % Population.ration_name(meal.ration))
	_change_treasury(_daily_taxes())
	_factors = _factors_of(meal)
	factors_changed.emit()
	var popularity := clampi(_popularity + get_factor_sum(), 0, 100)
	if popularity != _popularity:
		_popularity = popularity
		popularity_changed.emit()


## Was die Bewohner jetzt essen würden, ohne etwas zu ändern. Bedarf = aufgerundet Bewohner ×
## Verbrauch; reicht der Vorrat an Nahrung nicht, gilt die höchste Stufe unter der
## eingestellten, deren Bedarf gedeckt ist. Verteilt wird reihum über die vorhandenen Sorten in
## der Reihenfolge der Waren, eine Einheit nach der anderen.
func _plan_meal() -> Meal:
	var foods := _food_goods()
	var available: Dictionary[String, int] = {}
	var total := 0
	for good in foods:
		available[good] = get_stock(good)
		total += available[good]
	var rations := Population.ration_ids()
	var meal := Meal.new()
	meal.ration = rations[0]
	var need := 0
	for i in range(rations.find(_ration), -1, -1):
		var ration_need := ceili(get_population() * Population.consumption(rations[i]))
		if ration_need <= total:
			meal.ration = rations[i]
			need = ration_need
			break
	while need > 0:
		for good in foods:
			if need > 0 and available[good] > 0:
				available[good] -= 1
				meal.amounts[good] = meal.amounts.get(good, 0) + 1
				need -= 1
	return meal


## Steuern eines Tags: abgerundet Bewohner × Gold des Steuersatzes.
func _daily_taxes() -> int:
	return floori(get_population() * Population.tax_gold(_tax_rate) + ROUNDING_SLACK)


static func _is_lower_ration(ration_id: String, than: String) -> bool:
	var rations := Population.ration_ids()
	return rations.find(ration_id) < rations.find(than)


## Die Faktoren eines Tags: aus der Mahlzeit Ration (tatsächliche) und Vielfalt (Zahl der
## verzehrten Sorten), dazu der eingestellte Steuersatz.
func _factors_of(meal: Meal) -> Array[Factor]:
	return [
		Factor.create(Factor.RATION, Population.ration_factor(meal.ration)),
		Factor.create(Factor.VARIETY, Population.variety_factor(meal.amounts.size())),
		Factor.create(Factor.TAX_RATE, Population.tax_factor(_tax_rate)),
	]


## Die Waren mit "food" in den Daten, in deren Reihenfolge.
func _food_goods() -> Array[String]:
	var result: Array[String] = []
	var goods := GameDefs.get_instance().goods
	for good: String in goods:
		if bool(goods[good].get("food", false)):
			result.append(good)
	return result


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
	for _i in _start_residents:
		var found := _search_outward(campfire.origin, _is_free_tile)
		if found.is_empty():
			return
		_add_resident(found[0], Resident.Level.GROUND)


## Kann hier ein Bewohner neu hingestellt werden? Begehbar, aber nicht auf Eingänge oder das
## Lagerfeuer selbst; schon Besetzte zählen als belegt.
func _is_free_tile(tile: Vector2i) -> bool:
	return is_walkable(tile, Resident.Level.GROUND) and get_building_at(tile) == null \
			and get_residents_at(tile).is_empty()


## Die erste Kachel um center, für die accept (Kachel → bool) gilt, als [Kachel], sonst
## leer. Erst nahe Kacheln, bei Bedarf weiter hinaus (Radius verdoppeln, bis über die
## Kartengröße), je Radius in der Reihenfolge von _offsets_within().
func _search_outward(center: Vector2i, accept: Callable) -> Array[Vector2i]:
	var radius := 2
	while radius <= 2 * maxi(map.width, map.height):
		for offset in _offsets_within(radius):
			if accept.call(center + offset):
				return [center + offset]
		radius *= 2
	return []


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
		_report_change(resident, _update_resident.bind(resident))


## Kommen und Gehen (nach den Bewohnern, in jedem Takt): Erst gehen Überzählige sofort. Dann
## läuft der Zähler, solange jemand kommen (Beliebtheit über dem Gleichgewicht, Wohnraum frei)
## oder gehen kann (darunter, noch Bewohner da); nach Ablauf des Abstands
## (Population.migration_ticks()) kommt bzw. geht einer, und der Zähler beginnt von vorn.
func _migrate() -> void:
	_send_away_surplus()
	var balance := Population.balance_popularity()
	var arriving := _popularity > balance and get_population() < get_housing()
	var leaving := _popularity < balance and get_population() > 0
	if not arriving and not leaving:
		return
	_migration_ticks += 1
	if _migration_ticks < Population.migration_ticks(_popularity):
		return
	_migration_ticks = 0
	if arriving:
		_add_newcomer()
	else:
		_start_leaving(_next_to_leave())


## Übersteigt die Zahl der Bewohner den Wohnraum, gehen die Überzähligen sofort
## (Reihenfolge wie bei _next_to_leave()).
func _send_away_surplus() -> void:
	for _i in get_population() - get_housing():
		_start_leaving(_next_to_leave())


## Wer als Nächster geht: der Untätige mit der größten ID, sonst der Arbeiter der jüngsten
## besetzten Arbeitsstätte (größte ID; dort der mit der größten ID), sonst der Ankommende mit
## der größten ID. Es muss noch jemand da sein (get_population() > 0).
func _next_to_leave() -> Resident:
	var worker: Resident = null
	var newcomer: Resident = null
	var residents := get_residents()
	residents.reverse()
	for resident in residents:
		if resident.is_idle():
			return resident
		if resident.workplace_id != 0 and (worker == null or resident.workplace_id > worker.workplace_id):
			worker = resident
		elif resident.is_arriving() and newcomer == null:
			newcomer = resident
	return worker if worker != null else newcomer


## Ein Bewohner bricht auf: Seine Arbeitsstätte wird frei, Reservierung und getragene Ware
## verfallen, und er geht zum nächsten Rand (_send_to_edge()).
func _start_leaving(resident: Resident) -> void:
	_report_change(resident, func() -> void:
		resident.workplace_id = 0
		resident.clear_work()
		resident.task = Resident.Task.LEAVING
		_send_to_edge(resident))


## Schickt einen Gehenden zur nach Weglänge nächsten erreichbaren Randkachel; steht er schon
## dort oder ist keine erreichbar, ist er sofort fort.
func _send_to_edge(resident: Resident) -> void:
	var edge := _nearest_edge(resident.plan_start())
	if edge.is_empty() or not _route_to(resident, Resident.ground(edge[0])) or not resident.is_moving():
		_remove_resident(resident)


## Ein neuer Bewohner erscheint auf der Randkachel mit dem kürzesten Weg zum Lagerfeuer und geht
## als Ankommender dorthin; ist kein Rand erreichbar, erscheint er als Untätiger direkt am
## Lagerfeuer (Reihenfolge wie bei den Startbewohnern).
func _add_newcomer() -> void:
	var campfire := _campfire()
	var edge := _nearest_edge(Resident.ground(campfire.origin))
	if edge.is_empty():
		var found := _search_outward(campfire.origin, _is_free_tile)
		_add_resident(campfire.origin if found.is_empty() else found[0], Resident.Level.GROUND)
		return
	var newcomer := _add_resident(edge[0], Resident.Level.GROUND, Resident.Task.ARRIVING)
	_report_change(newcomer, _send_newcomer.bind(newcomer))


## Schickt einen Ankommenden zu einer freien Kachel am Lagerfeuer (_send_to_campfire()); steht
## er schon dort, ist er gleich Untätiger.
func _send_newcomer(newcomer: Resident) -> void:
	_send_to_campfire(newcomer)
	if not newcomer.is_moving() and newcomer.timer == 0:
		newcomer.task = Resident.Task.NONE


## Die begehbare Randkachel mit dem kürzesten Weg von start als [Kachel]; bei gleicher Länge
## die kleinere (zeilenweise). Leer, wenn kein Rand erreichbar ist.
func _nearest_edge(start: Vector3i) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_length := INF
	var distances := Pathfinder.distances(start, _is_walkable_position)
	for position: Vector3i in distances:
		var tile := Vector2i(position.x, position.y)
		if not map.is_edge(tile):
			continue
		var length := distances[position]
		var better := length < best_length and not Pathfinder.same_length(length, best_length)
		if not better and Pathfinder.same_length(length, best_length):
			better = _row_order(tile, best[0])
		if better:
			best = [tile]
			best_length = length
	return best


func _remove_resident(resident: Resident) -> void:
	_residents.erase(resident.id)
	resident_removed.emit(resident.id)


## Ein Takt für einen Bewohner (siehe _update_residents()).
func _update_resident(resident: Resident) -> void:
	if resident.is_targeting_deposit(resident.deposit_tile) \
			and not _has_deposit_for(resident.deposit_tile, get_building(resident.workplace_id)):
		# Das angesteuerte Vorkommen ist weg (erschöpft, ersetzt): gleich ein neues suchen.
		_seek_deposit(resident, get_building(resident.workplace_id))
	if resident.is_moving() and not _is_walkable_position(resident.path[0]):
		_reroute(resident)
		if not _residents.has(resident.id):
			# Ein Gehender ohne erreichbaren Rand ist fort.
			return
	if resident.is_moving():
		# Wer eine Wartezeit vor sich hat, wartet nach der Ankunft erst (_work()).
		if resident.advance() and not resident.is_waiting():
			_arrive(resident)
	else:
		_work(resident)


## Führt change aus und meldet resident_changed, wenn sich dabei von außen Sichtbares am
## Bewohner geändert hat (_visible_state()).
func _report_change(resident: Resident, change: Callable) -> void:
	var before := _visible_state(resident)
	change.call()
	if _visible_state(resident) != before and _residents.has(resident.id):
		resident_changed.emit(resident.id)


## Was sich an einem Bewohner von außen sehen lässt (für resident_changed).
func _visible_state(resident: Resident) -> Array:
	return [resident.workplace_id, resident.task, resident.carried_good, resident.carried_amount, resident.is_moving()]


## Ein Bewohner ist am Ende seines Weges angekommen: Ein Ankommender wird am Lagerfeuer
## Untätiger, ein Gehender verschwindet am Rand. Für einen Arbeiter der nächste Schritt im
## Arbeitsablauf: Am Hof arbeitet er in der Arbeitsstätte, beim Sammler sucht er ein Vorkommen.
func _arrive(resident: Resident) -> void:
	if resident.is_arriving():
		resident.task = Resident.Task.NONE
		return
	if resident.is_leaving():
		_remove_resident(resident)
		return
	var workplace := get_building(resident.workplace_id)
	if workplace == null or not workplace.is_workplace():
		return
	match resident.task:
		Resident.Task.TO_WORKPLACE:
			if workplace.is_farm():
				resident.task = Resident.Task.FARMING
				resident.timer = workplace.work_ticks()
			else:
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
		Resident.Task.FARMING:
			# Ein Vorkommen braucht der Hof nicht: Die Ware entsteht bei der Arbeit.
			resident.carried_good = workplace.product()
			resident.carried_amount = workplace.carry_load()
			_seek_storage(resident, workplace)
		_:
			_resume(resident)


## Nimmt den Arbeitsschritt wieder auf – nach der Wartezeit oder wenn der Weg versperrt und
## das Ziel nicht mehr erreichbar ist: Untätige und Ankommende gehen zum Lagerfeuer, Gehende
## zum nächsten Rand, Arbeiter suchen ihr Vorkommen bzw. Lager neu oder gehen (wieder) zur
## Arbeitsstätte. Ist auch das nicht erreichbar, greift die jeweilige Warteregel.
func _resume(resident: Resident) -> void:
	if resident.goal() == Resident.Goal.CAMPFIRE:
		_send_newcomer(resident)
		return
	if resident.goal() == Resident.Goal.EDGE:
		_send_to_edge(resident)
		return
	var workplace := get_building(resident.workplace_id)
	if workplace == null:
		_send_to_campfire(resident)
		return
	match resident.goal():
		Resident.Goal.DEPOSIT:
			_seek_deposit(resident, workplace)
		Resident.Goal.STORAGE:
			_seek_storage(resident, workplace)
		Resident.Goal.WORKPLACE:
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
## der Arbeitsstätte und versucht es nach der Wartezeit erneut. Erreicht er sie nicht, wartet
## er mit der Ware, wo er ist, und sucht danach erneut ein Lager.
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
		if resident.timer > 0:
			# Kein Weg (_go() hat die Wartezeit gesetzt): Er wartet sichtbar draußen und will
			# danach weiter ein Lager suchen – ohne Ziellager, denn er kommt dort nie an.
			resident.task = Resident.Task.TO_STORAGE
			resident.storage_id = 0
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
	# Die Bedingung schickt ihn schon los, sobald es einen Weg gibt.
	var routed := _search_outward(campfire.origin, func(tile: Vector2i) -> bool:
		return not taken.has(tile) and is_walkable(tile, ground) and get_building_at(tile) == null \
				and _route_to(resident, Resident.ground(tile)))
	if routed.is_empty():
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


func _add_resident(tile: Vector2i, level: Resident.Level, task := Resident.Task.NONE) -> Resident:
	var resident := Resident.create(_next_resident_id, tile, level)
	resident.task = task
	_next_resident_id += 1
	_residents[resident.id] = resident
	resident_added.emit(resident.id)
	return resident


func _build(type_id: String, origin: Vector2i) -> String:
	var error := build_error(type_id, origin)
	if error != "":
		return error
	var cost := goods_cost_of(type_id)
	var changed: Dictionary[int, bool] = {}
	for good: String in cost:
		_take_goods(good, cost[good], changed)
	_emit_stock_changed(changed)
	_change_treasury(-gold_cost_of(type_id))
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
		_report_change(resident, func() -> void:
			if not is_walkable(resident.tile, resident.level):
				resident.tile = _nearest_reachable(resident.tile, _anchor_of(resident), reach)
				resident.step_progress = 0
				if resident.is_moving():
					_reroute(resident)
				elif resident.task == Resident.Task.MINING:
					_seek_deposit(resident, get_building(resident.workplace_id))
			elif resident.is_moving() and _crosses(resident, building):
				_reroute(resident))


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
## außen (_search_outward()) bis zum Abstand reach. Abgeschlossene Taschen werden so
## übersprungen; ist anchor in der Nähe von keiner aus erreichbar, die nächste begehbare,
## gibt es gar keine, die Kachel selbst.
func _nearest_reachable(tile: Vector2i, anchor: Vector3i, reach: int) -> Vector2i:
	var nearest := _search_outward(tile, func(candidate: Vector2i) -> bool:
		return is_walkable(candidate, Resident.Level.GROUND))
	if nearest.is_empty():
		return tile
	# Meist erreicht schon die nächste begehbare Kachel den Anker (ein Weg). Sonst wird
	# einmal alles gemessen, was vom Anker aus erreichbar ist (selten, aber die ganze Burg).
	if not Pathfinder.find_path(Resident.ground(nearest[0]), anchor, _is_walkable_position).is_empty():
		return nearest[0]
	var reachable := Pathfinder.distances(anchor, _is_walkable_position)
	for offset in _offsets_within(reach):
		var candidate := tile + offset
		if is_walkable(candidate, Resident.Level.GROUND) and reachable.has(Resident.ground(candidate)):
			return candidate
	return nearest[0]


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
			_report_change(resident, _seek_storage.bind(resident, get_building(resident.workplace_id)))
	# Die Arbeiter werden wieder Untätige und gehen zum Lagerfeuer.
	for worker in get_workers(id):
		worker.workplace_id = 0
		worker.clear_work()
		_send_to_campfire(worker)
		resident_changed.emit(worker.id)
	# Mit einem Wohnhaus kann Wohnraum fehlen.
	_send_away_surplus()
	# Die Hälfte der Kosten je Ware (abgerundet) zurück; was nicht mehr passt, verfällt.
	var cost := goods_cost_of(building.type)
	var changed: Dictionary[int, bool] = {}
	for good: String in cost:
		@warning_ignore("integer_division")
		_store_goods(good, cost[good] / 2, changed)
	_emit_stock_changed(changed)
	@warning_ignore("integer_division")
	_change_treasury(gold_cost_of(building.type) / 2)
	return ""


func _trade(good: String, buying: bool) -> String:
	var reason := trade_error(good, buying)
	if reason != "":
		return reason
	var amount := Market.trade_amount()
	var changed: Dictionary[int, bool] = {}
	if buying:
		_store_goods(good, amount, changed)
		_emit_stock_changed(changed)
		_change_treasury(-amount * Market.buy_price(good))
	else:
		_take_goods(good, amount, changed)
		_emit_stock_changed(changed)
		_change_treasury(amount * Market.sell_price(good))
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
	# Begehbare Vorkommen (z. B. Wild) versperren den Eingang nicht.
	var front := Building.front_of_entrance(type_id, origin)
	var front_deposit := map.get_deposit(front)
	if not map.is_walkable(front) or (front_deposit != null and not front_deposit.is_walkable()) \
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
	if kind == "on_terrain":
		# Jede Kachel der Grundfläche muss eines der genannten Gelände haben.
		var allowed: Array = rule["terrain"]
		for tile in Building.footprint(type_id, origin):
			if not allowed.has(map.get_terrain(tile)):
				return false
		return true
	assert(false, "Unbekannte Bauregel „%s“ bei „%s“" % [kind, type_id])
	return false


func _building_name(type_id: String) -> String:
	return str(GameDefs.get_instance().buildings[type_id]["name"])


## Baukosten eines Gebäudetyps in Waren: Ware → Menge (ohne Gold).
static func goods_cost_of(type_id: String) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	var cost: Dictionary = GameDefs.get_instance().buildings[type_id]["cost"]
	for good: String in cost:
		if good != GOLD:
			result[good] = int(cost[good])
	return result


## Baukosten eines Gebäudetyps in Gold aus dem Schatz (0, wenn keins).
static func gold_cost_of(type_id: String) -> int:
	var cost: Dictionary = GameDefs.get_instance().buildings[type_id]["cost"]
	return int(cost.get(GOLD, 0))


## Ändert das Gold im Schatz um amount und meldet es (nichts bei 0).
func _change_treasury(amount: int) -> void:
	if amount == 0:
		return
	_treasury += amount
	treasury_changed.emit()


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


## Vorkommen mit "spread" in den Daten (z. B. Bäume, Wild) breiten sich in ihrem Rhythmus aus:
## Jede freie, bebaubare Kachel neben einem solchen Vorkommen bekommt mit der
## angegebenen Chance ein neues – mit "terrain" nur auf diesen Geländen. Grundflächen, Kacheln vor Eingängen und Kacheln, auf denen
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
			_spread_type(type, float(spread["chance"]), Deposit.spread_terrains_of(type))


## terrains leer: auf jedem bebaubaren Gelände.
@warning_ignore("integer_division")
func _spread_type(type: String, chance: float, terrains: Array[String]) -> void:
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
				and (terrains.is_empty() or terrains.has(map.get_terrain(tile))) \
				and _rng.randf() < chance and not standing.has(tile):
			map.add_deposit(tile, Deposit.create(type, _rng))
