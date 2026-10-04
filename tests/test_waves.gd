extends TestCase
## Simulationstests: Angriffswellen nach dem Wellenplan. Leere Karte (nur Wiese) 20×16, meist
## tiny_waves (Welle 1 an Tag 2 mit 1 Räuber aus Osten, Welle 2 an Tag 3 mit 1 Räuber von
## zufälliger Seite, Welle 3 an Tag 3 mit 2 Räubern aus Süden); Bergfried bei (2, 2) mit der
## Grundfläche (2..5, 2..5). Räuber greifen den Bergfried an: Mehr als ein Räuber ab Tag 2 brächte
## ihn vor Tag 3 zu Fall.

const KEEP_ORIGIN := Vector2i(2, 2)
## Randkachel im Osten nächst dem Bergfried: Abstand 14, zeilenweise die erste solche.
const EAST_SPAWN := Vector2i(19, 2)


func _founded(scenario_id := "tiny_waves") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _enemy_tiles(world: GameWorld) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for enemy in world.get_enemies():
		result.append(enemy.tile)
	return result


func _enemy_waves(world: GameWorld) -> Array[int]:
	var result: Array[int] = []
	for enemy in world.get_enemies():
		result.append(enemy.wave)
	return result


func test_wave_appears_at_the_start_of_its_day_on_its_side() -> void:
	var world := _founded()
	_run_world(world, GameWorld.TICKS_PER_DAY - 1)
	assert_eq(world.get_enemies().size(), 0, "Feinde vor Tag 2:")
	world.step()
	assert_eq(world.get_day(), 2, "Tag:")
	assert_eq(_enemy_tiles(world), [EAST_SPAWN] as Array[Vector2i], "Kachel:")
	assert_eq(_enemy_waves(world), [1] as Array[int], "Welle:")
	assert_eq(world.get_enemies()[0].type, "bandit", "Typ:")


func test_wave_enemies_spread_around_the_edge_tile() -> void:
	var world := _world_with_waves([{"day": 2, "enemies": {"bandit": 3}, "side": "east"}])
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	_run_world(world, GameWorld.TICKS_PER_DAY)
	# Gebündelt: der erste auf der Randkachel, die übrigen auf den nächsten freien drumherum.
	assert_eq(_enemy_tiles(world), [EAST_SPAWN, Vector2i(19, 1), Vector2i(19, 3)] as Array[Vector2i], "Kacheln:")
	assert_eq(_enemy_waves(world), [1, 1, 1] as Array[int], "Wellen:")


func test_waves_come_on_schedule_even_while_older_ones_live() -> void:
	var world := _founded()
	_run_world(world, 2 * GameWorld.TICKS_PER_DAY)
	assert_eq(world.get_day(), 3, "Tag:")
	assert_eq(_enemy_waves(world), [1, 2, 3, 3] as Array[int], "Wellen:")
	assert_eq(world.get_next_wave(), 4, "Nächste Welle:")


## Spielwelt 20×16 (nur Wiese) mit diesem Wellenplan und Seed, noch in Gründung.
func _world_with_waves(list: Array, world_seed := 7) -> GameWorld:
	var scenario := Scenario.from_dict("test_waves", {
		"name": "Test", "map": {"width": 20, "height": 16}, "seed": world_seed, "waves": {"list": list}})
	assert_eq(scenario.error, "", "Szenario:")
	return clear_map(GameWorld.create(scenario, world_seed))


## Die Meldungen der Welt ab jetzt.
func _notices(world: GameWorld) -> Array[String]:
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	return notices


func test_wave_without_side_comes_only_from_sides_that_reach_the_keep() -> void:
	for world_seed in range(1, 9):
		var world := _world_with_waves([{"day": 1, "enemies": {"bandit": 2}}], world_seed)
		# Wasser schneidet Norden (Zeile 1), Westen (Spalte 1) und Osten (Spalte 17) vom Bergfried ab.
		for x in world.map.width:
			world.map.set_terrain(Vector2i(x, 1), "water")
		for y in range(2, world.map.height):
			world.map.set_terrain(Vector2i(1, y), "water")
			world.map.set_terrain(Vector2i(17, y), "water")
		var notices := _notices(world)
		assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
		assert_eq(notices, ["Welle aus Süden!"] as Array[String], "Meldungen (Seed %d):" % world_seed)
		assert_eq(world.get_enemies()[0].tile.y, world.map.height - 1, "Zeile der Randkachel (Seed %d):" % world_seed)


