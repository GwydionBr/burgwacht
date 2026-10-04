extends TestCase
## Simulationstests: Angriffswellen nach dem Wellenplan. Leere Karte (nur Wiese) 20×16, meist
## tiny_waves (Welle 1 an Tag 2 mit 3 Räubern aus Osten, Welle 2 an Tag 3 mit 1 Räuber von
## zufälliger Seite, Welle 3 an Tag 3 mit 2 Räubern aus Süden); Bergfried bei (2, 2) mit der
## Grundfläche (2..5, 2..5).

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
	# Gebündelt: die erste auf der Randkachel, die übrigen auf den nächsten freien drumherum.
	assert_eq(_enemy_tiles(world), [EAST_SPAWN, Vector2i(19, 1), Vector2i(19, 3)] as Array[Vector2i], "Kacheln:")
	assert_eq(_enemy_waves(world), [1, 1, 1] as Array[int], "Wellen:")
	for enemy in world.get_enemies():
		assert_eq(enemy.type, "bandit", "Typ:")


func test_waves_come_on_schedule_even_while_older_ones_live() -> void:
	var world := _founded()
	_run_world(world, 2 * GameWorld.TICKS_PER_DAY)
	assert_eq(world.get_day(), 3, "Tag:")
	assert_eq(_enemy_waves(world), [1, 1, 1, 2, 3, 3] as Array[int], "Wellen:")
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


func test_wave_on_day_one_appears_at_founding() -> void:
	var world := _world_with_waves([{"day": 1, "enemies": {"bandit": 1}, "side": "north"}])
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(_enemy_tiles(world), [Vector2i(2, 0)] as Array[Vector2i], "Kachel:")
