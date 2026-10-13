extends TestCase
## Roden: Markierungen sind Befehle, bleiben im Spielstand und beeinflussen nur die nächste
## Vorkommenssuche. Reichweite, Wege, Reservierungen und der Warenfluss bleiben gültig.

const NEAR := Vector2i(14, 3)
const FAR := Vector2i(16, 8)
const SITE := Vector2i(12, 2)


func _world() -> GameWorld:
	var world := empty_world()
	assert_eq(world.execute(Command.found(Vector2i(2, 2))), "")
	add_deposit(world, NEAR, "tree")
	add_deposit(world, FAR, "tree")
	return world


func _until(world: GameWorld, condition: Callable) -> void:
	for i in 1000:
		if condition.call():
			return
		world.step()
	assert_true(false, "Arbeitszustand nach 1000 Takten nicht erreicht")


func test_mark_and_remove_batch_without_mining() -> void:
	var world := _world()
	var changes: Array[Vector2i] = []
	world.clearing_changed.connect(func(tile: Vector2i) -> void: changes.append(tile))
	assert_eq(world.execute(Command.mark_clearing([NEAR, FAR, NEAR])), "")
	assert_eq(changes, [NEAR, FAR] as Array[Vector2i], "Doppelte Kachel nur einmal gemeldet:")
	assert_true(world.map.get_deposit(NEAR).marked_for_clearing)
	assert_true(world.map.get_deposit(FAR).marked_for_clearing)
	assert_eq(world.map.get_deposit(NEAR).amount, 40, "Markieren baut nichts ab:")
	assert_eq(world.execute(Command.mark_clearing([NEAR])), "")
	assert_eq(changes.size(), 2, "Erneutes Markieren meldet keine Änderung:")
	assert_eq(world.execute(Command.mark_clearing([NEAR, FAR], false)), "")
	assert_false(world.map.get_deposit(NEAR).marked_for_clearing)
	assert_false(world.map.get_deposit(FAR).marked_for_clearing)


func test_invalid_batch_changes_nothing() -> void:
	var world := _world()
	var rock := Vector2i(18, 8)
	add_deposit(world, rock, "stone")
	for invalid: Vector2i in [rock, Vector2i.ZERO, Vector2i(-1, -1)]:
		var tiles: Array[Vector2i] = [NEAR, invalid]
		assert_true(world.clearing_error(tiles) != "")
		assert_eq(world.execute(Command.mark_clearing(tiles)), world.clearing_error(tiles))
		assert_false(world.map.get_deposit(NEAR).marked_for_clearing, "Kein Teilbefehl:")
	assert_true(world.execute(Command.mark_clearing([])) != "")


func test_founding_and_defeat_reject_clearing() -> void:
	var world := empty_world()
	add_deposit(world, NEAR, "tree")
	assert_eq(world.execute(Command.mark_clearing([NEAR])), GameWorld.FOUNDING_FIRST)
	assert_eq(world.clearing_error([NEAR]), GameWorld.FOUNDING_FIRST)
	assert_eq(world.clearing_tool_error(), GameWorld.FOUNDING_FIRST)
	world = _world()
	assert_eq(world.clearing_tool_error(), "")
	var data := world.to_data()
	data["defeated"] = true
	world = GameWorld.from_data(data)
	assert_eq(world.execute(Command.mark_clearing([NEAR])), GameWorld.DEFEATED)
	assert_eq(world.clearing_error([NEAR]), GameWorld.DEFEATED)
	assert_eq(world.clearing_tool_error(), GameWorld.DEFEATED)
	assert_false(world.map.get_deposit(NEAR).marked_for_clearing)


func test_marked_tree_has_priority_and_delivers_wood() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING)
	assert_eq(worker.deposit_tile, FAR, "Weiter entfernter markierter Baum zuerst:")
	var before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") > before)
	assert_eq(world.get_stock("wood"), before + 4, "Normaler Warenfluss:")
	assert_eq(world.map.get_deposit(NEAR).amount, 40, "Naher Baum unberührt:")


func test_nearest_marked_tree_wins_regardless_of_mark_order() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	assert_eq(world.execute(Command.mark_clearing([FAR, NEAR])), "")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT)
	assert_eq(worker.deposit_tile, NEAR)