func test_random_side_is_deterministic_for_the_same_seed() -> void:
	var sides: Dictionary[String, bool] = {}
	for world_seed in range(1, 11):
		var runs: Array[Array] = []
		for run in 2:
			var world := _world_with_waves([{"day": 1, "enemies": {"bandit": 1}}], world_seed)
			var notices := _notices(world)
			assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
			runs.append([notices.duplicate(), _enemy_tiles(world)])
		assert_eq(runs[1], runs[0], "Gleicher Seed %d:" % world_seed)
		sides[str(runs[0][0][0])] = true
	assert_true(sides.size() > 1, "Bei verschiedenen Seeds verschiedene Seiten: %s" % str(sides.keys()))


func _kill_wave(world: GameWorld, wave: int) -> void:
	for enemy in world.get_enemies():
		if enemy.wave == wave:
			kill_enemy(world, enemy)


func test_overlapping_waves_are_repelled_each_when_all_their_enemies_are_dead() -> void:
	var world := _founded()
	_run_world(world, 2 * GameWorld.TICKS_PER_DAY)
	var notices := _notices(world)
	kill_enemy(world, world.get_enemies()[2])
	assert_eq(world.get_repelled_waves(), 0, "Welle 3 lebt noch zum Teil:")
	_kill_wave(world, 2)
	assert_eq(world.get_repelled_waves(), 1, "Welle 2 abgewehrt, Welle 1 lebt noch:")
	_kill_wave(world, 1)
	assert_eq(world.get_repelled_waves(), 2, "Welle 1 und 2 abgewehrt:")
	assert_eq(notices, ["Welle abgewehrt", "Welle abgewehrt"] as Array[String], "Meldungen:")
	assert_eq(_enemy_waves(world), [3] as Array[int], "Übrig:")


func test_wave_notice_names_its_side() -> void:
	var world := _founded()
	var notices := _notices(world)
	_run_world(world, GameWorld.TICKS_PER_DAY)
	# Ohne Nahrung meldet der Tagesbeginn außerdem den Mangel, dazu kommt die Ankündigung der nächsten.
	assert_eq(notices.filter(func(text: String) -> bool: return text.begins_with("Welle") and text.ends_with("!")),
			["Welle aus Osten!"], "Meldungen:")


func test_start_enemies_belong_to_no_wave() -> void:
	var world := _founded("tiny_bandits")
	var bandit := world.get_enemies()[0]
	assert_eq(bandit.wave, 0, "Welle des Startfeinds:")
	kill_enemy(world, bandit)
	assert_eq(world.get_repelled_waves(), 0, "Abgewehrte Wellen:")


func test_wave_without_enemies_counts_as_repelled_at_once() -> void:
	var world := _world_with_waves([{"day": 1, "enemies": {"bandit": 0}, "side": "west"}])
	var notices := _notices(world)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(world.get_repelled_waves(), 1, "Abgewehrte Wellen:")
	assert_eq(notices, ["Welle aus Westen!", "Welle abgewehrt"] as Array[String], "Meldungen:")


func test_debug_command_brings_the_next_wave_now_and_the_plan_goes_on() -> void:
	var world := _founded()
	assert_eq(world.execute(Command.spawn_wave()), "", "Debug-Welle:")
	assert_eq(_enemy_waves(world), [1] as Array[int], "Welle 1 sofort:")
	assert_eq(world.get_day(), 1, "Tag:")
	# Abwehren, damit der Räuber den Bergfried nicht vor Tag 3 zu Fall bringt.
	_kill_wave(world, 1)
	_run_world(world, GameWorld.TICKS_PER_DAY)
	assert_eq(_enemy_waves(world), [] as Array[int], "An Tag 2 keine weitere:")
	_run_world(world, GameWorld.TICKS_PER_DAY)
	assert_eq(_enemy_waves(world), [2, 3, 3] as Array[int], "An Tag 3 wie geplant:")


func test_debug_wave_is_refused_without_a_next_wave_or_while_founding() -> void:
	var world := empty_world("tiny_waves")
	assert_eq(world.execute(Command.spawn_wave()), GameWorld.FOUNDING_FIRST, "In Gründung:")
	world = _founded("tiny_bandits")
	var before := world.to_data()
	assert_eq(world.execute(Command.spawn_wave()), "Keine weitere Welle geplant", "Ohne Wellenplan:")
	assert_eq(world.to_data(), before, "Unverändert:")


func _reload(world: GameWorld) -> GameWorld:
	return GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))


