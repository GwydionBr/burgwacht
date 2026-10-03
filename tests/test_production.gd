extends TestCase
## Simulationstests: Herstellungsbetriebe (Verhalten „produce“) – Mühle und Bäcker. Ihr
## Arbeiter holt die Eingangsware aus dem nächsten Lager mit Vorrat, stellt im Betrieb das
## Erzeugnis her und trägt es ins nächste Lager seiner Lagerart. Leere Karte (nur Wiese),
## Szenario mit 100 Gold; Bergfried (ID 1) bei (2, 2), Warenlager (ID 2) bei (7, 2),
## Lagerfeuer (ID 3) bei (3, 8), Kornspeicher (ID 4) bei (7, 6).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const GRANARY := 4
## Zweites Warenlager rechts neben dem ersten; vom Betrieb aus näher.
const SECOND_WAREHOUSE_SITE := Vector2i(10, 2)
## Mühle (3×3) rechts davon, eine zweite darunter.
const MILL_SITE := Vector2i(14, 2)
const OTHER_MILL_SITE := Vector2i(14, 7)
## Bäcker (2×2) rechts vom Kornspeicher.
const BAKERY_SITE := Vector2i(12, 7)
## Obergrenze für einen ganzen Arbeitsgang.
const MAX_TICKS := 1500


func _founded() -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _steps(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte); false, wenn nie.
func _until(world: GameWorld, condition: Callable, what: String) -> bool:
	for i in MAX_TICKS:
		if condition.call():
			return true
		world.step()
	assert_true(false, "Nach %d Takten nicht erreicht: %s" % [MAX_TICKS, what])
	return false


## Steht der Bewohner in diesem Arbeitsschritt (nicht mehr unterwegs)?
func _standing_in(resident: Resident, task: Resident.Task) -> bool:
	return resident.task == task and not resident.is_moving()


func test_flour_and_bread_are_goods() -> void:
	var goods: Dictionary = GameDefs.get_instance().goods
	assert_eq(goods.keys(), ["wood", "stone", "iron", "wheat", "flour", "apples", "meat", "bread"], "Reihenfolge:")
	assert_eq([goods["flour"]["name"], goods["flour"]["storage"]], ["Mehl", "warehouse"], "Mehl:")
	assert_true(not goods["flour"].get("food", false), "Mehl ist keine Nahrung")
	assert_eq([goods["bread"]["name"], goods["bread"]["storage"], goods["bread"]["food"]], ["Brot", "granary", true],
			"Brot:")
	for good: String in ["flour", "bread"]:
		assert_true(goods[good].has("color"), "Farbe für getragenes %s" % good)
	assert_eq([Market.buy_price("flour"), Market.sell_price("flour")], [16, 8], "Preise Mehl:")
	assert_eq([Market.buy_price("bread"), Market.sell_price("bread")], [8, 4], "Preise Brot:")


func test_mill_and_bakery_data() -> void:
	var expected := {
		"mill": ["Mühle", "Müller", "U", Vector2i(3, 3), "wheat", 3, "flour", 3, 120, "mahlt Weizen", 20, 20],
		"bakery": ["Bäcker", "Bäcker", "K", Vector2i(2, 2), "flour", 2, "bread", 4, 150, "backt Brot", 10, 10],
	}
	for type_id: String in expected:
		var def: Dictionary = GameDefs.get_instance().buildings[type_id]
		var building := Building.create(1, type_id, Vector2i.ZERO)
		var actual: Array = [def["name"], building.worker_name(), def["hotkey"], Building.size_of(type_id),
				building.input_good(), building.input_amount(), building.product(), building.carry_load(),
				building.work_ticks(), building.work_text(), GameWorld.goods_cost_of(type_id)["wood"],
				GameWorld.gold_cost_of(type_id)]
		assert_eq(actual, expected[type_id], "%s:" % type_id)
		assert_eq(def["behavior"], "produce", "Verhalten %s:" % type_id)
		assert_true(building.is_producer(), "%s ist ein Herstellungsbetrieb" % type_id)
		assert_eq(building.worker_slots(), 1, "Arbeiter %s:" % type_id)
		assert_true(GameWorld.is_buildable(type_id), "%s hat eine Bautaste" % type_id)


