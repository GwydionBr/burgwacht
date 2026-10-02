extends TestCase
## Simulationstests: Apfelplantage (Verhalten „farm“). Ihr Arbeiter arbeitet unsichtbar in
## der Plantage und trägt die Äpfel zum nächsten Kornspeicher. Leere Karte (nur Wiese);
## Bergfried (ID 1) bei (2, 2), Warenlager (ID 2) bei (7, 2), Lagerfeuer (ID 3) bei (3, 8)
## mit den 4 Startbewohnern, Kornspeicher (ID 4) bei (7, 6).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const GRANARY := 4
## Freie Stelle für eine Plantage (4×4) rechts vom Warenlager.
const SITE := Vector2i(12, 2)
const ONLY_ON_GRASS := "Nur auf Wiese"
## Obergrenze für einen ganzen Arbeitsgang.
const MAX_TICKS := 1000


func _founded() -> GameWorld:
	var world := empty_world()
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


func test_orchard_data() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["orchard"]
	assert_eq(str(def["name"]), "Apfelplantage", "Name:")
	assert_eq(str(def["behavior"]), "farm", "Verhalten:")
	assert_eq(Building.size_of("orchard"), Vector2i(4, 4), "Größe:")
	var orchard := Building.create(1, "orchard", Vector2i.ZERO)
	assert_eq(orchard.worker_slots(), 1, "Arbeiter:")
	assert_eq(orchard.work_ticks(), 200, "Arbeitsdauer:")
	assert_eq(orchard.product(), "apples", "Ware:")
	assert_eq(orchard.carry_load(), 4, "Traglast:")
	assert_eq(int(def["cost"]["wood"]), 5, "Kosten Holz:")
	assert_eq((def["cost"] as Dictionary).size(), 1, "Nur Holz:")
	assert_true(GameWorld.buildable_types().has("orchard"), "Apfelplantage hat eine Bautaste")


func test_orchard_on_grass_and_meadow_is_allowed() -> void:
	var world := _founded()
	world.map.set_terrain(SITE + Vector2i(3, 3), "meadow")
	assert_eq(world.build_error("orchard", SITE), "", "Wiese und Blumenwiese:")


func test_orchard_with_one_tile_of_dirt_is_rejected() -> void:
	var world := _founded()
	world.map.set_terrain(SITE + Vector2i(2, 1), "dirt")
	var before := world.to_data()
	assert_eq(world.build_error("orchard", SITE), ONLY_ON_GRASS, "Abfrage:")
	assert_eq(world.execute(Command.build("orchard", SITE)), ONLY_ON_GRASS, "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_dirt_only_next_to_orchard_does_not_matter() -> void:
	var world := _founded()
	world.map.set_terrain(SITE + Vector2i(4, 0), "dirt")
	assert_eq(world.build_error("orchard", SITE), "", "Erde daneben:")


func test_worker_works_inside_and_delivers_apples_to_granary() -> void:
	var world := _founded()
	var orchard := build(world, "orchard", SITE)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	var ticks_inside := 0
	var wood_before := world.get_stock("wood")
	for i in MAX_TICKS:
		if world.get_stock("apples") > 0:
			break
		world.step()
		if worker.is_inside_building():
			ticks_inside += 1
	assert_eq(worker.workplace_id, orchard, "Zugeteilt:")
	assert_eq(world.get_building(GRANARY).contents, {"apples": 4} as Dictionary[String, int], "Kornspeicher:")
	assert_eq(world.get_stock("wood"), wood_before, "Warenlager unberührt:")
	assert_eq(changed, [GRANARY] as Array[int], "Gemeldete Lager:")
	assert_eq(ticks_inside, 200, "Takte in der Plantage:")
	assert_eq(worker.carried_amount, 0, "Trägt danach nichts mehr:")
	assert_eq(worker.task, Resident.Task.TO_WORKPLACE, "Geht zurück zur Plantage:")
	# Der nächste Gang liefert wieder.
	_until(world, func() -> bool: return world.get_stock("apples") == 8, "Zweiter Gang")


func test_worker_comes_out_at_entrance_with_apples() -> void:
	var world := _founded()
	var orchard := world.get_building(build(world, "orchard", SITE))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.is_inside_building(), "Arbeit in der Plantage")
	assert_eq(worker.tile, orchard.entrance(), "Arbeitet am Eingang:")
	assert_eq(worker.carried_amount, 0, "Trägt beim Arbeiten nichts:")
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg zum Kornspeicher")
	assert_true(not worker.is_inside_building(), "Kommt heraus")
	assert_eq(worker.carried_good, "apples", "Ware:")
	assert_eq(worker.carried_amount, 4, "Menge:")
	assert_eq(worker.storage_id, GRANARY, "Ziel:")


