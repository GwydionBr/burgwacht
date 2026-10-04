extends TestCase
## Simulationstests: der Wilderer, ein Fernkampf-Feind. Er schießt auf Soldaten in Reichweite
## (auch auf dem Wehrgang), sonst auf das Hindernis auf seinem Weg, sonst auf den Bergfried, ohne
## heranzulaufen. Leere Karte tiny_siege (20×34); Bergfried (ID 1) bei (2, 2) mit der Grundfläche
## (2..5, 2..5), Warenlager (ID 2) bei (7..9, 2..4), Lagerfeuer bei (3, 8).

const KEEP_ORIGIN := Vector2i(2, 2)
const KEEP := 1
const WAREHOUSE := 2
## Obergrenze für Läufe bis zu einem Ereignis.
const MAX_TICKS := 1500


func _founded(scenario_id := "tiny_siege") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	put_goods(world, WAREHOUSE, "stone", 200)
	return world


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte).
func _until(world: GameWorld, condition: Callable, what: String) -> void:
	for i in MAX_TICKS:
		if condition.call():
			return
		world.step()
	assert_true(false, "%s nach %d Takten nicht eingetreten" % [what, MAX_TICKS])


# --- Daten -------------------------------------------------------------------------------------

func test_poacher_comes_from_data() -> void:
	assert_true(FighterType.is_enemy_type("poacher"), "Feindtyp")
	assert_eq([FighterType.name_of("poacher"), FighterType.max_hp("poacher"), FighterType.damage_of("poacher"),
			FighterType.attack_ticks("poacher"), FighterType.is_melee("poacher"), FighterType.range_of("poacher"),
			FighterType.sight_of("poacher"), FighterType.ticks_per_tile("poacher")],
			["Wilderer", 40, 10, 15, false, 6, 7, 5], "Wilderer:")
	assert_true(FighterType.color_of("poacher") != FighterType.color_of("bandit"), "Eigene Farbe")


## Die Schüsse des Wilderers bis condition() gilt, als [von, nach].
func _shots_until(world: GameWorld, poacher: Enemy, condition: Callable, what: String) -> Array[Array]:
	var shots: Array[Array] = []
	world.shot_fired.connect(func(from: Vector3i, to: Vector3i) -> void:
		if from == poacher.position():
			shots.append([from, to]))
	_until(world, condition, what)
	return shots


# --- Bergfried und Hindernis aus der Entfernung ------------------------------------------------

func test_poacher_shoots_the_keep_from_range_without_walking_up() -> void:
	var world := _founded()
	var poacher := add_enemy(world, "poacher", Vector2i(16, 20))
	var keep := world.get_building(KEEP)
	var shots := _shots_until(world, poacher, func() -> bool: return keep.hp < 1000, "Treffer am Bergfried")
	assert_eq(poacher.target_building_id, KEEP, "Ziel:")
	assert_eq(keep.hp, 1000 - 10, "Schaden:")
	var distance := Combat._distance_to_building(poacher.tile, keep)
	assert_true(distance > 5.0 and distance <= 6.0, "Aus Reichweite 6, nicht daneben: %f" % distance)
	assert_eq(shots.size(), 1, "Ein Pfeil:")
	assert_eq(world.enemy_activity_of(poacher), "Wilderer – greift Bergfried an", "Tätigkeit:")


func test_poacher_shoots_the_obstacle_from_range_without_walking_up() -> void:
	var world := _founded()
	# Geschlossene Mauer bei x = 11 über die ganze Höhe: Von dahinter reicht er nicht zum Bergfried
	# (Abstand mindestens 7), einen Umweg gibt es nicht. Er beginnt 8 Kacheln vor der Mauer.
	assert_eq(world.execute(Command.build_line("wall", Vector2i(11, 0), Vector2i(11, world.map.height - 1))), "",
			"Mauerlinie:")
	var poacher := add_enemy(world, "poacher", Vector2i(19, 4))
	var shots := _shots_until(world, poacher, func() -> bool: return poacher.target_building_id != 0, "Angriff")
	var target := world.get_building(poacher.target_building_id)
	assert_eq([target.type, target.origin.x], ["wall", 11], "Schießt auf die Mauer:")
	assert_eq(target.hp, 300 - 10, "Erster Treffer:")
	var distance := Combat._distance_to_building(poacher.tile, target)
	assert_true(distance > 5.0 and distance <= 6.0, "Aus Reichweite 6, nicht daneben: %f" % distance)
	assert_eq(shots.size(), 1, "Ein Pfeil:")
	assert_eq(world.enemy_activity_of(poacher), "Wilderer – greift Mauer an", "Tätigkeit:")