func test_out_of_range_and_unreachable_marks_do_not_block_normal_work() -> void:
	for blocked: bool in [false, true]:
		var world := _world()
		var target := FAR if blocked else Vector2i(0, 15)
		if blocked:
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				world.map.set_terrain(target + step, "water")
		else:
			add_deposit(world, target, "tree")
		build(world, "woodcutter", SITE)
		assert_eq(world.execute(Command.mark_clearing([target])), "")
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT)
		assert_eq(worker.deposit_tile, NEAR, "Nicht erreichbare Markierung übersprungen:")
		assert_true(world.clearing_warning(target) != "", "Hinweis zur Erreichbarkeit:")


func test_running_mining_finishes_then_prioritizes_mark() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING)
	var timer := worker.timer
	assert_eq(worker.deposit_tile, NEAR)
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	assert_eq(worker.task, Resident.Task.MINING)
	assert_eq(worker.timer, timer, "Laufende Arbeit nicht abgebrochen:")
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT and worker.deposit_tile == FAR)
	assert_eq(world.map.get_deposit(NEAR).amount, 36, "Vorheriger Arbeitsgang beendet:")


func test_cancel_restores_normal_priority() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	assert_eq(world.execute(Command.mark_clearing([FAR], false)), "")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT)
	assert_eq(worker.deposit_tile, NEAR)


func test_marked_tree_remains_exclusive() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	build(world, "woodcutter", Vector2i(15, 2))
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	var first := world.get_resident(1)
	var second := world.get_resident(2)
	_until(world, func() -> bool: return first.task == Resident.Task.MINING and second.task == Resident.Task.MINING)
	assert_eq(first.deposit_tile, FAR)
	assert_eq(second.deposit_tile, NEAR, "Reservierten markierten Baum übersprungen:")


func test_warning_updates_with_staffing_and_demolition() -> void:
	var world := _world()
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	assert_true(world.clearing_warning(FAR) != "")
	var id := build(world, "woodcutter", SITE)
	assert_true(world.clearing_warning(FAR) != "", "Unbesetzte Arbeitsstätte reicht nicht:")
	world.step()
	assert_eq(world.clearing_warning(FAR), "", "Besetzter Holzfäller erreicht Baum:")
	assert_eq(world.execute(Command.demolish(id)), "")
	assert_true(world.clearing_warning(FAR) != "")
	assert_eq(world.clearing_warning(NEAR), "", "Unmarkierter Baum ohne Warnung:")


func test_exhaustion_frees_tile_and_new_tree_is_unmarked() -> void:
	var world := _world()
	world.map.get_deposit(FAR).amount = 4
	build(world, "woodcutter", SITE)
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	_until(world, func() -> bool: return world.map.get_deposit(FAR) == null)
	assert_true(world.map.is_buildable(FAR), "Kachel ist frei:")
	add_deposit(world, FAR, "tree")
	assert_false(world.map.get_deposit(FAR).marked_for_clearing, "Kein dauerhafter Flächenauftrag:")


func test_save_load_preserves_marks_and_continuation() -> void:
	var world := _world()
	build(world, "woodcutter", SITE)
	assert_eq(world.execute(Command.mark_clearing([FAR])), "")
	var loaded := GameWorld.from_data(world.to_data())
	assert_true(loaded.map.get_deposit(FAR).marked_for_clearing)
	assert_false(loaded.map.get_deposit(NEAR).marked_for_clearing)
	for i in 500:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleiche Fortsetzung nach Laden:")


func test_older_deposit_data_loads_without_marks() -> void:
	var world := _world()
	var data := world.to_data()
	var map_data: Dictionary = data["map"]
	for entry: Dictionary in map_data["deposits"]:
		var deposit_data: Dictionary = entry["deposit"]
		deposit_data.erase("marked_for_clearing")
	var loaded := GameWorld.from_data(data)
	assert_true(loaded != null, "Alte Spielstände derselben Formatversion weiterhin ladbar:")
	assert_false(loaded.map.get_deposit(FAR).marked_for_clearing)
