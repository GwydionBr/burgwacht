class_name Resident
extends RefCounted
## Ein Bewohner der Burg. Position = Kachel + Ebene (ADR 0004); Verweise über IDs (ADR 0002).
## Läuft Kachel für Kachel einen Weg ab: Ein gerader Schritt dauert "ticks_per_tile" Takte
## (units.json, beim Soldaten die seines Soldatentyps), ein schräger √2-mal so lange (gerundet).
## Ein Soldat ist weiter Bewohner, arbeitet aber nicht: Er geht zu seinem Posten und steht dort.
## Arbeiter eines Sammlers, Hofs oder Herstellungsbetriebs gehen dazu den Arbeitsablauf in
## Task durch; die Spielwelt treibt ihn an, hier steht nur der Zustand.

## Höhenstufe einer Position; bisher gibt es nur den Boden.
enum Level { GROUND = 0 }
## Schritt im Arbeitsablauf eines Sammlers, Hofs bzw. Herstellungsbetriebs. Gewartet und gearbeitet wird erst, wenn er steht.
enum Task {
	## Untätig oder noch ohne Auftrag.
	NONE,
	## Geht ohne Ware zur Arbeitsstätte.
	TO_WORKPLACE,
	## Geht zu einer Kachel neben dem Vorkommen auf deposit_tile.
	TO_DEPOSIT,
	## Baut das Vorkommen auf deposit_tile ab (timer).
	MINING,
	## Bringt die abgebaute Ware bzw. die volle Eingangsware zur Arbeitsstätte.
	RETURNING,
	## Verarbeitet die Ware unsichtbar in der Arbeitsstätte (timer).
	PROCESSING,
	## Trägt die Ware zum Lager storage_id; versperrt (0) wartet er draußen auf einen neuen
	## Versuch.
	TO_STORAGE,
	## Kein Vorkommen erreichbar: wartet in der Arbeitsstätte (timer).
	WAITING_FOR_DEPOSIT,
	## Alle Lager voll: wartet mit der Ware an der Arbeitsstätte (timer).
	WAITING_FOR_STORAGE,
	## Hof: arbeitet unsichtbar in der Arbeitsstätte (timer), danach trägt er die Ware heraus.
	FARMING,
	## Herstellungsbetrieb: geht zum Lager storage_id, um Eingangsware zu holen; trägt dabei
	## schon Geholtes.
	FETCHING,
	## Herstellungsbetrieb: zu wenig Eingangsware in den Lagern; wartet in der Arbeitsstätte
	## (timer), auch mit schon geholter Ware.
	WAITING_FOR_INPUT,
	## Herstellungsbetrieb: stellt unsichtbar in der Arbeitsstätte das Erzeugnis her (timer);
	## die getragene Eingangsware ist danach verbraucht.
	PRODUCING,
	## Neuer Bewohner: geht vom Kartenrand zum Lagerfeuer und wird dort Untätiger.
	ARRIVING,
	## Verlässt die Burg: geht zum Kartenrand und verschwindet dort; zählt nicht mehr mit.
	LEAVING,
	## Soldat: geht zu seinem Posten bzw. steht dort.
	ON_DUTY,
}
## Wie ein Arbeitsschritt abläuft: unterwegs, Arbeit vor Ort oder Warten (beides mit timer).
enum Phase { NONE, WALK, WORK, WAIT }
## Worum es im Arbeitsschritt geht; danach richtet sich, was er beim Wiederaufnehmen neu
## sucht bzw. wohin er geht.
## INPUT: Eingangsware holen; STORAGE: Ware abliefern.
enum Goal { WORKPLACE, DEPOSIT, STORAGE, INPUT, CAMPFIRE, EDGE, POST }

