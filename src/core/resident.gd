class_name Resident
extends Figure
## Ein Bewohner der Burg (Bewegung und Kampfwerte: Figure). Ein gerader Schritt dauert
## "ticks_per_tile" Takte (units.json, beim Soldaten die seines Soldatentyps).
## Ein Soldat ist weiter Bewohner, arbeitet aber nicht: Er geht zu seinem Posten und steht dort
## bzw. greift den befohlenen Feind an.
## Arbeiter eines Sammlers, Hofs oder Herstellungsbetriebs gehen dazu den Arbeitsablauf in
## Task durch; die Spielwelt treibt ihn an, hier steht nur der Zustand.

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

## ID der zugeteilten Arbeitsstätte, 0 = Untätiger.
var workplace_id := 0
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


## Takte für einen geraden Schritt ("ticks_per_tile" in units.json).
static func ticks_per_tile() -> int:
	return int(GameDefs.get_instance().units["resident"]["ticks_per_tile"])


## Wartezeit in Takten, bis Gescheitertes erneut versucht wird ("retry_ticks" in units.json).
static func retry_ticks() -> int:
	return int(GameDefs.get_instance().units["resident"]["retry_ticks"])


func straight_step_ticks() -> int:
	return FighterType.ticks_per_tile(soldier_type) if is_soldier() else ticks_per_tile()


func fighter_type() -> String:
	return soldier_type


func report_hit(combat: Combat) -> void:
	combat.soldier_hit(self)


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


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	var data := _figure_data()
	data.merge({
		"workplace": workplace_id, "task": task, "deposit": [deposit_tile.x, deposit_tile.y], "storage": storage_id,
		"good": carried_good, "amount": carried_amount, "timer": timer,
		"soldier_type": soldier_type, "post": [post.x, post.y, post.z],
	})
	return data


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Resident:
	var resident := Resident.new()
	resident._read_figure_data(data)
	resident.workplace_id = int(data["workplace"])
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
