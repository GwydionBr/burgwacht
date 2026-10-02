class_name Command
extends RefCounted
## Ein Befehl: eine Absicht des Spielers, die GameWorld.execute() sofort ausführt (ADR 0001).

enum Kind { FOUND, BUILD }

var kind: Kind
## Ursprungskachel (obere Ecke der Grundfläche) des Gebäudes.
var tile: Vector2i
## Gebäudetyp aus buildings.json; bei FOUND der Bergfried.
var building_type: String


## Burg gründen: Bergfried mit Ursprung tile, dazu das erste Warenlager.
static func found(origin: Vector2i) -> Command:
	var command := Command.new()
	command.kind = Kind.FOUND
	command.tile = origin
	command.building_type = GameWorld.FOUNDING_TYPE
	return command


## Gebäude vom Typ type_id mit Ursprung origin bauen.
static func build(type_id: String, origin: Vector2i) -> Command:
	var command := Command.new()
	command.kind = Kind.BUILD
	command.tile = origin
	command.building_type = type_id
	return command