## Die Bedeutung der Arbeitsschritte an einer Stelle; ein neuer Schritt braucht hier je
## einen Eintrag.
const TASK_PHASE: Dictionary[Task, Phase] = {
	Task.NONE: Phase.NONE,
	Task.TO_WORKPLACE: Phase.WALK,
	Task.TO_DEPOSIT: Phase.WALK,
	Task.MINING: Phase.WORK,
	Task.RETURNING: Phase.WALK,
	Task.PROCESSING: Phase.WORK,
	Task.TO_STORAGE: Phase.WALK,
	Task.WAITING_FOR_DEPOSIT: Phase.WAIT,
	Task.WAITING_FOR_STORAGE: Phase.WAIT,
	Task.FARMING: Phase.WORK,
	Task.FETCHING: Phase.WALK,
	Task.WAITING_FOR_INPUT: Phase.WAIT,
	Task.PRODUCING: Phase.WORK,
	Task.ARRIVING: Phase.WALK,
	Task.LEAVING: Phase.WALK,
	Task.ON_DUTY: Phase.WALK,
}
const TASK_GOAL: Dictionary[Task, Goal] = {
	Task.NONE: Goal.WORKPLACE,
	Task.TO_WORKPLACE: Goal.WORKPLACE,
	Task.TO_DEPOSIT: Goal.DEPOSIT,
	Task.MINING: Goal.DEPOSIT,
	Task.RETURNING: Goal.WORKPLACE,
	Task.PROCESSING: Goal.WORKPLACE,
	Task.TO_STORAGE: Goal.STORAGE,
	Task.WAITING_FOR_DEPOSIT: Goal.DEPOSIT,
	Task.WAITING_FOR_STORAGE: Goal.STORAGE,
	Task.FARMING: Goal.WORKPLACE,
	Task.FETCHING: Goal.INPUT,
	Task.WAITING_FOR_INPUT: Goal.INPUT,
	Task.PRODUCING: Goal.WORKPLACE,
	Task.ARRIVING: Goal.CAMPFIRE,
	Task.LEAVING: Goal.EDGE,
	Task.ON_DUTY: Goal.POST,
}
## Bei diesen Schritten ist er im Stehen unsichtbar in seiner Arbeitsstätte.
const TASKS_INSIDE: Array[Task] = [Task.PROCESSING, Task.WAITING_FOR_DEPOSIT, Task.FARMING, Task.WAITING_FOR_INPUT,
		Task.PRODUCING]

var id: int
var tile: Vector2i
var level := Level.GROUND
## ID der zugeteilten Arbeitsstätte, 0 = Untätiger.
var workplace_id := 0
## Die noch abzulaufenden Positionen (Kachel + Ebene), ohne die aktuelle; leer = steht.
var path: Array[Vector3i] = []
## Takte, die er schon auf dem Schritt zu path[0] unterwegs ist.
var step_progress := 0
var task := Task.NONE
## Bei TO_DEPOSIT und MINING: Kachel des Vorkommens. Exklusive Vorkommen (Bäume) gelten
## damit als reserviert.
var deposit_tile := Vector2i.ZERO
## Bei TO_STORAGE und FETCHING: ID des Lagers; bei TO_STORAGE 0, wenn er versperrt auf
## einen neuen Versuch wartet.
var storage_id := 0
## Getragene Ware und Menge; leer bzw. 0, wenn er nichts trägt.
var carried_good := ""
var carried_amount := 0
## Restliche Takte für Abbau, Verarbeitung oder Warten.
var timer := 0
## Soldatentyp aus units.json; leer, wenn er kein Soldat ist.
var soldier_type := ""
## Nur bei Soldaten: die Position, zu der er gehört (anfangs eine Kachel an der Kaserne).
var post := Vector3i.ZERO


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


## Dauer eines seiner Schritte zwischen zwei benachbarten Positionen in Takten.
func step_ticks(from: Vector3i, to: Vector3i) -> int:
	var straight := SoldierType.ticks_per_tile(soldier_type) if is_soldier() else ticks_per_tile()
	return roundi(straight * Pathfinder.step_cost(from, to))