func test_save_and_load_mid_wave_continues_the_same() -> void:
	var world := _founded()
	_run_world(world, GameWorld.TICKS_PER_DAY + 50)
	kill_enemy(world, world.get_enemies()[0])
	var loaded := _reload(world)
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	# Weiter bis nach Tag 3: Welle 2 zieht ihre Seite aus dem Zufall der Spielwelt.
	_run_world(world, GameWorld.TICKS_PER_DAY)
	_run_world(loaded, GameWorld.TICKS_PER_DAY)
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
	for each: GameWorld in [world, loaded]:
		_kill_wave(each, 2)
	assert_eq(loaded.get_repelled_waves(), 2, "Abgewehrt nach dem Laden:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Gleich nach der Abwehr:")


func test_save_and_load_keeps_the_wave_plan_before_founding() -> void:
	var loaded := _reload(empty_world("tiny_waves"))
	assert_eq(loaded.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	_run_world(loaded, GameWorld.TICKS_PER_DAY)
	assert_eq(_enemy_tiles(loaded), [EAST_SPAWN] as Array[Vector2i], "Welle 1:")


## Gegründete Spielwelt 20×16 (nur Wiese): Welle 1 an Tag 2 aus Osten, danach die Formel alle
## 2 Tage mit abgerundet 1 + 0,5 × n Räubern.
func _world_with_formula() -> GameWorld:
	var scenario := Scenario.from_dict("test_waves", {
		"name": "Test", "map": {"width": 20, "height": 16}, "seed": 7, "waves": {
			"list": [{"day": 2, "enemies": {"bandit": 1}, "side": "east"}],
			"formula": {"every_days": 2, "enemies": {"bandit": {"base": 1, "growth": 0.5}}}}})
	assert_eq(scenario.error, "", "Szenario:")
	var world := clear_map(GameWorld.create(scenario, 7))
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Lässt die Welt bis zum Beginn von Tag last_day laufen; jede Welle wird nach ihrem Erscheinen
## abgewehrt, damit der Bergfried steht. Ergebnis: Tag → Feinde je erschienener Welle.
func _formula_course(world: GameWorld, last_day: int) -> Dictionary[int, Array]:
	var course: Dictionary[int, Array] = {}
	while world.get_day() < last_day:
		_run_world(world, GameWorld.TICKS_PER_DAY)
		var waves := _enemy_waves(world)
		if not waves.is_empty():
			course[world.get_day()] = waves
		for wave in waves:
			_kill_wave(world, wave)
	return course


func test_formula_waves_follow_the_list_and_grow() -> void:
	var world := _world_with_formula()
	assert_eq(_formula_course(world, 9), {2: [1], 4: [2], 6: [3], 8: [4, 4]} as Dictionary[int, Array], "Verlauf:")
	assert_eq(world.get_repelled_waves(), 4, "Abgewehrt:")


func test_save_and_load_between_formula_waves_continues_the_same() -> void:
	var world := _world_with_formula()
	_formula_course(world, 5)
	var loaded := _reload(world)
	for each: GameWorld in [world, loaded]:
		_run_world(each, GameWorld.TICKS_PER_DAY + 50)
	assert_eq(_enemy_waves(loaded), [3] as Array[int], "Welle 3 an Tag 6:")
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf bis Tag 6:")
	for each: GameWorld in [world, loaded]:
		_kill_wave(each, 3)
		_run_world(each, 2 * GameWorld.TICKS_PER_DAY)
	assert_eq(_enemy_waves(loaded), [4, 4] as Array[int], "Welle 4 an Tag 8:")
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf bis Tag 8:")


func test_free_play_brings_the_first_wave_on_day_six() -> void:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	var world := found_castle(GameWorld.create(scenario, 1))
	_run_world(world, 5 * GameWorld.TICKS_PER_DAY - 1)
	assert_eq(world.get_enemies().size(), 0, "Feinde in der Schonfrist:")
	world.step()
	assert_eq(world.get_day(), 6, "Tag:")
	assert_eq(_enemy_waves(world), [1, 1, 1] as Array[int], "Welle 1 mit drei Räubern:")
	var next := scenario.wave_plan.wave(2)
	assert_eq([next.day, next.enemies, next.side], [9, {"bandit": 4, "poacher": 0}, ""], "Welle 2 laut Plan (Wilderer erst ab Welle 3):")


func test_wave_on_day_one_appears_at_founding() -> void:
	var world := _world_with_waves([{"day": 1, "enemies": {"bandit": 1}, "side": "north"}])
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(_enemy_tiles(world), [Vector2i(2, 0)] as Array[Vector2i], "Kachel:")
