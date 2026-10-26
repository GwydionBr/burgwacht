class_name Economy
extends RefCounted
## Wirtschaftsrechner fürs Balancing: schätzt allein aus den Spieldaten, ohne Simulation, was
## eine Arbeitsstätte an einem Tag leistet (Erzeugnis, verbrauchte Eingangsware, Wertschöpfung),
## wie viele Bewohner eine Nahrungsstätte satt macht und wie viele Zulieferer ein
## Herstellungsbetrieb braucht. Laufwege schätzt er mit angenommenen Weglängen; ausgegeben wird
## das mit tools/economy.sh.

## Vorgabe: Weglänge in Kacheln von der Arbeitsstätte zum nächsten Lager.
const DEFAULT_STORAGE_DISTANCE := 10.0
## Vorgabe: Weglänge in Kacheln von einem Sammler zu seinem Vorkommen.
const DEFAULT_DEPOSIT_DISTANCE := 5.0
## So tief folgt chain() den Zulieferern höchstens (Schutz vor Kreisen in den Daten).
const MAX_CHAIN_DEPTH := 8


## Was eine Arbeitsstätte mit allen Arbeitern an einem Tag leistet.
class Rate:
	var type: String
	## Takte je Arbeitsgang in der Arbeitsstätte bzw. am Vorkommen.
	var work_ticks: int
	## Takte je Arbeitsgang auf dem Weg (geschätzt).
	var walk_ticks: float
	var product: String
	var product_per_day: float
	## Eingangsware; leer bei Sammler und Hof.
	var input: String
	var input_per_day: float

	func cycle_ticks() -> float:
		return work_ticks + walk_ticks


## Ein Glied einer Kette: so viele Gebäude dieses Typs je Endglied.
class Link:
	var type: String
	var count: float
	## Stufe ab dem Endglied (0) bis zum Rohstoff.
	var depth: int


var storage_distance: float
var deposit_distance: float


func _init(storage := DEFAULT_STORAGE_DISTANCE, deposit := DEFAULT_DEPOSIT_DISTANCE) -> void:
	storage_distance = storage
	deposit_distance = deposit


## Die Arbeitsstätten, die eine Ware liefern (Sammler, Hof, Herstellungsbetrieb), in der
## Reihenfolge der Daten.
static func workplace_types() -> Array[String]:
	var result: Array[String] = []
	for type_id: String in GameDefs.get_instance().buildings:
		var building := _example(type_id)
		if building.is_workplace() and (building.is_farm() or building.is_producer() or building.deposit_type() != ""):
			result.append(type_id)
	return result


## Die Gebäude mit Wohnraum in der Reihenfolge der Daten.
static func housing_types() -> Array[String]:
	var result: Array[String] = []
	for type_id: String in GameDefs.get_instance().buildings:
		if _example(type_id).housing() > 0:
			result.append(type_id)
	return result


## Leistung einer Arbeitsstätte. Ein Arbeitsgang:
## - Sammler: zum Vorkommen, Abbau, zurück, Verarbeitung, zum Lager und zurück
## - Hof: Arbeit, zum Lager und zurück
## - Herstellungsbetrieb: Eingangsware im Lager holen, Arbeit, Erzeugnis zum Lager bringen
func rate(type_id: String) -> Rate:
	var building := _example(type_id)
	var rate := Rate.new()
	rate.type = type_id
	var storage_trips := 1
	if building.is_farm():
		rate.work_ticks = building.work_ticks()
		rate.product = building.product()
	elif building.is_producer():
		rate.work_ticks = building.work_ticks()
		rate.product = building.product()
		rate.input = building.input_good()
		storage_trips = 2
	else:
		rate.work_ticks = building.mine_ticks() + building.process_ticks()
		rate.product = Deposit.good_of(building.deposit_type())
		rate.walk_ticks = 2 * deposit_distance * Resident.ticks_per_tile()
	rate.walk_ticks += storage_trips * 2 * storage_distance * Resident.ticks_per_tile()
	var cycles_per_day := GameWorld.TICKS_PER_DAY / rate.cycle_ticks() * building.worker_slots()
	rate.product_per_day = cycles_per_day * building.carry_load()
	if rate.input != "":
		rate.input_per_day = cycles_per_day * building.input_amount()
	return rate


## Baukosten in Gold: Gold selbst, andere Waren zum Kaufpreis am Markt.
static func cost_in_gold(type_id: String) -> int:
	var cost: Dictionary = GameDefs.get_instance().buildings[type_id].get("cost", {})
	var gold := 0
	for good: String in cost:
		gold += int(cost[good]) * (1 if good == GameWorld.GOLD else Market.buy_price(good))
	return gold


## Wertschöpfung pro Tag zum Verkaufspreis: Erzeugnis minus verbrauchte Eingangsware.
func value_per_day(type_id: String) -> float:
	var rate := rate(type_id)
	var value := rate.product_per_day * Market.sell_price(rate.product)
	if rate.input != "":
		value -= rate.input_per_day * Market.sell_price(rate.input)
	return value


## Nach wie vielen Tagen die Wertschöpfung die Baukosten (cost_in_gold()) einbringt; INF, wenn nie.
func payback_days(type_id: String) -> float:
	var value := value_per_day(type_id)
	return cost_in_gold(type_id) / value if value > 0 else INF


## Wie viele Bewohner die Arbeitsstätte bei dieser Ration satt macht; INF bei einer Ration ohne
## Verbrauch, 0, wenn sie keine Nahrung liefert.
func fed_residents(type_id: String, ration_id: String) -> float:
	var rate := rate(type_id)
	if not Population.is_food(rate.product):
		return 0.0
	var consumption := Population.consumption(ration_id)
	return rate.product_per_day / consumption if consumption > 0 else INF


## Die Arbeitsstätten, die diese Ware liefern.
func suppliers_of(good: String) -> Array[String]:
	var result: Array[String] = []
	for type_id in workplace_types():
		if rate(type_id).product == good:
			result.append(type_id)
	return result


## Wie viele Gebäude des Zulieferers eine Arbeitsstätte für ihre Eingangsware braucht.
func suppliers_needed(type_id: String, supplier_id: String) -> float:
	return rate(type_id).input_per_day / rate(supplier_id).product_per_day


## Die ganze Kette einer Arbeitsstätte bis zum Rohstoff: zuerst sie selbst (1), dann je Zulieferer
## seiner Eingangsware, wie viele es je Stück von ihr braucht, und so weiter. Liefern mehrere
## Arbeitsstätten dieselbe Ware, steht jede für sich da, als deckte sie den Bedarf allein.
func chain(type_id: String) -> Array[Link]:
	var links: Array[Link] = []
	_add_chain(type_id, 1.0, 0, links)
	return links


func _add_chain(type_id: String, count: float, depth: int, links: Array[Link]) -> void:
	var link := Link.new()
	link.type = type_id
	link.count = count
	link.depth = depth
	links.append(link)
	var input := rate(type_id).input
	if input == "" or depth >= MAX_CHAIN_DEPTH:
		return
	for supplier in suppliers_of(input):
		_add_chain(supplier, count * suppliers_needed(type_id, supplier), depth + 1, links)


## Ein Gebäude des Typs, um seine Werte aus den Daten zu lesen.
static func _example(type_id: String) -> Building:
	return Building.create(0, type_id, Vector2i.ZERO)
