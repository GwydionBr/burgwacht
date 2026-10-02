extends TestCase

const SIZE := 30


func _make_world(world_seed := 1) -> GameWorld:
	return GameWorld.create(world_seed, SIZE, SIZE)


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


func test_world_owns_generated_map() -> void:
	var world := _make_world(42)
	var expected := MapGenerator.generate(42, SIZE, SIZE)
	assert_eq(world.map.width, SIZE, "Breite:")
	assert_eq(world.map.deposits.keys(), expected.deposits.keys(), "Vorkommen wie beim Kartengenerator:")


func test_deposit_removed_is_reported_by_world() -> void:
	var world := _make_world(42)
	var removed: Array[Vector2i] = []
	world.deposit_removed.connect(func(tile: Vector2i) -> void: removed.append(tile))
	var tile: Vector2i = world.map.deposits.keys()[0]
	world.map.remove_deposit(tile)
	assert_eq(removed, [tile] as Array[Vector2i], "Entfernte Vorkommen:")
