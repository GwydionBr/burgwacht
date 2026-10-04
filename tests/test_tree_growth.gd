extends TestCase
## Simulationstests: Bäume wachsen nach. In den Spieldaten ist das Wachstum
## vorerst aus (Chance 0); die Tests setzen dafür eine eigene Chance.

const GROWTH_CHANCE := 0.005


func _interval() -> int:
	return int(GameDefs.get_instance().deposits["tree"]["spread"]["interval_ticks"])


## Lässt die Welt mit vorübergehend geänderter Wachstumschance laufen;
## die Spieldaten sind danach wieder wie vorher.
func _run_with_chance(world: GameWorld, ticks: int, chance: float) -> void:
	var spread: Dictionary = GameDefs.get_instance().deposits["tree"]["spread"]
	var old_chance: float = spread["chance"]
	spread["chance"] = chance
	for i in ticks:
		world.step()
	spread["chance"] = old_chance


## Tiny-Welt, aber leergeräumt (nur Wiese, keine Vorkommen), Burg links unten gegründet.
func _empty_world() -> GameWorld:
	var world := empty_world()
	world.execute(Command.found(Vector2i(1, 8)))
	return world


func _tree_tiles(world: GameWorld) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in world.map.deposits:
		if world.map.deposits[tile].type == "tree":
			tiles.append(tile)
	tiles.sort()
	return tiles


## Läuft N Tage mit GROWTH_CHANCE und liefert die per Signal gemeldeten neuen Vorkommen.
func _run_days_collecting_added(world: GameWorld, days: int) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	world.deposit_added.connect(func(tile: Vector2i) -> void: added.append(tile))
	_run_with_chance(world, GameWorld.TICKS_PER_DAY * days, GROWTH_CHANCE)
	return added


func test_trees_grow_over_days() -> void:
	var world := run_scenario("tiny", 0)
	var before := _tree_tiles(world).size()
	_run_with_chance(world, GameWorld.TICKS_PER_DAY * 5, GROWTH_CHANCE)
	var after := _tree_tiles(world).size()
	assert_true(after > before, "Nach 5 Tagen sollten mehr Bäume stehen als %d, sind %d" % [before, after])


func test_trees_grow_only_next_to_trees_on_free_buildable_tiles() -> void:
	var world := _empty_world()
	var rng := RandomNumberGenerator.new()
	world.map.add_deposit(Vector2i(5, 5), Deposit.create("tree", rng))
	world.map.set_terrain(Vector2i(6, 5), "water")
	world.map.set_terrain(Vector2i(4, 5), "sand")
	world.map.add_deposit(Vector2i(5, 6), Deposit.create("stone", rng))
	# Ein Felsen allein lässt keine Bäume wachsen.
	world.map.add_deposit(Vector2i(15, 10), Deposit.create("stone", rng))
	_run_with_chance(world, _interval(), 1.0)
	var expected: Array[Vector2i] = [
		Vector2i(4, 4), Vector2i(4, 6), Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 4), Vector2i(6, 6),
	]
	assert_eq(_tree_tiles(world), expected, "Bäume:")
	assert_eq(world.map.get_deposit(Vector2i(5, 6)).type, "stone", "Felsen bleibt:")


func test_spread_chance_zero_stops_growth() -> void:
	var world := run_scenario("tiny", 0)
	var before := _tree_tiles(world)
	_run_with_chance(world, GameWorld.TICKS_PER_DAY * 5, 0.0)
	assert_eq(_tree_tiles(world), before, "Mit Chance 0 keine neuen Bäume:")


func test_trees_grow_only_at_interval() -> void:
	var world := _empty_world()
	world.map.add_deposit(Vector2i(5, 5), Deposit.create("tree", RandomNumberGenerator.new()))
	_run_with_chance(world, _interval() - 1, 1.0)
	var before_interval := _tree_tiles(world).size()
	_run_with_chance(world, 1, 1.0)
	assert_eq(before_interval, 1, "Vor Ablauf des Rhythmus:")
	assert_eq(_tree_tiles(world).size(), 9, "Nach einem Rhythmus:")


func test_new_trees_are_reported_by_world() -> void:
	var world := run_scenario("tiny", 0)
	var before := _tree_tiles(world)
	var added := _run_days_collecting_added(world, 5)
	var expected := before.duplicate()
	expected.append_array(added)
	expected.sort()
	assert_true(not added.is_empty(), "Neue Bäume sollten gemeldet werden")
	assert_eq(_tree_tiles(world), expected, "Bäume = vorher + gemeldete:")


func test_same_scenario_and_seed_grow_identical_trees() -> void:
	var first := _run_days_collecting_added(run_scenario_with_seed("tiny", 0, 99), 5)
	var second := _run_days_collecting_added(run_scenario_with_seed("tiny", 0, 99), 5)
	var other := _run_days_collecting_added(run_scenario_with_seed("tiny", 0, 100), 5)
	assert_true(not first.is_empty(), "Es sollten Bäume wachsen")
	assert_eq(first, second, "Neue Bäume bei gleichem Seed:")
	assert_true(first != other, "Anderer Seed sollte andere Bäume ergeben")


func test_trees_do_not_grow_on_buildings_or_in_front_of_entrances() -> void:
	var world := empty_world()
	world.execute(Command.found(Vector2i(2, 2)))
	var reserved: Array[Vector2i] = []
	for building in world.get_buildings():
		reserved.append_array(building.tiles())
		if building.has_entrance():
			reserved.append(building.entrance_front())
	# Bäume rundherum, damit jede Kachel einen Nachbarn hat, von dem aus sie wachsen könnte.
	for y in world.map.height:
		for x in world.map.width:
			var tile := Vector2i(x, y)
			if not tile in reserved and (x + y) % 2 == 0:
				world.map.add_deposit(tile, Deposit.create("tree", RandomNumberGenerator.new()))
	_run_with_chance(world, _interval(), 1.0)
	var grown_on_reserved: Array[Vector2i] = []
	for tile in reserved:
		if world.map.get_deposit(tile) != null:
			grown_on_reserved.append(tile)
	assert_eq(grown_on_reserved, [] as Array[Vector2i], "Bäume auf Grundflächen oder vor Eingängen:")
	assert_true(world.map.get_deposit(Vector2i(15, 12)) != null, "Freie Kacheln wachsen zu")
