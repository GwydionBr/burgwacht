extends TestCase
## Simulationstests: Der Jäger erlegt Wild und trägt das Fleisch in den Kornspeicher;
## Wild ist begehbar und vermehrt sich langsam auf Wiese.
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), erstes Warenlager (ID 2) bei (7, 2),
## Lagerfeuer (ID 3) bei (3, 8), erster Kornspeicher (ID 4) bei (7, 6).

const KEEP_ORIGIN := Vector2i(2, 2)
const GRANARY := 4
## Jäger (2×2) mit Eingang bei (12, 3), daneben Wild.
const HUNTER_SITE := Vector2i(12, 2)
const GAME := Vector2i(14, 6)
## Jäger weiter weg, damit der Weg dorthin über Wild führen kann.
const SITE_FAR := Vector2i(15, 10)
const MAX_TICKS := 1000


func _founded() -> GameWorld:
	var world := empty_world()
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _steps(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


func _until(world: GameWorld, condition: Callable, what: String) -> bool:
	for i in MAX_TICKS:
		if condition.call():
			return true
		world.step()
	assert_true(false, "Nach %d Takten nicht erreicht: %s" % [MAX_TICKS, what])
	return false


func _game_tiles(world: GameWorld) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in world.map.deposits:
		if world.map.deposits[tile].type == "game":
			tiles.append(tile)
	tiles.sort()
	return tiles


func _spread_def(type_id: String) -> Dictionary:
	return GameDefs.get_instance().deposits[type_id]["spread"]


## Lässt die Welt mit vorübergehend geänderter Vermehrungschance des Wilds laufen.
func _run_with_chance(world: GameWorld, ticks: int, chance: float) -> void:
	var spread := _spread_def("game")
	var old_chance: float = spread["chance"]
	spread["chance"] = chance
	_steps(world, ticks)
	spread["chance"] = old_chance


func test_game_data() -> void:
	var game: Dictionary = GameDefs.get_instance().deposits["game"]
	assert_eq(game["name"], "Wild", "Name:")
	assert_eq(game["yields"], "meat", "Liefert:")
	assert_eq(int(game["amount"]), 6, "Menge:")
	assert_eq(game["walkable"], true, "Begehbar:")
	assert_eq(game["exclusive"], true, "Exklusiv:")
	var tree := _spread_def("tree")
	var spread := _spread_def("game")
	var tree_rate := float(tree["chance"]) / float(tree["interval_ticks"])
	var game_rate := float(spread["chance"]) / float(spread["interval_ticks"])
	assert_true(game_rate < tree_rate, "Wild vermehrt sich langsamer als Bäume")


func test_hunter_data() -> void:
	var hunter := Building.create(1, "hunter", Vector2i.ZERO)
	var def: Dictionary = GameDefs.get_instance().buildings["hunter"]
	assert_eq(def["behavior"], "gather", "Verhalten:")
	assert_eq(Building.size_of("hunter"), Vector2i(2, 2), "Größe:")
	assert_eq(int(def["workers"]), 1, "Arbeiter:")
	var actual: Array = [hunter.deposit_type(), hunter.mine_ticks(), hunter.process_ticks(),
			hunter.carry_load(), hunter.gather_range()]
	assert_eq(actual, ["game", 30, 20, 3, 15], "Sammlerwerte:")
	assert_eq(int(def["cost"]["wood"]), 5, "Kosten an Holz:")
	assert_true(GameWorld.buildable_types().has("hunter"), "Jäger hat eine Bautaste")


func test_residents_walk_over_game() -> void:
	var world := _founded()
	add_deposit(world, GAME, "game")
	assert_true(world.is_walkable(GAME, Resident.Level.GROUND), "Wild versperrt keinen Weg")


func test_worker_walks_through_game() -> void:
	var world := _founded()
	var id := build(world, "hunter", SITE_FAR)
	var worker := world.get_resident(1)
	# Felsen rund um den Jäger; nur vor dem Eingang steht Wild statt eines Felsens.
	var front := Building.front_of_entrance("hunter", SITE_FAR)
	for y in range(SITE_FAR.y - 1, SITE_FAR.y + 3):
		for x in range(SITE_FAR.x - 1, SITE_FAR.x + 3):
			var tile := Vector2i(x, y)
			if world.get_building_at(tile) == null:
				add_deposit(world, tile, "game" if tile == front else "stone")
	var entrance := world.get_building(id).entrance()
	var crossed := false
	for i in MAX_TICKS:
		if worker.tile == entrance:
			break
		world.step()
		crossed = crossed or worker.tile == front
	assert_eq(worker.tile, entrance, "Angekommen:")
	assert_true(crossed, "Über das Wild vor dem Eingang gelaufen")


func test_hunter_delivers_meat_to_granary() -> void:
	var world := _founded()
	add_deposit(world, GAME, "game")
	build(world, "hunter", HUNTER_SITE)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	var seen_hunting := ""
	for i in MAX_TICKS:
		if world.get_stock("meat") > 0:
			break
		world.step()
		if worker.task == Resident.Task.MINING:
			seen_hunting = world.activity_of(worker)
	assert_eq(world.get_stock("meat"), 3, "Fleisch nach dem ersten Gang (Traglast 3):")
	assert_eq(changed, [GRANARY] as Array[int], "Geliefert in den Kornspeicher:")
	assert_eq(world.map.get_deposit(GAME).amount, 3, "Rest im Wild:")
	assert_eq(seen_hunting, "Jäger – erlegt Wild", "Tätigkeit beim Abbau:")


func test_game_disappears_when_exhausted() -> void:
	var world := _founded()
	add_deposit(world, GAME, "game")
	build(world, "hunter", HUNTER_SITE)
	var removed: Array[Vector2i] = []
	world.deposit_removed.connect(func(tile: Vector2i) -> void: removed.append(tile))
	_until(world, func() -> bool: return world.get_stock("meat") == 6, "zwei Gänge")
	assert_eq(world.map.get_deposit(GAME), null, "Wild ist weg")
	assert_eq(removed, [GAME] as Array[Vector2i], "Gemeldet:")


func test_two_hunters_never_at_the_same_game() -> void:
	var world := _founded()
	add_deposit(world, GAME, "game")
	build(world, "hunter", HUNTER_SITE)
	build(world, "hunter", Vector2i(15, 2))
	var seen_waiting := false
	for i in 400:
		world.step()
		var targets: Dictionary[Vector2i, int] = {}
		for resident in world.get_residents():
			if resident.task == Resident.Task.TO_DEPOSIT or resident.task == Resident.Task.MINING:
				assert_true(not targets.has(resident.deposit_tile),
						"Bewohner %d und %d am selben Wild" % [targets.get(resident.deposit_tile, 0), resident.id])
				targets[resident.deposit_tile] = resident.id
			if resident.task == Resident.Task.WAITING_FOR_DEPOSIT:
				seen_waiting = true
	assert_true(seen_waiting, "Der zweite Jäger wartet, solange das einzige Wild reserviert ist")


func test_no_game_in_range_waits() -> void:
	var world := _founded()
	add_deposit(world, Vector2i(0, 15), "game")
	build(world, "hunter", Vector2i(16, 0))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_DEPOSIT and not worker.is_moving(),
			"Warten")
	assert_eq(world.activity_of(worker), "Jäger – wartet: Kein Wild erreichbar", "Tätigkeit:")