func test_waits_inside_without_enough_wheat_then_fetches() -> void:
	var world := _founded()
	var mill := world.get_building(build(world, "mill", MILL_SITE))
	put_goods(world, WAREHOUSE, "wheat", 2)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return _standing_in(worker, Resident.Task.WAITING_FOR_INPUT), "Warten auf Weizen")
	assert_eq(worker.tile, mill.entrance(), "Wartet in der Mühle:")
	assert_true(worker.is_inside_building(), "Unsichtbar in der Mühle")
	assert_eq(world.activity_of(worker), "Müller – wartet: kein Weizen", "Tätigkeit:")
	assert_eq(world.get_stock("wheat"), 2, "Nichts geholt:")
	# Erst nach der Wartezeit wird erneut geprüft.
	put_goods(world, WAREHOUSE, "wheat", 3)
	world.step()
	assert_eq(worker.task, Resident.Task.WAITING_FOR_INPUT, "Wartet weiter bis zur nächsten Prüfung:")
	_steps(world, Resident.retry_ticks())
	assert_eq(worker.task, Resident.Task.FETCHING, "Holt nach der Wartezeit:")
	assert_eq(worker.storage_id, WAREHOUSE, "Ziel:")
	assert_eq(world.activity_of(worker), "Müller – holt Weizen", "Tätigkeit beim Holen:")


func test_mill_turns_three_wheat_into_three_flour() -> void:
	var world := _founded()
	var mill := world.get_building(build(world, "mill", MILL_SITE))
	put_goods(world, WAREHOUSE, "wheat", 5)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.RETURNING, "Rückweg mit Weizen")
	assert_eq([worker.carried_good, worker.carried_amount], ["wheat", 3], "Trägt die Eingangsmenge:")
	assert_eq(world.get_stock("wheat"), 2, "Aus dem Lager genommen:")
	assert_eq(changed, [WAREHOUSE] as Array[int], "Entnahme gemeldet:")
	assert_eq(world.activity_of(worker), "Müller – trägt 3 Weizen", "Tätigkeit auf dem Rückweg:")
	_until(world, func() -> bool: return worker.is_inside_building(), "Mahlen")
	assert_eq(worker.task, Resident.Task.PRODUCING, "Stellt her:")
	assert_eq(worker.tile, mill.entrance(), "In der Mühle:")
	assert_eq(world.activity_of(worker), "Müller – mahlt Weizen", "Tätigkeit beim Mahlen:")
	var ticks_inside := 0
	while worker.is_inside_building():
		world.step()
		ticks_inside += 1
	assert_eq(ticks_inside, 120, "Arbeitsdauer:")
	assert_eq([worker.task, worker.carried_good, worker.carried_amount], [Resident.Task.TO_STORAGE, "flour", 3],
			"Kommt mit dem Mehl heraus:")
	assert_eq(worker.storage_id, WAREHOUSE, "Ins Warenlager:")
	_until(world, func() -> bool: return world.get_stock("flour") == 3, "Lieferung des Mehls")
	assert_eq(world.get_stock("wheat"), 2, "Genau die Eingangsmenge verbraucht:")
	assert_eq(worker.carried_amount, 0, "Trägt danach nichts mehr:")
	# Für den nächsten Arbeitsgang reichen 2 Weizen nicht: Er wartet.
	_until(world, func() -> bool: return _standing_in(worker, Resident.Task.WAITING_FOR_INPUT), "Warten auf Weizen")
	assert_eq(world.get_stock("wheat"), 2, "Rest bleibt im Lager:")


func test_fetches_from_nearest_storage_and_collects_from_several() -> void:
	var world := _founded()
	var second := build(world, "warehouse", SECOND_WAREHOUSE_SITE)
	build(world, "mill", MILL_SITE)
	put_goods(world, WAREHOUSE, "wheat", 5)
	put_goods(world, second, "wheat", 1)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.FETCHING, "Holen")
	assert_eq(worker.storage_id, second, "Erst zum nächsten Lager:")
	_until(world, func() -> bool: return worker.storage_id == WAREHOUSE, "Weiter zum zweiten Lager")
	assert_eq(worker.task, Resident.Task.FETCHING, "Holt weiter:")
	assert_eq([worker.carried_good, worker.carried_amount], ["wheat", 1], "Trägt den Rest des ersten Lagers:")
	assert_eq(world.get_building(second).contents.get("wheat", 0), 0, "Erstes Lager leer:")
	_until(world, func() -> bool: return worker.task == Resident.Task.RETURNING, "Rückweg")
	assert_eq(worker.carried_amount, 3, "Volle Eingangsmenge:")
	assert_eq(world.get_building(WAREHOUSE).contents.get("wheat", 0), 3, "Nur das Fehlende genommen:")


