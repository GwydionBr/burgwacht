class_name Command
extends RefCounted
## Ein Befehl: eine Absicht des Spielers, die GameWorld.execute() sofort ausführt (ADR 0001).

enum Kind { FOUND, BUILD }

var kind: Kind
## Ursprungskachel (obere Ecke der Grundfläche) des Gebäudes.
var origin: Vector2i
## Gebäudetyp aus buildings.json; bei FOUND der Bergfried.
var building_type: String


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