func test_game_spreads_only_onto_grass() -> void:
	var world := _founded()
	add_deposit(world, Vector2i(14, 10), "game")
	world.map.set_terrain(Vector2i(13, 10), "meadow")
	world.map.set_terrain(Vector2i(15, 10), "dirt")
	_run_with_chance(world, int(_spread_def("game")["interval_ticks"]), 1.0)
	var expected: Array[Vector2i] = [
		Vector2i(13, 9), Vector2i(13, 11),
		Vector2i(14, 9), Vector2i(14, 10), Vector2i(14, 11),
		Vector2i(15, 9), Vector2i(15, 11),
	]
	assert_eq(_game_tiles(world), expected, "Wild:")


func test_game_does_not_spread_under_residents() -> void:
	var world := _founded()
	var resident := world.get_resident(1)
	# Wild schräg neben dem Bewohner; bei sicherer Vermehrung bleibt nur seine Kachel frei.
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1)]:
		add_deposit(world, resident.tile + offset, "game")
	_run_with_chance(world, int(_spread_def("game")["interval_ticks"]), 1.0)
	assert_eq(world.map.get_deposit(resident.tile), null, "Kein Wild unter dem Bewohner")
	assert_true(world.map.get_deposit(resident.tile + Vector2i(-1, 0)) != null, "Daneben vermehrt es sich")
