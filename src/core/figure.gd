class_name Figure
extends RefCounted
## Eine Figur auf der Karte: Bewohner (Resident) oder Feind (Enemy). Position = Kachel + Ebene
## (ADR 0004); läuft Kachel für Kachel einen Weg ab: Ein gerader Schritt dauert
## straight_step_ticks() Takte, ein schräger √2-mal so lange (gerundet). Kämpfer (Soldaten und
## Feinde) haben dazu Lebenspunkte, ein Angriffsziel und eine Wartezeit bis zum nächsten Angriff.
## Verweise über IDs (ADR 0002); die Spielwelt treibt die Figuren an, hier steht nur der Zustand.

## Höhenstufe einer Position; bisher gibt es nur den Boden.
enum Level { GROUND = 0 }

var id: int
var tile: Vector2i
var level := Level.GROUND
## Die noch abzulaufenden Positionen (Kachel + Ebene), ohne die aktuelle; leer = steht.
var path: Array[Vector3i] = []
## Takte, die er schon auf dem Schritt zu path[0] unterwegs ist.
var step_progress := 0
## Lebenspunkte eines Kämpfers; 0 bei allen anderen.
var hp := 0
## ID des Gegners, den er angreift (beim Soldaten ein Feind, beim Feind ein Soldat); 0 = keiner.
var target_id := 0
## Takte bis zum nächsten möglichen Angriff.
var cooldown := 0


## Position (Kachel + Ebene) einer Kachel am Boden.
static func ground(ground_tile: Vector2i) -> Vector3i:
	return Vector3i(ground_tile.x, ground_tile.y, Level.GROUND)


## Takte für einen geraden Schritt.
func straight_step_ticks() -> int:
	assert(false, "straight_step_ticks() fehlt")
	return 1


## Kampfwerte (FighterType) aus units.json; leer, wenn er nicht kämpft.
func fighter_type() -> String:
	return ""


func is_fighter() -> bool:
	return fighter_type() != ""


## Hat ein Kämpfer Lebenspunkte verloren?
func is_wounded() -> bool:
	return is_fighter() and hp < FighterType.max_hp(fighter_type())


## Dauer eines seiner Schritte zwischen zwei benachbarten Positionen in Takten.
func step_ticks(from: Vector3i, to: Vector3i) -> int:
	return roundi(straight_step_ticks() * Pathfinder.step_cost(from, to))


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


## Der gemeinsame Teil von to_data() der Unterklassen.
func _figure_data() -> Dictionary:
	var path_data: Array[Array] = []
	for step in path:
		path_data.append([step.x, step.y, step.z])
	return {
		"id": id, "x": tile.x, "y": tile.y, "level": level, "path": path_data, "step_progress": step_progress,
		"hp": hp, "target": target_id, "cooldown": cooldown,
	}


## Gegenstück zu _figure_data().
func _read_figure_data(data: Dictionary) -> void:
	id = int(data["id"])
	tile = Vector2i(int(data["x"]), int(data["y"]))
	level = int(data["level"]) as Level
	for step: Array in data["path"]:
		path.append(Vector3i(int(step[0]), int(step[1]), int(step[2])))
	step_progress = int(data["step_progress"])
	hp = int(data["hp"])
	target_id = int(data["target"])
	cooldown = int(data["cooldown"])
