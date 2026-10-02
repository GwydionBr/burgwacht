extends TestCase
## Simulationstests: Arbeiter von Holzfäller und Steinbruch bauen Vorkommen ab, verarbeiten
## die Ware in der Arbeitsstätte und tragen sie ins nächste Lager mit Platz.
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), erstes Warenlager (ID 2) bei (7, 2)
## mit Eingang (8, 4), Lagerfeuer (ID 3) bei (3, 8) mit den 4 Startbewohnern.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
## Holzfäller (2×2) mit Eingang bei (12, 3), daneben ein Baum.
const WOODCUTTER_SITE := Vector2i(12, 2)
const TREE := Vector2i(14, 6)
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


## Holzfäller mit Baum daneben; liefert die Welt, der Arbeiter ist Bewohner 1.
func _woodcutter_with_tree(world: GameWorld, site := WOODCUTTER_SITE, tree := TREE) -> int:
	add_deposit(world, tree, "tree")
	return build(world, "woodcutter", site)


func test_gatherer_data() -> void:
	var defs := GameDefs.get_instance()
	var expected := {
		"woodcutter": ["tree", 40, 20, 4, 15],
		"quarry": ["stone", 60, 20, 4, 6],
	}
	for type_id: String in expected:
		var building := Building.create(1, type_id, Vector2i.ZERO)
		var actual := [building.deposit_type(), building.mine_ticks(), building.process_ticks(),
				building.carry_load(), building.gather_range()]
		assert_eq(actual, expected[type_id], "Sammlerwerte von %s:" % type_id)
	assert_eq(defs.deposits["tree"]["exclusive"], true, "Baum exklusiv:")
	assert_eq(defs.deposits["stone"]["exclusive"], false, "Felsen exklusiv:")
	assert_eq(defs.deposits["iron"]["exclusive"], false, "Eisen exklusiv:")


func test_woodcutter_delivers_wood_to_storage() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	var ticks_in: Dictionary[Resident.Task, int] = {}
	var wood_before := world.get_stock("wood")
	for i in MAX_TICKS:
		if world.get_stock("wood") > wood_before:
			break
		world.step()
		if not worker.is_moving():
			ticks_in[worker.task] = ticks_in.get(worker.task, 0) + 1
	assert_eq(world.get_stock("wood"), wood_before + 4, "Holz nach dem ersten Gang (Traglast 4):")
	assert_eq(changed, [WAREHOUSE] as Array[int], "Gemeldete Lager:")
	assert_eq(world.map.get_deposit(TREE).amount, 36, "Rest im Baum:")
	assert_eq(ticks_in.get(Resident.Task.MINING), 40, "Takte beim Abbau:")
	assert_eq(ticks_in.get(Resident.Task.PROCESSING), 20, "Takte beim Verarbeiten:")
	assert_eq(worker.carried_amount, 0, "Trägt danach nichts mehr:")
	assert_eq(worker.task, Resident.Task.TO_WORKPLACE, "Geht zurück zur Arbeitsstätte:")


func test_worker_mines_from_adjacent_walkable_tile() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau")
	var offset := worker.tile - TREE
	assert_eq(absi(offset.x) + absi(offset.y), 1, "Steht mit gemeinsamer Kante am Baum: Versatz %s" % str(offset))
	assert_true(world.is_walkable(worker.tile, worker.level), "Steht auf begehbarer Kachel")
	assert_eq(worker.deposit_tile, TREE, "Baut den Baum ab:")


func test_nearest_deposit_by_path_length() -> void:
	var world := _founded()
	# Luftlinie näher, aber hinter Wasser: der Weg zum anderen Baum ist kürzer.
	var near_but_walled := Vector2i(12, 7)
	add_deposit(world, near_but_walled, "tree")
	for x in range(8, 17):
		world.map.set_terrain(Vector2i(x, 6), "water")
	_woodcutter_with_tree(world, WOODCUTTER_SITE, Vector2i(17, 3))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT, "Weg zum Baum")
	assert_eq(worker.deposit_tile, Vector2i(17, 3), "Baum mit kürzerem Weg:")


