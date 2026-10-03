extends TestCase
## Simulationstests: Räuber (Feind) und Kampf. Leere Karte (nur Wiese) 20×16, tiny_production
## bzw. tiny_bandits (dazu ein Räuber bei (16, 13)); Bergfried (ID 1) bei (2, 2) mit der
## Grundfläche (2..5, 2..5), Lagerfeuer bei (3, 8); Waffenkammer und Kaserne wie in test_barracks,
## Posten des ersten Soldaten vor der Kaserne bei (15, 5).

const KEEP_ORIGIN := Vector2i(2, 2)
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
## Rand nächst dem Bergfried: Abstand 2 zur Grundfläche, zeilenweise die erste solche Kachel.
const SPAWN_TILE := Vector2i(2, 0)
## Dort steht der Räuber von SPAWN_TILE aus am Bergfried.
const KEEP_SPOT := Vector2i(2, 1)
const BANDIT_START := Vector2i(16, 13)
## Obergrenze für Läufe bis zu einem Ereignis.
const MAX_TICKS := 1500


func _founded(scenario_id := "tiny_production") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Gegründet, mit Waffenkammer, Kaserne und angeworbenen Soldaten dieser Typen (IDs 1, 2, …).
func _with_soldiers(types: Array[String], scenario_id := "tiny_production") -> GameWorld:
	var world := _founded(scenario_id)
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", 4)
	put_goods(world, armory, "bow", 4)
	var barracks := build(world, "barracks", BARRACKS_SITE)
	for type_id in types:
		assert_eq(world.execute(Command.recruit(barracks, type_id)), "", "Anwerben:")
	return world


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte).
func _until(world: GameWorld, condition: Callable, what: String) -> void:
	for i in MAX_TICKS:
		if condition.call():
			return
		world.step()
	assert_true(false, "%s nach %d Takten nicht eingetreten" % [what, MAX_TICKS])


func _until_still(world: GameWorld, figure: Figure) -> void:
	_until(world, func() -> bool: return not figure.is_moving(), "Stehen")


## Abstand einer Kachel zur Grundfläche des Bergfrieds (0 auf ihr).
func _keep_distance(tile: Vector2i) -> float:
	var nearest := tile.clamp(KEEP_ORIGIN, KEEP_ORIGIN + Vector2i(3, 3))
	return Vector2(tile - nearest).length()


func test_bandit_comes_from_data() -> void:
	assert_eq(FighterType.enemy_ids(), ["bandit"] as Array[String], "Feindtypen:")
	assert_true(not SoldierType.is_soldier_type("bandit"), "Kein Soldatentyp")
	assert_eq([FighterType.name_of("bandit"), FighterType.max_hp("bandit"), FighterType.damage_of("bandit"),
			FighterType.attack_ticks("bandit"), FighterType.is_melee("bandit"), FighterType.sight_of("bandit"),
			FighterType.ticks_per_tile("bandit")],
			["Räuber", 80, 12, 10, true, 6, 6], "Räuber:")


func test_scenario_bandits_appear_at_founding_and_are_no_residents() -> void:
	var world := empty_world("tiny_bandits")
	assert_eq(world.get_enemies().size(), 0, "Vor der Gründung:")
	var added: Array[int] = []
	world.enemy_added.connect(func(id: int) -> void: added.append(id))
	world.execute(Command.found(KEEP_ORIGIN))
	assert_eq(added, [1] as Array[int], "Gemeldet:")
	var bandit := world.get_enemy(1)
	assert_eq([bandit.type, bandit.tile, bandit.hp], ["bandit", BANDIT_START, 80], "Räuber:")
	assert_eq(world.get_population(), 4, "Bewohner:")
	assert_eq(world.get_residents().size(), 4, "Keiner der Bewohner:")
	assert_eq(world.get_enemies_at(BANDIT_START), [bandit] as Array[Enemy], "Auf der Kachel:")


