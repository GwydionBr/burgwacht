class_name ScenarioBot
extends RefCounted
## Szenario-Bot fürs Balancing: spielt eine Partie allein über Befehle nach einer festen
## Bauordnung (tools/bots/<szenario>.json) und merkt sich, was er getan hat. Ausgegeben von
## tools/bot.sh; tests/test_bots.gd prüft, dass jede Referenz-Bauordnung ihr Szenario gewinnt.
##
## Eine Bauordnung hat "steps" (der Reihe nach; ein Schritt hält die folgenden auf, bis er
## erledigt ist) und "rules" (bei jeder Prüfung erneut). Jeder Eintrag ist von genau einer Art:
## - {"build": Typ, "until": n}: Gebäude des Typs bauen, bis n stehen (Vorgabe 1)
## - {"ration": ID} / {"tax": ID}: Ration bzw. Steuersatz setzen
## - {"buy": Ware, "until": n}: am Markt kaufen, bis n vorrätig sind
## - {"sell": Ware, "keep": n}: am Markt verkaufen, solange danach noch n übrig bleiben
## - {"recruit": Soldatentyp, "until": n}: anwerben (in der ersten Kaserne), bis n davon da sind
## - {"post": Gebäudetyp}: Soldaten, deren Posten weiter als POST_RADIUS vom Eingang des ersten
##   Gebäudes dieses Typs liegt, dorthin schicken (als Regel auch alle neu angeworbenen)
## und optional Bedingungen, die alle gelten müssen: "day" (frühestens an diesem Tag),
## "population", "gold" (Schatz) und "stock" ({Ware: Menge}).

## Rückgabe von _try(): Der Eintrag wartet auf seine Bedingungen (ohne eigenen Grund).
const WAITING := "…"
## So viele Takte liegen zwischen zwei Prüfungen der Bauordnung.
const CHECK_TICKS := 10
## Bauordnungen liegen hier, je Szenario eine Datei <ID>.json.
const DIR := "res://tools/bots/"
## Ein Sammler wird nur gebaut, wo so viele Vorkommen seines Typs in Reichweite liegen.
const MIN_DEPOSITS_IN_RANGE := 6
## Soldaten mit Posten in diesem Abstand (Kacheln) gelten als dort postiert ("post").
const POST_RADIUS := 6.0

var steps: Array[Dictionary] = []
var rules: Array[Dictionary] = []
## Leer, wenn die Bauordnung gelesen werden konnte; sonst der Grund.
var error := ""
## Was der Bot getan hat, je Zeile „Tag n: …“.
var events: PackedStringArray = []

var _next_step := 0
## Der zuletzt protokollierte Grund, warum der aktuelle Schritt wartet.
var _waiting_for := ""


## Liest die Bauordnung eines Szenarios aus DIR (bzw. dir).
static func load_named(scenario_id: String, dir := DIR) -> ScenarioBot:
	var bot := ScenarioBot.new()
	var path := dir + scenario_id + ".json"
	if not FileAccess.file_exists(path):
		bot.error = "Keine Bauordnung: %s" % path
		return bot
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		bot.error = "Keine gültige Bauordnung: %s" % path
		return bot
	var order: Dictionary = data
	bot.steps.assign(order.get("steps", []))
	bot.rules.assign(order.get("rules", []))
	return bot


## Wie viele Schritte erledigt sind.
func done_steps() -> int:
	return _next_step


## Hat der Bot alle Schritte erledigt (die Regeln gelten weiter)?
func is_done() -> bool:
	return _next_step >= steps.size()


## Die Partie: gründet an der vorgesehenen Stelle (falls noch nötig) und lässt die Welt laufen,
## bis sie zu Ende ist oder max_days vorbei sind. on_day(world) wird nach der Gründung und zu
## jedem Tagesbeginn gerufen.
func play(world: GameWorld, max_days: int, on_day := Callable()) -> void:
	if world.is_founding() and _execute(world, Command.found(world.find_founding_site()), "Gründung") != "":
		_note(world, "Gründung gescheitert")
		return
	if on_day.is_valid():
		on_day.call(world)
	while not world.is_finished() and world.get_day() <= max_days:
		if world.get_tick() % CHECK_TICKS == 0:
			act(world)
		world.step()
		if on_day.is_valid() and world.get_tick() % GameWorld.TICKS_PER_DAY == 0:
			on_day.call(world)