func test_tree_disappears_when_exhausted() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	world.map.get_deposit(TREE).amount = 6
	var removed: Array[Vector2i] = []
	world.deposit_removed.connect(func(tile: Vector2i) -> void: removed.append(tile))
	var wood_before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 4, "erster Gang")
	assert_eq(world.map.get_deposit(TREE).amount, 2, "Nach einem Gang:")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 6, "zweiter Gang mit dem Rest")
	assert_eq(world.map.get_deposit(TREE), null, "Baum ist weg")
	assert_eq(removed, [TREE] as Array[Vector2i], "Gemeldet:")


func test_two_woodcutters_never_at_the_same_tree() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	build(world, "woodcutter", Vector2i(15, 2))
	var seen_waiting := false
	for i in 400:
		world.step()
		var targets: Dictionary[Vector2i, int] = {}
		for resident in world.get_residents():
			if resident.task == Resident.Task.TO_DEPOSIT or resident.task == Resident.Task.MINING:
				assert_true(not targets.has(resident.deposit_tile),
						"Bewohner %d und %d am selben Baum" % [targets.get(resident.deposit_tile, 0), resident.id])
				targets[resident.deposit_tile] = resident.id
			if resident.task == Resident.Task.WAITING_FOR_DEPOSIT:
				seen_waiting = true
	assert_true(seen_waiting, "Der zweite Holzfäller wartet, solange der einzige Baum reserviert ist")


func test_two_woodcutters_take_different_trees() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	add_deposit(world, Vector2i(16, 6), "tree")
	build(world, "woodcutter", Vector2i(15, 2))
	var first := world.get_resident(1)
	var second := world.get_resident(2)
	_until(world, func() -> bool:
		return first.task == Resident.Task.MINING and second.task == Resident.Task.MINING, "beide fällen")
	assert_true(first.deposit_tile != second.deposit_tile, "Verschiedene Bäume")


func test_two_workers_share_a_rock() -> void:
	var world := _founded()
	var rock := Vector2i(10, 10)
	add_deposit(world, rock, "stone")
	# Links und rechts vom Felsen je ein Steinbruch (3×3).
	build(world, "quarry", rock - Vector2i(3, 1))
	build(world, "quarry", rock + Vector2i(1, -1))
	var first := world.get_resident(1)
	var second := world.get_resident(2)
	_until(world, func() -> bool:
		return first.task == Resident.Task.MINING and second.task == Resident.Task.MINING, "beide bauen ab")
	assert_eq(first.deposit_tile, rock, "Erster am Felsen:")
	assert_eq(second.deposit_tile, rock, "Zweiter am selben Felsen:")


func test_no_deposit_in_range_waits_and_retries() -> void:
	var world := _founded()
	# Holzfäller oben rechts, Baum unten links: weiter weg als der Suchradius.
	var id := _woodcutter_with_tree(world, Vector2i(16, 0), Vector2i(0, 15))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_DEPOSIT and not worker.is_moving(),
			"Warten")
	assert_eq(worker.tile, world.get_building(id).entrance(), "Wartet in der Arbeitsstätte:")
	assert_true(worker.is_inside_building(), "Unsichtbar im Gebäude")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Kein Baum erreichbar", "Tätigkeit:")
	# Ein Baum in der Nähe: nach der Wartezeit geht er hin.
	add_deposit(world, Vector2i(16, 5), "tree")
	_steps(world, Resident.retry_ticks())
	assert_eq(worker.task, Resident.Task.TO_DEPOSIT, "Nach der Wartezeit unterwegs:")
	assert_eq(worker.deposit_tile, Vector2i(16, 5), "Zum neuen Baum:")


func test_quarry_without_rock_in_range_says_rock() -> void:
	var world := _founded()
	var rock := Vector2i(10, 10)
	add_deposit(world, rock, "stone")
	build(world, "quarry", rock - Vector2i(3, 1))
	world.map.remove_deposit(rock)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_DEPOSIT and not worker.is_moving(),
			"Warten")
	assert_eq(world.activity_of(worker), "Steinbrucharbeiter – wartet: Kein Felsen erreichbar", "Tätigkeit:")


## Zweites Warenlager (ID 4) rechts am ersten, Holzfäller (ID 5) mit Baum rechts daneben;
## das zweite Lager liegt dem Holzfäller näher.
func _two_warehouses() -> GameWorld:
	var world := _founded()
	assert_eq(build(world, "warehouse", Vector2i(10, 1)), 4, "Zweites Lager:")
	_woodcutter_with_tree(world, Vector2i(15, 2), Vector2i(16, 7))
	return world