func test_bandit_walks_to_the_keep_and_waits_there() -> void:
	var world := _founded("tiny_bandits")
	var bandit := world.get_enemy(1)
	assert_true(bandit.is_moving(), "Läuft los")
	assert_eq(world.enemy_activity_of(bandit), "Räuber – läuft zum Bergfried", "Unterwegs:")
	_until_still(world, bandit)
	assert_eq(_keep_distance(bandit.tile), 1.0, "Am Bergfried:")
	assert_eq(world.enemy_activity_of(bandit), "Räuber – wartet", "Steht:")
	for i in 100:
		world.step()
	assert_true(not bandit.is_moving(), "Bleibt stehen")
	# Bewohner greift er nicht an.
	assert_eq(world.get_population(), 4, "Bewohner:")


func test_blocked_bandit_waits_nearest_to_the_keep_and_replans_after_demolish() -> void:
	var world := empty_world("tiny_bandits")
	# Felsen um (14..16, 11..13); die Lücke links oben schließt ein Wohnhaus bei (12, 10).
	for x in range(13, 18):
		for y in range(10, 15):
			var border := x == 13 or x == 17 or y == 10 or y == 14
			if border and not (x == 13 and y in [10, 11]):
				add_deposit(world, Vector2i(x, y), "stone")
	world.execute(Command.found(KEEP_ORIGIN))
	var bandit := world.get_enemy(1)
	var house := build(world, "house", Vector2i(12, 10))
	_until_still(world, bandit)
	assert_eq(bandit.tile, Vector2i(14, 11), "Nächste erreichbare Kachel am Bergfried:")
	assert_eq(world.execute(Command.demolish(house)), "", "Abriss:")
	assert_true(bandit.is_moving(), "Plant neu")
	_until_still(world, bandit)
	assert_eq(_keep_distance(bandit.tile), 1.0, "Am Bergfried:")


func test_building_over_the_waiting_bandit_makes_him_replan() -> void:
	var world := _founded()
	world.execute(Command.spawn_enemy("bandit"))
	var bandit := world.get_enemy(1)
	_until_still(world, bandit)
	assert_eq(bandit.tile, KEEP_SPOT, "Wartet am Bergfried:")
	# Wohnhaus (2×2) über ihm; der Eingang (1, 1) ist begehbar, aber nicht am Bergfried.
	var house := build(world, "house", KEEP_SPOT - Vector2i(1, 1))
	assert_true(world.get_building_at(bandit.tile) != world.get_building(house) or bandit.tile == Vector2i(1, 1),
			"Weicht aus")
	_until_still(world, bandit)
	assert_true(world.get_building_at(bandit.tile) == null, "Nicht im Wohnhaus: %s" % bandit.tile)
	assert_eq(_keep_distance(bandit.tile), 1.0, "Wieder am Bergfried:")


func test_spawn_command_puts_bandit_on_the_edge_nearest_the_keep() -> void:
	var world := _founded()
	assert_eq(world.execute(Command.spawn_enemy("bandit")), "", "Erscheinen:")
	var bandit := world.get_enemy(1)
	assert_eq(bandit.tile, SPAWN_TILE, "Rand:")
	_until_still(world, bandit)
	assert_eq(bandit.tile, KEEP_SPOT, "Am Bergfried:")


func test_spawn_reasons() -> void:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.spawn_enemy("bandit")), GameWorld.FOUNDING_FIRST, "Gründung:")
	world.execute(Command.found(KEEP_ORIGIN))
	assert_eq(world.execute(Command.spawn_enemy("swordsman")), "Unbekannter Feind „swordsman“", "Soldatentyp:")
	assert_eq(world.get_enemies().size(), 0, "Keiner erschienen:")