func test_two_mills_racing_for_the_last_wheat_neither_lose_nor_stall() -> void:
	var world := _founded()
	build(world, "mill", MILL_SITE)
	build(world, "mill", OTHER_MILL_SITE)
	# Reicht für beide zum Aufbruch, aber nur für einen Arbeitsgang.
	put_goods(world, WAREHOUSE, "wheat", 4)
	var first := world.get_resident(1)
	var second := world.get_resident(2)
	_until(world, func() -> bool: return first.task == Resident.Task.FETCHING and second.task == Resident.Task.FETCHING,
			"Beide holen")
	_until(world, func() -> bool:
		return first.carried_amount + second.carried_amount == 4 and world.get_stock("wheat") == 0,
		"Alles Weizen aufgeteilt")
	var late := first if first.carried_amount == 1 else second
	assert_eq(late.carried_amount, 1, "Der Spätere nimmt den Rest:")
	_until(world, func() -> bool: return _standing_in(late, Resident.Task.WAITING_FOR_INPUT), "Warten mit dem Rest")
	assert_eq([late.carried_good, late.carried_amount], ["wheat", 1], "Behält den Rest:")
	assert_eq(world.activity_of(late), "Müller – wartet: kein Weizen", "Tätigkeit:")
	# Neuer Vorrat für den Rest: Er holt weiter und mahlt.
	put_goods(world, WAREHOUSE, "wheat", 2)
	_until(world, func() -> bool: return world.get_stock("flour") == 6, "Beide Arbeitsgänge geliefert")
	assert_eq(world.get_stock("wheat"), 0, "Ohne Verlust verbraucht:")


func test_bakery_delivers_bread_to_granary() -> void:
	var world := _founded()
	build(world, "bakery", BAKERY_SITE)
	put_goods(world, WAREHOUSE, "flour", 2)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.is_inside_building() and worker.task == Resident.Task.PRODUCING,
			"Backen")
	assert_eq(world.activity_of(worker), "Bäcker – backt Brot", "Tätigkeit:")
	_until(world, func() -> bool: return world.get_stock("bread") == 4, "Brot im Kornspeicher")
	assert_eq(world.get_building(GRANARY).contents, {"bread": 4} as Dictionary[String, int], "Kornspeicher:")
	assert_eq(world.get_stock("flour"), 0, "Mehl verbraucht:")


func test_bread_is_eaten_and_counts_for_variety() -> void:
	var world := _founded()
	put_goods(world, GRANARY, "apples", 20)
	put_goods(world, GRANARY, "bread", 20)
	_steps(world, GameWorld.TICKS_PER_DAY)
	assert_true(world.get_stock("bread") < 20, "Brot wird gegessen")
	var variety := 0
	for factor in world.get_factors():
		if factor.id == Factor.VARIETY:
			variety = factor.value
	assert_eq(variety, Population.variety_factor(2), "Zwei Sorten:")


func test_full_warehouses_wait_with_flour() -> void:
	var world := _founded()
	var mill := world.get_building(build(world, "mill", MILL_SITE))
	put_goods(world, WAREHOUSE, "wheat", 3)
	# Nach der Entnahme des Weizens ist das Warenlager voll (80 Holz + 120 Stein).
	put_goods(world, WAREHOUSE, "stone", 120)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return _standing_in(worker, Resident.Task.WAITING_FOR_STORAGE), "Warten mit Mehl")
	assert_eq(worker.tile, mill.entrance(), "An der Mühle:")
	assert_eq([worker.carried_good, worker.carried_amount], ["flour", 3], "Behält das Mehl:")
	assert_eq(world.activity_of(worker), "Müller – wartet: Lager voll", "Tätigkeit:")
	put_goods(world, WAREHOUSE, "stone", 100)
	_until(world, func() -> bool: return world.get_stock("flour") == 3, "Lieferung nach dem Warten")