func test_activity_texts() -> void:
	var world := _founded()
	build(world, "orchard", SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.is_inside_building(), "Arbeit in der Plantage")
	assert_eq(world.activity_of(worker), "Plantagenarbeiter – arbeitet in der Plantage", "Beim Arbeiten:")
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg zum Kornspeicher")
	assert_eq(world.activity_of(worker), "Plantagenarbeiter – trägt 4 Äpfel", "Zum Kornspeicher:")


func test_all_granaries_full_waits_with_apples_and_retries() -> void:
	var world := _founded()
	var orchard := world.get_building(build(world, "orchard", SITE))
	put_goods(world, GRANARY, "meat", 200)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_STORAGE and not worker.is_moving(),
			"Warten bei vollem Kornspeicher")
	assert_eq(worker.tile, orchard.entrance(), "Wartet an der Plantage:")
	assert_eq([worker.carried_good, worker.carried_amount], ["apples", 4], "Behält die Äpfel:")
	assert_true(not worker.is_inside_building(), "Sichtbar mit der Ware")
	assert_eq(world.activity_of(worker), "Plantagenarbeiter – wartet: Lager voll", "Tätigkeit:")
	# Platz im Warenlager hilft nicht: Äpfel gehören in den Kornspeicher.
	_steps(world, Resident.retry_ticks() + 1)
	assert_eq(worker.task, Resident.Task.WAITING_FOR_STORAGE, "Wartet weiter trotz Platz im Warenlager:")
	# Wieder Platz im Kornspeicher: nach der Wartezeit liefert er.
	put_goods(world, GRANARY, "meat", 100)
	_until(world, func() -> bool: return world.get_stock("apples") == 4, "Lieferung nach dem Warten")


func test_unreachable_granary_waits_until_way_is_free() -> void:
	var world := _founded()
	build(world, "orchard", SITE)
	# Ein Felsen versperrt die einzige Kachel vor dem Eingang des Kornspeichers.
	var front := world.get_building(GRANARY).entrance_front()
	add_deposit(world, front, "stone")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_STORAGE and not worker.is_moving(),
			"Warten bei versperrtem Kornspeicher")
	assert_eq(worker.carried_amount, 4, "Behält die Äpfel:")
	world.map.remove_deposit(front)
	_until(world, func() -> bool: return world.get_stock("apples") == 4, "Lieferung nach freiem Weg")


func test_demolished_orchard_mid_work_leaves_no_half_state() -> void:
	for task: Resident.Task in [Resident.Task.TO_WORKPLACE, Resident.Task.FARMING, Resident.Task.TO_STORAGE]:
		var world := _founded()
		var id := build(world, "orchard", SITE)
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == task and (task != Resident.Task.TO_WORKPLACE or worker.is_moving()),
				"Arbeitsgang %d" % task)
		assert_eq(world.execute(Command.demolish(id)), "", "Abriss (%d):" % task)
		assert_true(worker.is_idle(), "Untätig (%d)" % task)
		assert_eq([worker.task, worker.carried_amount, worker.timer], [Resident.Task.NONE, 0, 0],
				"Kein Arbeitsgang, keine Ware (%d):" % task)
		assert_true(not worker.is_inside_building(), "Sichtbar (%d)" % task)
		_until(world, func() -> bool: return not worker.is_moving(), "Ankunft am Lagerfeuer")
		assert_eq(world.activity_of(worker), "Untätig", "Tätigkeit (%d):" % task)
		assert_eq(world.get_stock("apples"), 0, "Keine Äpfel geliefert (%d):" % task)


func test_demolished_granary_on_the_way_waits_at_orchard() -> void:
	var world := _founded()
	build(world, "orchard", SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg zum Kornspeicher")
	assert_eq(world.execute(Command.demolish(GRANARY)), "", "Abriss des Kornspeichers:")
	assert_eq(worker.task, Resident.Task.WAITING_FOR_STORAGE, "Kein Kornspeicher mehr:")
	assert_eq(worker.carried_amount, 4, "Behält die Äpfel:")


func test_save_mid_work_gives_same_course() -> void:
	for task: Resident.Task in [Resident.Task.FARMING, Resident.Task.TO_STORAGE, Resident.Task.WAITING_FOR_STORAGE]:
		var world := _founded()
		build(world, "orchard", SITE)
		if task == Resident.Task.WAITING_FOR_STORAGE:
			put_goods(world, GRANARY, "meat", 200)
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == task, "Arbeitsgang")
		var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
		assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden (%d):" % task)
		for each: GameWorld in [world, loaded]:
			if task == Resident.Task.WAITING_FOR_STORAGE:
				put_goods(each, GRANARY, "meat", 100)
			_steps(each, 800)
		assert_true(world.get_stock("apples") > 0, "Äpfel kommen an (%d)" % task)
		assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten (%d):" % task)