# --- Soldaten ----------------------------------------------------------------------------------

## Gegründet, mit Waffenkammer und Kaserne unterhalb der Burg und angeworbenen Soldaten dieser
## Typen (IDs 1, 2, …).
func _with_soldiers(types: Array[String]) -> GameWorld:
	var world := _founded()
	var armory := build(world, "armory", Vector2i(2, 12))
	put_goods(world, armory, "sword", 4)
	put_goods(world, armory, "bow", 4)
	var barracks := build(world, "barracks", Vector2i(6, 12))
	for type_id in types:
		assert_eq(world.execute(Command.recruit(barracks, type_id)), "", "Anwerben:")
	return world


## Schickt den Soldaten dorthin und wartet, bis er steht.
func _place(world: GameWorld, id: int, target: Vector3i) -> void:
	assert_eq(world.execute(Command.move([id] as Array[int], target)), "", "Bewegen:")
	_until(world, func() -> bool: return world.get_resident(id).position() == target, "Ankunft")


## Dort steht der Soldat oben auf dem Mauerstück (_soldier_on_wall()).
const ARCHER_SPOT := Vector3i(11, 6, Figure.Level.WALL_WALK)


## Kurzes Mauerstück bei x = 11 (y 4..8); ein Soldat dieses Typs (ID 1) steigt über eine Treppe
## bei (10, 8) hinauf nach ARCHER_SPOT, dann wird die Treppe abgerissen: Kein Feind erreicht ihn.
func _soldier_on_wall(type_id: String) -> GameWorld:
	var world := _with_soldiers([type_id] as Array[String])
	assert_eq(world.execute(Command.build_line("wall", Vector2i(11, 4), Vector2i(11, 8))), "", "Mauer:")
	var stairs := build(world, "stairs", Vector2i(10, 8))
	_place(world, 1, ARCHER_SPOT)
	assert_eq(world.execute(Command.demolish(stairs)), "", "Treppe abreißen:")
	return world


func test_poacher_shoots_an_archer_on_the_wall_walk() -> void:
	var world := _soldier_on_wall("archer")
	var archer := world.get_resident(1)
	# Der Bogenschütze (Reichweite 7 + 2 auf dem Wehrgang) schießt zuerst, der Wilderer (40 LP)
	# kommt aber auf 6 Kacheln heran, bevor er fällt.
	var poacher := add_enemy(world, "poacher", Vector2i(19, 6))
	var shots := _shots_until(world, poacher, func() -> bool: return archer.hp < 50, "Treffer am Bogenschützen")
	assert_eq(poacher.target_id, 1, "Ziel des Wilderers:")
	assert_eq(archer.hp, 50 - 10, "Schaden:")
	assert_eq(shots, [[poacher.position(), ARCHER_SPOT]] as Array[Array], "Pfeil auf den Wehrgang:")
	assert_true(poacher.distance_to(archer) <= 6.0 + Figure.DISTANCE_SLACK, "Aus Reichweite: %f" % poacher.distance_to(archer))
	assert_eq(poacher.level, Figure.Level.GROUND, "Bleibt unten:")
	assert_eq(world.enemy_activity_of(poacher), "Wilderer – greift Bogenschütze an", "Tätigkeit:")


func test_swordsman_hunts_down_the_poacher_like_any_enemy() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	var post := Figure.ground(Vector2i(13, 6))
	_place(world, 1, post)
	var swordsman := world.get_resident(1)
	var poacher := add_enemy(world, "poacher", Vector2i(19, 6))
	_until(world, func() -> bool: return swordsman.target_id == poacher.id, "Schwertkämpfer greift an")
	assert_true(swordsman.defending, "Verteidigt sich selbstständig")
	_until(world, func() -> bool: return world.get_enemy(poacher.id) == null, "Tod des Wilderers")
	assert_true(swordsman.hp < 100, "Der Wilderer hat zurückgeschossen: %d" % swordsman.hp)
	_until(world, func() -> bool: return swordsman.position() == post, "Zurück auf dem Posten")


