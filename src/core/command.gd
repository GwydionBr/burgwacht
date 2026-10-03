class_name Command
extends RefCounted
## Ein Befehl: eine Absicht des Spielers, die GameWorld.execute() sofort ausführt (ADR 0001).

enum Kind { FOUND, BUILD, DEMOLISH, SET_RATION, SET_TAX_RATE, TRADE, RECRUIT, MOVE }

var kind: Kind
## Ursprungskachel (obere Ecke der Grundfläche) des Gebäudes.
var origin: Vector2i
## Gebäudetyp aus buildings.json; bei FOUND der Bergfried.
var building_type: String
## Bei DEMOLISH: ID des Gebäudes; bei RECRUIT: ID der Kaserne.
var building_id: int
## Bei SET_RATION: die Rationsstufe aus population.json.
var ration: String
## Bei SET_TAX_RATE: der Steuersatz aus population.json.
var tax_rate: String
## Bei TRADE: die Ware aus goods.json.
var good: String
## Bei TRADE: kaufen (true) oder verkaufen (false).
var buying: bool
## Bei RECRUIT: der Soldatentyp aus units.json.
var soldier_type: String
## Bei MOVE: die IDs der Soldaten (die Auswahl).
var resident_ids: Array[int] = []
## Bei MOVE: das Ziel (Kachel + Ebene).
var target: Vector3i


## Burg gründen: Bergfried mit Ursprung keep_origin, dazu das erste Warenlager.
static func found(keep_origin: Vector2i) -> Command:
	var command := Command.new()
	command.kind = Kind.FOUND
	command.origin = keep_origin
	command.building_type = GameWorld.FOUNDING_TYPE
	return command


## Gebäude vom Typ type_id mit Ursprung building_origin bauen.
static func build(type_id: String, building_origin: Vector2i) -> Command:
	var command := Command.new()
	command.kind = Kind.BUILD
	command.origin = building_origin
	command.building_type = type_id
	return command


## Gebäude mit dieser ID abreißen.
static func demolish(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.DEMOLISH
	command.building_id = id
	return command


## Ration für alle Bewohner einstellen (auch schon während der Gründung).
static func set_ration(ration_id: String) -> Command:
	var command := Command.new()
	command.kind = Kind.SET_RATION
	command.ration = ration_id
	return command


## Steuersatz für alle Bewohner einstellen (auch schon während der Gründung).
static func set_tax_rate(tax_rate_id: String) -> Command:
	var command := Command.new()
	command.kind = Kind.SET_TAX_RATE
	command.tax_rate = tax_rate_id
	return command


## Am Markt handeln: die Menge je Handel (market.json) einer Ware kaufen oder verkaufen.
static func trade(good_id: String, buy: bool) -> Command:
	var command := Command.new()
	command.kind = Kind.TRADE
	command.good = good_id
	command.buying = buy
	return command


## An einer Kaserne einen Untätigen als Soldaten dieses Typs anwerben.
static func recruit(barracks_id: int, type_id: String) -> Command:
	var command := Command.new()
	command.kind = Kind.RECRUIT
	command.building_id = barracks_id
	command.soldier_type = type_id
	return command


## Soldaten zu einem Ziel schicken: jeder bekommt dort eine eigene Kachel als neuen Posten.
static func move(soldier_ids: Array[int], target_position: Vector3i) -> Command:
	var command := Command.new()
	command.kind = Kind.MOVE
	command.resident_ids = soldier_ids.duplicate()
	command.target = target_position
	return command