## Eine Prüfung: die Schritte, so weit sie erledigt sind, dann jede Regel einmal.
func act(world: GameWorld) -> void:
	while not is_done():
		var reason := _try(world, steps[_next_step])
		if reason != "":
			if reason != WAITING and reason != _waiting_for:
				_note(world, "Schritt %d wartet: %s" % [_next_step + 1, reason])
				_waiting_for = reason
			break
		_next_step += 1
		_waiting_for = ""
	for rule in rules:
		_try(world, rule)


## Versucht einen Eintrag: leer, wenn er erledigt ist (Ziel erreicht oder nicht machbar), sonst
## warum er wartet – der Grund eines abgelehnten Befehls oder WAITING.
func _try(world: GameWorld, entry: Dictionary) -> String:
	if not _conditions_hold(world, entry):
		return WAITING if not _is_reached(world, entry) else ""
	if _is_reached(world, entry):
		return ""
	if entry.has("ration"):
		return _execute(world, Command.set_ration(str(entry["ration"])), "Ration %s" % entry["ration"])
	if entry.has("tax"):
		return _execute(world, Command.set_tax_rate(str(entry["tax"])), "Steuersatz %s" % entry["tax"])
	if entry.has("build"):
		var type_id := str(entry["build"])
		var cost := world.cost_error(type_id)
		if cost != "":
			return cost
		var site := site_near_keep(world, type_id)
		if site == GameWorld.NO_SITE:
			_note(world, "kein Bauplatz für %s – übersprungen" % type_id)
			return ""
		return _or_waiting(_execute(world, Command.build(type_id, site), "Bau %s" % type_id))
	if entry.has("buy"):
		return _or_waiting(_execute(world, Command.trade(str(entry["buy"]), true), ""))
	if entry.has("sell"):
		return _or_waiting(_execute(world, Command.trade(str(entry["sell"]), false), ""))
	if entry.has("recruit"):
		var barracks := _first_barracks(world)
		if barracks == null:
			return "Keine Kaserne"
		return _or_waiting(_execute(world, Command.recruit(barracks.id, str(entry["recruit"])), ""))
	if entry.has("post"):
		return _post(world, str(entry["post"]))
	_note(world, "unbekannter Eintrag %s – übersprungen" % str(entry))
	return ""


## Ist das Ziel des Eintrags schon erreicht (dann ist nichts mehr zu tun)?
func _is_reached(world: GameWorld, entry: Dictionary) -> bool:
	var until := int(entry.get("until", 1))
	if entry.has("ration"):
		return world.get_ration() == str(entry["ration"])
	if entry.has("tax"):
		return world.get_tax_rate() == str(entry["tax"])
	if entry.has("build"):
		return count_buildings(world, str(entry["build"])) >= until
	if entry.has("buy"):
		return world.get_stock(str(entry["buy"])) >= until
	if entry.has("sell"):
		return world.get_stock(str(entry["sell"])) < int(entry.get("keep", 0)) + Market.trade_amount()
	if entry.has("recruit"):
		return _count_soldiers(world, str(entry["recruit"])) >= until
	return false


## Nach einem gelungenen Befehl ist der Eintrag noch nicht erledigt: Er wartet weiter (WAITING).
static func _or_waiting(reason: String) -> String:
	return WAITING if reason == "" else reason


## Schickt Soldaten, die zu weit weg postiert sind, vor den Eingang des ersten Gebäudes vom Typ
## type_id; leer, wenn alle dort sind (oder es das Gebäude nicht gibt), sonst wie _try().
func _post(world: GameWorld, type_id: String) -> String:
	var target := GameWorld.NO_SITE
	for building in world.get_buildings():
		if building.type == type_id and building.has_entrance():
			target = building.entrance_front()
			break
	if target == GameWorld.NO_SITE:
		return ""
	var far: Array[int] = []
	for resident in world.get_residents():
		if resident.is_soldier() and Vector2(resident.post_tile() - target).length() > POST_RADIUS:
			far.append(resident.id)
	if far.is_empty():
		return ""
	return _or_waiting(_execute(world, Command.move(far, Figure.ground(target)), "%d Soldaten zu %s" % [far.size(), type_id]))