## Ohne Arbeitsstätte am Lagerfeuer bzw. auf dem Weg dorthin – nicht, wer erst ankommt
## oder geht, und kein Soldat.
func is_idle() -> bool:
	return workplace_id == 0 and task == Task.NONE and not is_soldier()


## Wurde er als Soldat angeworben? Dann arbeitet er nicht und geht nie fort.
func is_soldier() -> bool:
	return soldier_type != ""


## Kommt er gerade neu in die Burg? Dann zählt er schon als Bewohner, ist aber noch kein
## Untätiger.
func is_arriving() -> bool:
	return task == Task.ARRIVING


## Geht er fort? Dann zählt er nicht mehr als Bewohner.
func is_leaving() -> bool:
	return task == Task.LEAVING


func is_moving() -> bool:
	return not path.is_empty()


## Wie sein Arbeitsschritt abläuft (TASK_PHASE).
func phase() -> Phase:
	return TASK_PHASE[task]


## Worum es in seinem Arbeitsschritt geht (TASK_GOAL).
func goal() -> Goal:
	return TASK_GOAL[task]


## Ist er in seiner Arbeitsstätte und damit nicht zu sehen (TASKS_INSIDE)?
func is_inside_building() -> bool:
	return not is_moving() and task in TASKS_INSIDE


## Hat er eine Wartezeit (timer) vor sich – in einem Warteschritt oder nach versperrtem Weg?
## Unterwegs heißt das: Nach der Ankunft wartet er erst, statt den nächsten Schritt zu beginnen.
func is_waiting() -> bool:
	return timer > 0 and phase() != Phase.WORK


## Steht er, obwohl er unterwegs sein will, weil sein Ziel nicht erreichbar war? Dann
## versucht er es nach der Wartezeit erneut.
func is_blocked() -> bool:
	return not is_moving() and is_waiting() and phase() == Phase.WALK


## Geht er zum Vorkommen auf dieser Kachel oder baut es ab? Bei exklusiven Vorkommen
## (Bäumen) ist es damit für andere reserviert.
func is_targeting_deposit(target: Vector2i) -> bool:
	return goal() == Goal.DEPOSIT and phase() != Phase.WAIT and deposit_tile == target


## Vergisst den Arbeitsablauf samt getragener Ware (z. B. beim Abriss der Arbeitsstätte).
func clear_work() -> void:
	task = Task.NONE
	deposit_tile = Vector2i.ZERO
	storage_id = 0
	carried_good = ""
	carried_amount = 0
	timer = 0


## Kachel seines Postens (nur bei Soldaten).
func post_tile() -> Vector2i:
	return Vector2i(post.x, post.y)


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
		"path": path_data, "step_progress": step_progress, "task": task,
		"deposit": [deposit_tile.x, deposit_tile.y], "storage": storage_id,
		"good": carried_good, "amount": carried_amount, "timer": timer,
		"soldier_type": soldier_type, "post": [post.x, post.y, post.z],
	}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Resident:
	var resident := create(int(data["id"]), Vector2i(int(data["x"]), int(data["y"])), int(data["level"]) as Level)
	resident.workplace_id = int(data["workplace"])
	for step: Array in data["path"]:
		resident.path.append(Vector3i(int(step[0]), int(step[1]), int(step[2])))
	resident.step_progress = int(data["step_progress"])
	resident.task = int(data["task"]) as Task
	var deposit: Array = data["deposit"]
	resident.deposit_tile = Vector2i(int(deposit[0]), int(deposit[1]))
	resident.storage_id = int(data["storage"])
	resident.carried_good = str(data["good"])
	resident.carried_amount = int(data["amount"])
	resident.timer = int(data["timer"])
	resident.soldier_type = str(data["soldier_type"])
	var post_data: Array = data["post"]
	resident.post = Vector3i(int(post_data[0]), int(post_data[1]), int(post_data[2]))
	return resident
