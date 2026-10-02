class_name Resident
extends RefCounted
## Ein Bewohner der Burg. Position = Kachel + Ebene (ADR 0004); Verweise über IDs (ADR 0002).
## Läuft Kachel für Kachel einen Weg ab: Ein gerader Schritt dauert "ticks_per_tile" Takte
## (units.json), ein schräger √2-mal so lange (gerundet).

## Höhenstufe einer Position; bisher gibt es nur den Boden.
enum Level { GROUND = 0 }

var id: int
var tile: Vector2i
var level := Level.GROUND
## ID der zugeteilten Arbeitsstätte, 0 = Untätiger.
var workplace_id := 0
## Die noch abzulaufenden Positionen (Kachel + Ebene), ohne die aktuelle; leer = steht.
var path: Array[Vector3i] = []
## Takte, die er schon auf dem Schritt zu path[0] unterwegs ist.
var step_progress := 0


static func create(resident_id: int, start_tile: Vector2i, start_level: Level) -> Resident:
	var resident := Resident.new()
	resident.id = resident_id
	resident.tile = start_tile
	resident.level = start_level
	return resident


## Position (Kachel + Ebene) einer Kachel am Boden.
static func ground(ground_tile: Vector2i) -> Vector3i:
	return Vector3i(ground_tile.x, ground_tile.y, Level.GROUND)


## Takte für einen geraden Schritt ("ticks_per_tile" in units.json).
static func ticks_per_tile() -> int:
	return int(GameDefs.get_instance().units["resident"]["ticks_per_tile"])


## Wartezeit in Takten, bis Gescheitertes erneut versucht wird ("retry_ticks" in units.json).
static func retry_ticks() -> int:
	return int(GameDefs.get_instance().units["resident"]["retry_ticks"])


## Dauer eines Schritts zwischen zwei benachbarten Positionen in Takten.
static func step_ticks(from: Vector3i, to: Vector3i) -> int:
	return roundi(ticks_per_tile() * Pathfinder.step_cost(from, to))


func is_idle() -> bool:
	return workplace_id == 0


func is_moving() -> bool:
	return not path.is_empty()


## Aktuelle Position als Kachel + Ebene.
func position() -> Vector3i:
	return Vector3i(tile.x, tile.y, level)


## Die Position, von der aus ein neuer Weg beginnt: mitten im Schritt die Kachel, auf die
## er gerade tritt, sonst die aktuelle.
func plan_start() -> Vector3i:
	return path[0] if step_progress > 0 else position()


## Die Kachel, auf der er nach seinem Weg steht (steht er, die aktuelle).
func destination() -> Vector2i:
	if path.is_empty():
		return tile
	var last: Vector3i = path.back()
	return Vector2i(last.x, last.y)


## Bleibt stehen; mitten im Schritt geht er den noch zu Ende.
func stop() -> void:
	if step_progress > 0:
		path.resize(1)
	else:
		path.clear()


## Ein Takt Bewegung; true, wenn er dabei am Ende seines Weges angekommen ist.
func advance() -> bool:
	if path.is_empty():
		return false
	step_progress += 1
	if step_progress < step_ticks(position(), path[0]):
		return false
	var next: Vector3i = path.pop_front()
	tile = Vector2i(next.x, next.y)
	level = next.z as Level
	step_progress = 0
	return path.is_empty()


## Position in Kachelkoordinaten zwischen zwei Takten, für die Darstellung: fraction ist
## der Bruchteil bis zum nächsten Takt (0 bis 1).
func tile_point(fraction: float) -> Vector2:
	if path.is_empty():
		return Vector2(tile)
	var next := Vector2(path[0].x, path[0].y)
	var weight := clampf((step_progress + fraction) / step_ticks(position(), path[0]), 0.0, 1.0)
	return Vector2(tile).lerp(next, weight)


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	var path_data: Array[Array] = []
	for step in path:
		path_data.append([step.x, step.y, step.z])
	return {
		"id": id, "x": tile.x, "y": tile.y, "level": level, "workplace": workplace_id,
		"path": path_data, "step_progress": step_progress,
	}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Resident:
	var resident := create(int(data["id"]), Vector2i(int(data["x"]), int(data["y"])), int(data["level"]) as Level)
	resident.workplace_id = int(data["workplace"])
	for step: Array in data["path"]:
		resident.path.append(Vector3i(int(step[0]), int(step[1]), int(step[2])))
	resident.step_progress = int(data["step_progress"])
	return resident