func test_attack_reasons() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	world.execute(Command.spawn_enemy("bandit"))
	assert_eq(world.execute(Command.attack([] as Array[int], 1)), "Keine Soldaten ausgewählt", "Leer:")
	assert_eq(world.execute(Command.attack([2] as Array[int], 1)), "Kein Soldat", "Untätiger:")
	assert_eq(world.execute(Command.attack([1] as Array[int], 7)), "Kein Feind", "Unbekannter Feind:")
	var before := world.to_data()
	world.execute(Command.attack([1, 2] as Array[int], 1))
	assert_eq(world.to_data(), before, "Abgelehnt ändert nichts:")


func test_swordsman_hunts_down_the_bandit_every_attack_duration() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	world.execute(Command.spawn_enemy("bandit"))
	var bandit := world.get_enemy(1)
	var soldier := world.get_resident(1)
	_until_still(world, bandit)
	assert_eq(world.execute(Command.attack([1] as Array[int], 1)), "", "Angreifen:")
	assert_eq(soldier.target_id, 1, "Ziel:")
	_until(world, func() -> bool: return bandit.hp < 80, "Erster Treffer")
	assert_eq(bandit.hp, 60, "Schaden:")
	assert_true(maxi(absi(soldier.tile.x - bandit.tile.x), absi(soldier.tile.y - bandit.tile.y)) <= 1, "Nebeneinander")
	assert_eq(world.activity_of(soldier), "Schwertkämpfer – greift Räuber an", "Tätigkeit:")
	var hits: Array[int] = []
	var removed: Array[int] = []
	world.enemy_removed.connect(func(id: int) -> void: removed.append(id))
	for i in 60:
		var hp := bandit.hp
		world.step()
		if world.get_enemy(1) == null or bandit.hp != hp:
			hits.append(world.get_tick())
		if world.get_enemy(1) == null:
			break
	assert_eq(hits.size(), 3, "Noch drei Treffer:")
	assert_eq([hits[1] - hits[0], hits[2] - hits[1]], [10, 10], "Abstand der Treffer:")
	assert_eq(removed, [1] as Array[int], "Räuber verschwindet:")
	assert_eq(world.get_enemies().size(), 0, "Keine Feinde:")
	# Der Räuber hat zurückgeschlagen; ohne Ziel bleibt der Soldat, wo er ist.
	assert_true(soldier.hp < 100 and soldier.hp > 0, "Verletzt: %d" % soldier.hp)
	assert_eq(soldier.target_id, 0, "Kein Ziel mehr:")
	_until_still(world, soldier)
	assert_eq(soldier.post, soldier.position(), "Posten = aktuelle Position:")
	assert_eq(world.activity_of(soldier), "Schwertkämpfer – auf Posten", "Tätigkeit:")


func test_bandit_kills_a_soldier_in_sight() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	var soldier := world.get_resident(1)
	world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(7, 0))))
	_until_still(world, soldier)
	var removed: Array[int] = []
	world.resident_removed.connect(func(id: int) -> void: removed.append(id))
	world.execute(Command.spawn_enemy("bandit"))
	var bandit := world.get_enemy(1)
	_until(world, func() -> bool: return soldier.hp < 100, "Erster Treffer")
	assert_eq(bandit.target_id, 1, "Ziel des Räubers:")
	assert_eq(soldier.hp, 88, "Schaden:")
	assert_eq(world.enemy_activity_of(bandit), "Räuber – greift Schwertkämpfer an", "Tätigkeit:")
	var population := world.get_population()
	while world.get_resident(1) != null and world.get_tick() < MAX_TICKS:
		population = world.get_population()
		world.step()
	assert_true(removed.has(1), "Tod gemeldet")
	assert_eq([world.get_population(), world.get_soldier_count()], [population - 1, 0], "Bewohner und Soldaten:")
	assert_eq(bandit.target_id, 0, "Räuber ohne Ziel:")
	_until_still(world, bandit)
	assert_eq(_keep_distance(bandit.tile), 1.0, "Weiter zum Bergfried:")