func test_partial_delivery_carries_rest_to_next_storage() -> void:
	var world := _two_warehouses()
	put_goods(world, 4, "stone", 198)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var wood_before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 4, "Lieferung")
	assert_eq(world.get_building(4).contents.get("wood", 0), 2, "Ins nächste Lager, so viel passt:")
	assert_eq(world.get_building(WAREHOUSE).contents["wood"], wood_before + 2, "Rest ins andere Lager:")
	assert_eq(changed, [4, WAREHOUSE] as Array[int], "Gemeldete Lager:")


func test_all_storages_full_waits_with_goods() -> void:
	var world := _two_warehouses()
	put_goods(world, 4, "stone", 200)
	var first := world.get_building(WAREHOUSE)
	put_goods(world, WAREHOUSE, "stone", first.capacity() - first.contents["wood"])
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_STORAGE and not worker.is_moving(),
			"Warten bei vollem Lager")
	assert_eq(worker.tile, world.get_building(5).entrance(), "Wartet an der Arbeitsstätte:")
	assert_eq(worker.carried_amount, 4, "Behält die Ware:")
	assert_true(not worker.is_inside_building(), "Sichtbar mit der Ware")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Lager voll", "Tätigkeit:")
	# Wieder Platz: nach der Wartezeit liefert er.
	put_goods(world, 4, "stone", 100)
	var wood_before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 4, "Lieferung nach dem Warten")


func test_activity_while_carrying() -> void:
	var world := _founded()
	_woodcutter_with_tree(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau")
	assert_eq(world.activity_of(worker), "Holzfäller – baut Baum ab", "Beim Abbau:")
	_until(world, func() -> bool: return worker.task == Resident.Task.RETURNING, "Rückweg")
	assert_eq(world.activity_of(worker), "Holzfäller – trägt 4 Holz", "Auf dem Rückweg:")
	assert_eq(worker.carried_good, "wood", "Ware:")
	_until(world, func() -> bool: return worker.task == Resident.Task.PROCESSING, "Verarbeiten")
	assert_true(worker.is_inside_building(), "Beim Verarbeiten unsichtbar")
	assert_eq(world.activity_of(worker), "Holzfäller – verarbeitet 4 Holz", "Beim Verarbeiten:")
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg zum Lager")
	assert_eq(world.activity_of(worker), "Holzfäller – trägt 4 Holz", "Zum Lager:")


func test_demolished_workplace_drops_goods_and_reservation() -> void:
	var world := _founded()
	var id := _woodcutter_with_tree(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.RETURNING, "Rückweg")
	world.execute(Command.demolish(id))
	assert_eq(worker.task, Resident.Task.NONE, "Keine Arbeit mehr:")
	assert_eq(worker.carried_amount, 0, "Ware verfällt:")
	# Ein neuer Holzfäller darf denselben Baum gleich wieder nehmen.
	build(world, "woodcutter", WOODCUTTER_SITE)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau am selben Baum")
	assert_eq(worker.deposit_tile, TREE, "Baum:")


func test_save_mid_work_gives_same_course() -> void:
	for task: Resident.Task in [Resident.Task.MINING, Resident.Task.PROCESSING, Resident.Task.TO_STORAGE]:
		var world := _two_warehouses()
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == task, "Arbeitsgang")
		var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
		assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden (%d):" % task)
		for each: GameWorld in [world, loaded]:
			_steps(each, 800)
		assert_true(world.get_stock("wood") > 97, "Holz kommt an")
		assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten (%d):" % task)


func test_quarry_worker_ignores_tree_grown_where_rock_was() -> void:
	var world := _founded()
	var rock := Vector2i(10, 10)
	add_deposit(world, rock, "stone")
	build(world, "quarry", rock - Vector2i(3, 1))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT, "Weg zum Felsen")
	# Felsen erschöpft, an seiner Stelle wächst ein Baum.
	world.map.remove_deposit(rock)
	add_deposit(world, rock, "tree")
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_DEPOSIT, "Warten")
	assert_eq(worker.carried_amount, 0, "Trägt nichts:")
	assert_eq(world.map.get_deposit(rock).amount, 40, "Baum unberührt:")
