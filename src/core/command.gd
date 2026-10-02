class_name Command
extends RefCounted
## Ein Befehl: eine Absicht des Spielers, die GameWorld.execute() sofort ausführt (ADR 0001).

enum Kind { FOUND, BUILD, DEMOLISH, SET_RATION }

var kind: Kind
## Ursprungskachel (obere Ecke der Grundfläche) des Gebäudes.
var origin: Vector2i
## Gebäudetyp aus buildings.json; bei FOUND der Bergfried.
var building_type: String
## Bei DEMOLISH: ID des Gebäudes.
var building_id: int
## Bei SET_RATION: die Rationsstufe aus population.json.
var ration: String


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