func test_save_and_load_while_shooting_at_the_wall_walk_continues_the_same() -> void:
	var world := _soldier_on_wall("archer")
	var archer := world.get_resident(1)
	add_enemy(world, "poacher", Vector2i(19, 6))
	_until(world, func() -> bool: return archer.hp < 50, "Treffer am Bogenschützen")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	for i in 200:
		world.step()
		loaded.step()
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Gleicher Verlauf:")
	assert_eq(loaded.to_data(), world.to_data(), "Gleiche Daten:")


func test_unarmed_residents_are_never_a_target() -> void:
	var world := _founded()
	# Die Startbewohner stehen untätig am Lagerfeuer (3, 8); Räuber und Wilderer kommen dicht vorbei
	# und greifen den Bergfried an.
	var bandit := add_enemy(world, "bandit", Vector2i(6, 10))
	var poacher := add_enemy(world, "poacher", Vector2i(7, 11))
	var hp_before: Array[int] = []
	for resident in world.get_residents():
		hp_before.append(resident.hp)
	assert_true(not hp_before.is_empty(), "Bewohner da")
	var hit_tiles: Array[Vector2i] = []
	world.shot_fired.connect(func(_from: Vector3i, to: Vector3i) -> void: hit_tiles.append(Vector2i(to.x, to.y)))
	for i in 300:
		world.step()
		assert_true(bandit.target_id == 0 and poacher.target_id == 0, "Kein Bewohner als Ziel (Takt %d)" % i)
	var hp_after: Array[int] = []
	for resident in world.get_residents():
		hp_after.append(resident.hp)
	assert_eq(hp_after, hp_before, "Alle Bewohner leben unverletzt:")
	assert_eq([bandit.target_building_id, poacher.target_building_id], [KEEP, KEEP], "Greifen den Bergfried an:")
	for tile in hit_tiles:
		assert_true(world.get_building_at(tile) == world.get_building(KEEP), "Pfeil nur auf den Bergfried: %s" % tile)


# --- Wellenplan, Startfeinde und freies Spiel --------------------------------------------------

## Typ und Welle jedes Feinds, nach ID, als „Typ/Welle“.
func _enemy_types(world: GameWorld) -> Array[String]:
	var result: Array[String] = []
	for enemy in world.get_enemies():
		result.append("%s/%d" % [enemy.type, enemy.wave])
	return result


func test_poacher_comes_in_a_wave_and_as_start_enemy() -> void:
	var scenario := Scenario.from_dict("test_poacher", {
		"name": "Test", "map": {"width": 20, "height": 16}, "seed": 7,
		"enemies": [{"type": "poacher", "tile": [16, 13]}],
		"waves": {"list": [{"day": 2, "enemies": {"bandit": 1, "poacher": 2}, "side": "east"}]}})
	assert_eq(scenario.error, "", "Szenario:")
	var world := clear_map(GameWorld.create(scenario, 7))
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(_enemy_types(world), ["poacher/0"] as Array[String], "Startfeind:")
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	assert_eq(_enemy_types(world), ["poacher/0", "bandit/1", "poacher/1", "poacher/1"] as Array[String],
			"Mit Welle 1:")


func test_free_play_brings_poachers_from_the_third_formula_wave() -> void:
	var plan := Scenario.load_named(Scenario.DEFAULT).wave_plan
	var poachers: Array[int] = []
	var bandits: Array[int] = []
	for number in range(1, 7):
		var wave := plan.wave(number)
		poachers.append(wave.enemies.get("poacher", 0))
		bandits.append(wave.enemies.get("bandit", 0))
	# Abgerundet 0,5 × n mit n ab 0.
	assert_eq(poachers, [0, 0, 1, 1, 2, 2] as Array[int], "Wilderer je Welle:")
	assert_eq(bandits, [3, 4, 5, 6, 7, 8] as Array[int], "Räuber je Welle:")