func _conditions_hold(world: GameWorld, entry: Dictionary) -> bool:
	if world.get_day() < int(entry.get("day", 0)) or world.get_population() < int(entry.get("population", 0)) \
			or world.get_treasury() < int(entry.get("gold", 0)):
		return false
	var stock: Dictionary = entry.get("stock", {})
	for good: String in stock:
		if world.get_stock(good) < int(stock[good]):
			return false
	return true


## Führt den Befehl aus; leer, wenn er gelang, sonst der Grund. Mit what wird das Gelingen
## protokolliert.
func _execute(world: GameWorld, command: Command, what: String) -> String:
	var reason := world.execute(command)
	if reason == "" and what != "":
		_note(world, what)
	return reason


func _note(world: GameWorld, text: String) -> void:
	events.append("Tag %d: %s" % [world.get_day(), text])


## Wie viele Gebäude dieses Typs stehen.
static func count_buildings(world: GameWorld, type_id: String) -> int:
	return world.get_buildings().filter(func(building: Building) -> bool: return building.type == type_id).size()


static func _count_soldiers(world: GameWorld, type_id: String) -> int:
	return world.get_residents().filter(func(resident: Resident) -> bool: return resident.soldier_type == type_id).size()


static func _first_barracks(world: GameWorld) -> Building:
	for building in world.get_buildings():
		if building.is_barracks():
			return building
	return null


## Freier Bauplatz für type_id, dessen Ursprung dem Bergfried am nächsten liegt und der rundum
## eine Kachel Abstand zu anderen Gebäuden lässt, damit kein Weg zugebaut wird; ein Sammler
## braucht dazu MIN_DEPOSITS_IN_RANGE Vorkommen seines Typs in Reichweite. Gesucht wird in Ringen
## um den Bergfried; GameWorld.NO_SITE, wenn es keinen gibt.
static func site_near_keep(world: GameWorld, type_id: String) -> Vector2i:
	var keep := Vector2i.ZERO
	for building in world.get_buildings():
		if building.type == GameWorld.FOUNDING_TYPE:
			keep = building.origin
	var deposits := _deposits_for(world, type_id)
	var best := GameWorld.NO_SITE
	var best_distance := INF
	for radius in maxi(world.map.width, world.map.height):
		if radius * radius > best_distance:
			break
		for site in _ring(keep, radius):
			var distance := float((site - keep).length_squared())
			if distance < best_distance and world.build_error(type_id, site) == "" \
					and _has_margin(world, type_id, site) \
					and _has_deposits_in_range(type_id, site, deposits):
				best = site
				best_distance = distance
	return best


## Liegt um die Grundfläche rundum eine Kachel ohne Gebäude?
static func _has_margin(world: GameWorld, type_id: String, site: Vector2i) -> bool:
	var last := Building.last_tile_of(type_id, site)
	for y in range(site.y - 1, last.y + 2):
		for x in range(site.x - 1, last.x + 2):
			if world.get_building_at(Vector2i(x, y)) != null:
				return false
	return true


## Die Kacheln mit genau diesem Abstand (Chebyshev) um center.
static func _ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if maxi(absi(x), absi(y)) == radius:
				tiles.append(center + Vector2i(x, y))
	return tiles


## Kacheln der Vorkommen, die ein Sammler dieses Typs abbaut; leer bei allen anderen Gebäuden.
static func _deposits_for(world: GameWorld, type_id: String) -> Array[Vector2i]:
	var deposit_type := Building.create(0, type_id, Vector2i.ZERO).deposit_type()
	var tiles: Array[Vector2i] = []
	if deposit_type != "":
		for tile: Vector2i in world.map.deposits:
			if world.map.deposits[tile].type == deposit_type:
				tiles.append(tile)
	return tiles


static func _has_deposits_in_range(type_id: String, site: Vector2i, deposits: Array[Vector2i]) -> bool:
	var building := Building.create(0, type_id, site)
	if building.deposit_type() == "":
		return true
	var entrance := Figure.ground(building.entrance())
	var found := 0
	for tile in deposits:
		if Pathfinder.free_length(entrance, Figure.ground(tile)) <= building.gather_range():
			found += 1
			if found >= MIN_DEPOSITS_IN_RANGE:
				return true
	return false
