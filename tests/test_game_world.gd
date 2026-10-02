extends TestCase


func _make_world() -> GameWorld:
	return run_scenario("tiny", 0)


func _make_world_with_seed(world_seed: int) -> GameWorld:
	return run_scenario_with_seed("tiny", 0, world_seed)


func _run(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


func test_new_world_starts_at_tick_zero_on_day_one() -> void:
	var world := _make_world()
	assert_eq(world.get_tick(), 0, "Takt:")
	assert_eq(world.get_day(), 1, "Tag:")


func test_step_advances_one_tick() -> void:
	var world := _make_world()
	_run(world, 3)
	assert_eq(world.get_tick(), 3, "Takt:")


func test_day_changes_after_ticks_per_day() -> void:
	var world := _make_world()
	_run(world, GameWorld.TICKS_PER_DAY - 1)
	assert_eq(world.get_day(), 1, "Tag kurz vor Tageswechsel:")
	world.step()
	assert_eq(world.get_day(), 2, "Tag nach Tageswechsel:")
	_run(world, GameWorld.TICKS_PER_DAY * 3)
	assert_eq(world.get_day(), 5, "Tag nach weiteren drei Tagen:")


func test_day_is_600_ticks() -> void:
	assert_eq(GameWorld.TICKS_PER_DAY, 600, "Takte pro Tag:")


func test_day_started_signal_fires_once_per_day() -> void:
	var world := _make_world()
	var days: Array[int] = []
	world.day_started.connect(func(day: int) -> void: days.append(day))
	_run(world, GameWorld.TICKS_PER_DAY * 3)
	assert_eq(days, [2, 3, 4] as Array[int], "Gemeldete Tage:")


func test_map_size_comes_from_scenario() -> void:
	var world := _make_world()
	assert_eq(Vector2i(world.map.width, world.map.height), Vector2i(20, 16), "Kartengröße:")


func test_world_knows_its_scenario_and_seed() -> void:
	var world := _make_world()
	assert_eq(world.get_scenario_id(), "tiny", "Szenario:")
	assert_eq(world.get_seed(), 7, "Seed aus dem Szenario:")


func test_seed_override_replaces_scenario_seed() -> void:
	var world := _make_world_with_seed(42)
	var expected := MapGenerator.generate(42, 20, 16)
	assert_eq(world.get_seed(), 42, "Seed:")
	assert_eq(world.map.deposits.keys(), expected.deposits.keys(), "Vorkommen wie beim Kartengenerator mit Seed 42:")


func test_scenario_seed_is_used_for_map() -> void:
	var world := _make_world()
	var expected := MapGenerator.generate(7, 20, 16)
	assert_eq(world.map.deposits.keys(), expected.deposits.keys(), "Vorkommen wie beim Kartengenerator mit Seed 7:")


func test_same_scenario_and_seed_give_same_world_after_ticks() -> void:
	var ticks := GameWorld.TICKS_PER_DAY * 3 + 17
	var first := run_scenario_with_seed("tiny", ticks, 99)
	var second := run_scenario_with_seed("tiny", ticks, 99)
	assert_eq(world_snapshot(first), world_snapshot(second), "Spielwelt nach %d Takten:" % ticks)


func test_different_seeds_give_different_worlds() -> void:
	assert_true(world_snapshot(_make_world_with_seed(1)) != world_snapshot(_make_world_with_seed(2)), "Seeds 1 und 2 sollten verschiedene Karten ergeben")


func test_deposit_removed_is_reported_by_world() -> void:
	var world := _make_world_with_seed(42)
	var removed: Array[Vector2i] = []
	world.deposit_removed.connect(func(tile: Vector2i) -> void: removed.append(tile))
	var tile: Vector2i = world.map.deposits.keys()[0]
	world.map.remove_deposit(tile)
	assert_eq(removed, [tile] as Array[Vector2i], "Entfernte Vorkommen:")