## Zwei Schwertkämpfer (IDs 1 und 2) stehen auf diesen Kacheln, dann erscheint ein Räuber bei
## SPAWN_TILE; liefert die ID seines ersten Ziels.
func _first_bandit_target(first: Vector2i, second: Vector2i) -> int:
	var world := _with_soldiers(["swordsman", "swordsman"] as Array[String])
	world.execute(Command.move([1] as Array[int], Figure.ground(first)))
	world.execute(Command.move([2] as Array[int], Figure.ground(second)))
	_until_still(world, world.get_resident(1))
	_until_still(world, world.get_resident(2))
	world.execute(Command.spawn_enemy("bandit"))
	world.step()
	return world.get_enemy(1).target_id


func test_bandit_attacks_the_nearest_soldier() -> void:
	# Abstand von SPAWN_TILE (2, 0): 5 bzw. 4.
	assert_eq(_first_bandit_target(Vector2i(7, 0), Vector2i(6, 0)), 2, "Der nähere, trotz größerer ID:")


func test_bandit_breaks_ties_by_smaller_id() -> void:
	# Abstand von SPAWN_TILE (2, 0): beide 5.
	assert_eq(_first_bandit_target(Vector2i(6, 3), Vector2i(7, 0)), 1, "Gleichstand:")
	assert_eq(_first_bandit_target(Vector2i(7, 0), Vector2i(6, 3)), 1, "Gleichstand, vertauscht:")


func test_bandit_ignores_soldiers_out_of_sight() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	_until_still(world, world.get_resident(1))
	world.execute(Command.spawn_enemy("bandit"))
	var bandit := world.get_enemy(1)
	for i in 300:
		world.step()
	assert_eq([bandit.target_id, world.get_resident(1).hp], [0, 100], "Soldat an der Kaserne zu weit weg:")


func test_archer_shoots_from_range() -> void:
	var world := _with_soldiers(["archer"] as Array[String])
	world.execute(Command.spawn_enemy("bandit"))
	var bandit := world.get_enemy(1)
	var archer := world.get_resident(1)
	_until_still(world, bandit)
	var shots: Array[Array] = []
	world.shot_fired.connect(func(from: Vector3i, to: Vector3i) -> void: shots.append([from, to]))
	world.execute(Command.attack([1] as Array[int], 1))
	_until(world, func() -> bool: return world.get_enemy(1) == null, "Tod des Räubers")
	assert_eq(shots.size(), 8, "Pfeile (80 / 10):")
	var shot: Array = shots[0]
	var distance := Vector2(shot[0].x - shot[1].x, shot[0].y - shot[1].y).length()
	assert_true(distance <= 7.0 and distance > 6.0, "Schuss aus Reichweite, außer Sicht des Räubers: %f" % distance)
	assert_eq(archer.hp, 50, "Unverletzt:")


func test_move_cancels_the_attack() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	world.execute(Command.spawn_enemy("bandit"))
	world.execute(Command.attack([1] as Array[int], 1))
	world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(15, 12))))
	assert_eq(world.get_resident(1).target_id, 0, "Kein Ziel mehr:")


func test_save_and_load_mid_fight_continues_the_same() -> void:
	var world := _with_soldiers(["swordsman", "archer"] as Array[String])
	world.execute(Command.spawn_enemy("bandit"))
	world.execute(Command.attack([1, 2] as Array[int], 1))
	var bandit := world.get_enemy(1)
	_until(world, func() -> bool: return bandit.hp < 80, "Erster Treffer")
	world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in 300:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
	assert_eq(world.get_enemies().size(), 0, "Räuber besiegt:")


func test_save_and_load_keeps_scenario_bandits_before_founding() -> void:
	var world := empty_world("tiny_bandits")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	loaded.execute(Command.found(KEEP_ORIGIN))
	assert_eq(loaded.get_enemies().size(), 1, "Räuber nach der Gründung:")
