class_name Resident
extends RefCounted
## Ein Bewohner der Burg. Position = Kachel + Ebene (ADR 0004); Verweise über IDs (ADR 0002).

## Höhenstufe einer Position; bisher gibt es nur den Boden.
enum Level { GROUND = 0 }

var id: int
var tile: Vector2i
var level := Level.GROUND
## ID der zugeteilten Arbeitsstätte, 0 = Untätiger.
var workplace_id := 0


static func create(resident_id: int, start_tile: Vector2i, start_level: Level) -> Resident:
	var resident := Resident.new()
	resident.id = resident_id
	resident.tile = start_tile
	resident.level = start_level
	return resident


func is_idle() -> bool:
	return workplace_id == 0


## Was der Bewohner gerade tut, als Spieltext für die Kachel-Info.
func activity() -> String:
	return "Untätig" if is_idle() else "Arbeiter"


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"id": id, "x": tile.x, "y": tile.y, "level": level, "workplace": workplace_id}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Resident:
	var resident := create(int(data["id"]), Vector2i(int(data["x"]), int(data["y"])), int(data["level"]) as Level)
	resident.workplace_id = int(data["workplace"])
	return resident