func test_demolished_mill_drops_carried_goods() -> void:
	for task: Resident.Task in [Resident.Task.FETCHING, Resident.Task.RETURNING, Resident.Task.PRODUCING,
			Resident.Task.TO_STORAGE]:
		var world := _founded()
		var id := build(world, "mill", MILL_SITE)
		put_goods(world, WAREHOUSE, "wheat", 3)
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == task, "Arbeitsschritt %d" % task)
		assert_eq(world.execute(Command.demolish(id)), "", "Abriss (%d):" % task)
		assert_true(worker.is_idle(), "Untätig (%d)" % task)
		assert_eq([worker.carried_good, worker.carried_amount, worker.storage_id], ["", 0, 0],
				"Ware verfällt (%d):" % task)
		_steps(world, 600)
		assert_eq(world.get_stock("flour"), 0, "Kein Mehl (%d):" % task)
		assert_eq(world.get_stock("wheat"), 0 if task != Resident.Task.FETCHING else 3, "Weizen (%d):" % task)


func test_demolished_storage_while_fetching_seeks_another() -> void:
	var world := _founded()
	var second := build(world, "warehouse", SECOND_WAREHOUSE_SITE)
	build(world, "mill", MILL_SITE)
	put_goods(world, WAREHOUSE, "wheat", 3)
	put_goods(world, second, "wheat", 1)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.FETCHING and worker.storage_id == second,
			"Holen im zweiten Lager")
	# Ein Lager wird nur leer abgerissen.
	put_goods(world, second, "wheat", 0)
	assert_eq(world.execute(Command.demolish(second)), "", "Abriss:")
	assert_eq([worker.task, worker.storage_id], [Resident.Task.FETCHING, WAREHOUSE], "Sofort zum anderen Lager:")
	_until(world, func() -> bool: return world.get_stock("flour") == 3, "Mehl trotzdem geliefert")


func test_demolished_storage_while_delivering_seeks_another() -> void:
	var world := _founded()
	var second := build(world, "warehouse", SECOND_WAREHOUSE_SITE)
	build(world, "mill", MILL_SITE)
	put_goods(world, WAREHOUSE, "wheat", 3)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg mit dem Mehl")
	assert_eq(worker.storage_id, second, "Zum nächsten Lager:")
	assert_eq(world.execute(Command.demolish(second)), "", "Abriss:")
	assert_eq([worker.task, worker.storage_id], [Resident.Task.TO_STORAGE, WAREHOUSE], "Sofort zum anderen Lager:")
	_until(world, func() -> bool: return world.get_stock("flour") == 3, "Mehl geliefert")


func test_unreachable_storage_with_wheat_waits_until_way_is_free() -> void:
	var world := _founded()
	build(world, "mill", MILL_SITE)
	put_goods(world, WAREHOUSE, "wheat", 3)
	var front := world.get_building(WAREHOUSE).entrance_front()
	add_deposit(world, front, "stone")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return _standing_in(worker, Resident.Task.WAITING_FOR_INPUT), "Warten")
	assert_eq(world.activity_of(worker), "Müller – wartet: kein Weizen erreichbar", "Tätigkeit:")
	world.map.remove_deposit(front)
	_until(world, func() -> bool: return world.get_stock("flour") == 3, "Mehl nach freiem Weg")


func test_save_mid_production_gives_same_course() -> void:
	for task: Resident.Task in [Resident.Task.FETCHING, Resident.Task.WAITING_FOR_INPUT, Resident.Task.RETURNING,
			Resident.Task.PRODUCING]:
		var world := _founded()
		var second := build(world, "warehouse", SECOND_WAREHOUSE_SITE)
		build(world, "mill", MILL_SITE)
		put_goods(world, second, "wheat", 1)
		if task != Resident.Task.WAITING_FOR_INPUT:
			put_goods(world, WAREHOUSE, "wheat", 2)
		var worker := world.get_resident(1)
		# Beim Holen: mitten auf dem Weg zum zweiten Lager, mit Ware in der Hand.
		_until(world, func() -> bool:
			return worker.task == task and (task != Resident.Task.FETCHING or worker.carried_amount == 1),
			"Arbeitsschritt %d" % task)
		var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
		assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden (%d):" % task)
		for each: GameWorld in [world, loaded]:
			if task == Resident.Task.WAITING_FOR_INPUT:
				put_goods(each, WAREHOUSE, "wheat", 2)
			_steps(each, 800)
		assert_eq(world.get_stock("flour"), 3, "Mehl kommt an (%d):" % task)
		assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten (%d):" % task)
