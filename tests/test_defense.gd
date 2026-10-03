extends TestCase
## Simulationstests: Selbstständiges Verteidigen und Vorteile des Wehrgangs. Leere Karte (nur
## Wiese, 20×16), tiny_production mit 100 Stein; Bergfried (ID 1) bei (2, 2) mit der Grundfläche
## (2..5, 2..5), Warenlager (7..9, 2..4), Kornspeicher (7..9, 6..8), Lagerfeuer bei (3, 8),
## Waffenkammer (10..12, 10..12) und Kaserne (14..16, 2..4) wie in test_combat.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const WALL_WALK := Resident.Level.WALL_WALK
## Dort wartet ein Räuber vom Rand (2, 0) aus am Bergfried.
const KEEP_SPOT := Vector2i(2, 1)
## Ring um den Bergfried: Mauer bei x = 6 (y 0..7) und y = 7 (x 0..6); der Kartenrand schließt ihn.
const RING_X := 6
const RING_Y := 7
## Obergrenze für Läufe bis zu einem Ereignis.
const MAX_TICKS := 1500


## Gegründet, mit Waffenkammer, Kaserne und angeworbenen Soldaten dieser Typen (IDs 1, 2, …).
func _with_soldiers(types: Array[String]) -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	put_goods(world, WAREHOUSE, "stone", 100)
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", 4)
	put_goods(world, armory, "bow", 4)
	var barracks := build(world, "barracks", BARRACKS_SITE)
	for type_id in types:
		assert_eq(world.execute(Command.recruit(barracks, type_id)), "", "Anwerben:")
	return world


func _wall(world: GameWorld, from: Vector2i, to: Vector2i) -> void:
	assert_eq(world.execute(Command.build_line("wall", from, to)), "", "Mauerlinie:")


func _on_wall(tile: Vector2i) -> Vector3i:
	return Vector3i(tile.x, tile.y, WALL_WALK)


## Schickt den Soldaten dorthin und wartet, bis er steht.
func _place(world: GameWorld, id: int, target: Vector3i) -> void:
	assert_eq(world.execute(Command.move([id] as Array[int], target)), "", "Bewegen:")
	_until(world, func() -> bool: return world.get_resident(id).position() == target, "Ankunft")


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte).
func _until(world: GameWorld, condition: Callable, what: String) -> void:
	for i in MAX_TICKS:
		if condition.call():
			return
		world.step()
	assert_true(false, "%s nach %d Takten nicht eingetreten" % [what, MAX_TICKS])


func _run(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


## Abstand einer Kachel zur Grundfläche des Bergfrieds (0 auf ihr).
func _keep_distance(tile: Vector2i) -> float:
	var nearest := tile.clamp(KEEP_ORIGIN, KEEP_ORIGIN + Vector2i(3, 3))
	return Vector2(tile - nearest).length()


func _inside_ring(tile: Vector2i) -> bool:
	return tile.x < RING_X and tile.y < RING_Y


# --- Daten -------------------------------------------------------------------------------------

func test_range_bonus_and_leash_come_from_data() -> void:
	assert_eq(FighterType.wall_walk_range_bonus("archer"), 2, "Bonus des Bogenschützen auf dem Wehrgang:")
	assert_eq(FighterType.wall_walk_range_bonus("swordsman"), 0, "Schwertkämpfer ohne Bonus:")
	assert_eq(FighterType.leash_of("swordsman"), 8, "Leine des Schwertkämpfers:")


# --- Bogenschützen -----------------------------------------------------------------------------

## Mauer (10..11, 0) mit Treppe bei (10, 1), daran der Turm (12..13, 0..1, Eingang (12, 1)); ein
## Bogenschütze (ID 1) steht auf position. Dann erscheint ein Räuber am Rand (2, 0) und wartet bei
## KEEP_SPOT, außer Sicht des Bogenschützen. Liefert die Weite jedes Schusses in ticks Takten.
func _shots_at_bandit_from(position: Vector3i, ticks := 200) -> Array[float]:
	var world := _with_soldiers(["archer"] as Array[String])
	_wall(world, Vector2i(10, 0), Vector2i(11, 0))
	build(world, "stairs", Vector2i(10, 1))
	build(world, "tower", Vector2i(12, 0))
	_place(world, 1, position)
	var shots: Array[float] = []
	world.shot_fired.connect(func(from: Vector3i, to: Vector3i) -> void:
		assert_eq(from, position, "Schießt von seinem Platz aus:")
		shots.append(Vector2(from.x - to.x, from.y - to.y).length()))
	assert_eq(world.execute(Command.spawn_enemy("bandit")), "", "Erscheinen:")
	_run(world, ticks)
	var archer := world.get_resident(1)
	assert_eq(archer.position(), position, "Bleibt stehen:")
	assert_eq(archer.post, position, "Posten unverändert:")
	return shots


func test_archer_shoots_the_nearest_enemy_in_range_without_order() -> void:
	# (9, 1) – (2, 1): Abstand 7 = Reichweite.
	var shots := _shots_at_bandit_from(Figure.ground(Vector2i(9, 1)))
	assert_true(not shots.is_empty(), "Schießt ohne Befehl")
	assert_true(shots.max() <= 7.0, "Höchstens Reichweite 7: %s" % str(shots))
	# (10, 2): Abstand 8,06 bzw. 8,25 vom Rand aus.
	assert_eq(_shots_at_bandit_from(Figure.ground(Vector2i(10, 2))), [] as Array[float], "Außer Reichweite:")


func test_archer_on_the_wall_walk_gets_extra_range() -> void:
	# (10, 0) – (2, 1): Abstand 8,06 ≤ 7 + 2.
	var shots := _shots_at_bandit_from(_on_wall(Vector2i(10, 0)))
	assert_true(not shots.is_empty() and shots.max() > 7.0, "Auf der Mauer weiter: %s" % str(shots))
	# (11, 0): nur auf den Räuber am Rand (2, 0), Abstand 9; bei (2, 1) ist er 9,06 entfernt.
	shots = _shots_at_bandit_from(_on_wall(Vector2i(11, 0)))
	assert_true(shots.max() <= 9.0, "Höchstens 7 + 2: %s" % str(shots))


func test_archer_on_a_tower_gets_the_tower_bonus_too() -> void:
	# (13, 0) – (2, 1): Abstand 11,05 ≤ 7 + 2 + 3.
	var shots := _shots_at_bandit_from(_on_wall(Vector2i(13, 0)))
	assert_true(not shots.is_empty() and shots.max() > 9.0, "Auf dem Turm weiter: %s" % str(shots))
	assert_true(shots.max() <= 12.0, "Höchstens 7 + 2 + 3: %s" % str(shots))


func test_archer_fires_every_attack_duration_and_kills_the_bandit() -> void:
	var world := _with_soldiers(["archer"] as Array[String])
	_place(world, 1, Figure.ground(Vector2i(9, 1)))
	var ticks: Array[int] = []
	world.shot_fired.connect(func(_from: Vector3i, _to: Vector3i) -> void: ticks.append(world.get_tick()))
	world.execute(Command.spawn_enemy("bandit"))
	_until(world, func() -> bool: return world.get_enemy(1) == null, "Tod des Räubers")
	assert_eq(ticks.size(), 8, "Pfeile (80 / 10):")
	assert_eq(ticks[1] - ticks[0], 15, "Abstand der Schüsse:")
	var archer := world.get_resident(1)
	assert_eq([archer.target_id, archer.defending], [0, false], "Kein Ziel mehr:")
	assert_eq(archer.position(), Figure.ground(Vector2i(9, 1)), "Steht noch da:")
	assert_eq(world.activity_of(archer), "Bogenschütze – auf Posten", "Tätigkeit:")


# --- Schwertkämpfer ----------------------------------------------------------------------------

func test_swordsman_attacks_an_enemy_in_sight_and_returns_to_his_post() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	var post := Figure.ground(Vector2i(15, 8))
	_place(world, 1, post)
	var soldier := world.get_resident(1)
	# (15, 13): Abstand 5 – beide sehen sich.
	var bandit := add_enemy(world, "bandit", Vector2i(15, 13))
	world.step()
	assert_eq([soldier.target_id, soldier.defending], [bandit.id, true], "Verteidigt sich:")
	assert_eq(world.activity_of(soldier), "Schwertkämpfer – verfolgt Räuber", "Tätigkeit:")
	_until(world, func() -> bool: return world.get_enemy(bandit.id) == null, "Tod des Räubers")
	assert_eq(soldier.post, post, "Posten unverändert:")
	_until(world, func() -> bool: return soldier.position() == post and not soldier.is_moving(), "Zurück am Posten")
	assert_eq([soldier.target_id, soldier.defending], [0, false], "Kein Ziel mehr:")


func test_swordsman_ignores_enemies_out_of_sight() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	_place(world, 1, Figure.ground(Vector2i(15, 8)))
	# (15, 15): Abstand 7 > Sichtweite 6. Der Räuber läuft zum Bergfried, vom Soldaten weg.
	add_enemy(world, "bandit", Vector2i(15, 15))
	world.step()
	assert_eq(world.get_resident(1).target_id, 0, "Kein Ziel:")


## Zwei Schwertkämpfer: Nr. 1 auf seinem Posten (5, 14), Nr. 2 bei (8, 14). Ein Räuber erscheint
## bei (8, 9) und sieht beide; Nr. 2 läuft sofort nach rechts zum Kartenrand (19, 14) davon, der
## Räuber verfolgt ihn (der nähere). Mit attack greift Nr. 1 auf Befehl an, sonst verteidigt er
## sich selbst. Liefert den größten Abstand von Nr. 1 zu seinem Posten, solange der Räuber lebt.
func _chase_distance(attack: bool) -> float:
	var world := _with_soldiers(["swordsman", "swordsman"] as Array[String])
	var post := Figure.ground(Vector2i(5, 14))
	_place(world, 1, post)
	_place(world, 2, Figure.ground(Vector2i(8, 14)))
	var bandit := add_enemy(world, "bandit", Vector2i(8, 9))
	assert_eq(world.execute(Command.move([2] as Array[int], Figure.ground(Vector2i(19, 14)))), "", "Flucht:")
	if attack:
		assert_eq(world.execute(Command.attack([1] as Array[int], bandit.id)), "", "Angreifen:")
	var soldier := world.get_resident(1)
	var farthest := 0.0
	var chased := false
	for i in 400:
		world.step()
		if world.get_enemy(bandit.id) == null:
			break
		assert_eq(bandit.target_id, 2, "Der Räuber verfolgt Nr. 2:")
		chased = chased or soldier.target_id == bandit.id
		farthest = maxf(farthest, Vector2(soldier.tile - soldier.post_tile()).length())
	assert_true(chased, "Nr. 1 verfolgt den Räuber")
	if not attack:
		assert_eq(soldier.post, post, "Posten unverändert:")
		_until(world, func() -> bool: return soldier.position() == post, "Zurück am Posten")
		assert_eq(soldier.target_id, 0, "Gibt auf:")
	return farthest


func test_defending_swordsman_follows_only_up_to_the_leash() -> void:
	var farthest := _chase_distance(false)
	assert_true(farthest <= 8.0, "Höchstens 8 Kacheln vom Posten: %f" % farthest)
	assert_true(farthest >= 7.0, "Verfolgt bis zur Leine: %f" % farthest)


func test_ordered_attack_has_no_leash() -> void:
	var farthest := _chase_distance(true)
	assert_true(farthest > 8.0, "Über die Leine hinaus: %f" % farthest)


func test_ordered_attack_takes_priority_over_defending() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	_place(world, 1, Figure.ground(Vector2i(15, 8)))
	var near := add_enemy(world, "bandit", Vector2i(15, 12))
	var far := add_enemy(world, "bandit", Vector2i(12, 15))
	world.step()
	var soldier := world.get_resident(1)
	assert_eq(soldier.target_id, near.id, "Verteidigt sich gegen den näheren:")
	assert_eq(world.execute(Command.attack([1] as Array[int], far.id)), "", "Angreifen:")
	assert_eq([soldier.target_id, soldier.defending], [far.id, false], "Befehl geht vor:")
	_run(world, 20)
	assert_eq(soldier.target_id, far.id, "Bleibt beim befohlenen Ziel:")


# --- Ebenen ------------------------------------------------------------------------------------

## Ring um den Bergfried: Mauer bei x = RING_X (y 0..7) und y = RING_Y (x 0..5). Ohne Tor, Treppe
## und Turm ist der Bergfried vom Rest der Karte abgeschnitten.
func _ring(world: GameWorld) -> void:
	_wall(world, Vector2i(RING_X, 0), Vector2i(RING_X, RING_Y))
	_wall(world, Vector2i(0, RING_Y), Vector2i(RING_X - 1, RING_Y))


## Ein Räuber erscheint bei (15, 13) und läuft, bis er steht; liefert alle betretenen Positionen.
func _bandit_route(world: GameWorld) -> Array[Vector3i]:
	var bandit := add_enemy(world, "bandit", Vector2i(15, 13))
	var visited: Array[Vector3i] = [bandit.position()]
	for i in MAX_TICKS:
		world.step()
		if visited.back() != bandit.position():
			visited.append(bandit.position())
		if not bandit.is_moving():
			return visited
	assert_true(false, "Räuber steht nach %d Takten nicht" % MAX_TICKS)
	return visited


func test_enemies_do_not_pass_through_a_gate() -> void:
	var world := _with_soldiers([] as Array[String])
	_ring(world)
	var gate := Vector2i(RING_X, 1)
	assert_eq(world.execute(Command.demolish(world.get_building_at(gate).id)), "", "Abriss:")
	build(world, "gate", gate)
	var visited := _bandit_route(world)
	for position in visited:
		assert_true(not _inside_ring(Vector2i(position.x, position.y)) and position.z == Figure.Level.GROUND,
				"Draußen am Boden: %s" % str(visited))
	assert_true(not visited.has(Figure.ground(gate)), "Nicht durchs Tor")


func test_enemies_climb_over_the_wall_by_stairs() -> void:
	var world := _with_soldiers([] as Array[String])
	_ring(world)
	build(world, "stairs", Vector2i(RING_X + 1, 0))
	build(world, "stairs", Vector2i(RING_X - 1, 0))
	var visited := _bandit_route(world)
	assert_true(visited.has(_on_wall(Vector2i(RING_X, 0))), "Über den Wehrgang: %s" % str(visited))
	var last: Vector3i = visited.back()
	assert_eq(last.z, Figure.Level.GROUND, "Unten:")
	assert_eq(_keep_distance(Vector2i(last.x, last.y)), 1.0, "Am Bergfried:")


func test_enemies_do_not_use_a_tower_entrance() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	# Der Turm (5..6, 6..7) schließt die Ecke des Rings; sein Eingang (5, 7) zeigt nach draußen.
	_wall(world, Vector2i(RING_X, 0), Vector2i(RING_X, 5))
	_wall(world, Vector2i(0, RING_Y), Vector2i(4, RING_Y))
	build(world, "tower", Vector2i(5, 6))
	build(world, "stairs", Vector2i(RING_X - 1, 0))
	# Ein Soldat kommt so hinein: Eingang hinauf, Wehrgang, Treppe hinab.
	assert_eq(world.move_error([1] as Array[int], Figure.ground(Vector2i(5, 1))), "", "Soldat kommt hinein:")
	var visited := _bandit_route(world)
	for position in visited:
		assert_true(not _inside_ring(Vector2i(position.x, position.y)) and position.z == Figure.Level.GROUND,
				"Draußen am Boden: %s" % str(visited))
	assert_true(not visited.has(Figure.ground(Vector2i(5, 7))), "Nicht auf den Eingang")


func test_bandit_on_a_demolished_wall_steps_down_and_walks_on() -> void:
	var world := _with_soldiers([] as Array[String])
	_ring(world)
	build(world, "stairs", Vector2i(RING_X + 1, 0))
	build(world, "stairs", Vector2i(RING_X - 1, 0))
	var bandit := add_enemy(world, "bandit", Vector2i(15, 13))
	_until(world, func() -> bool: return bandit.level == WALL_WALK and bandit.step_progress == 0, "Räuber oben")
	var tile := bandit.tile
	assert_eq(world.execute(Command.demolish(world.get_building_at(tile).id)), "", "Abriss:")
	assert_eq(bandit.level, Figure.Level.GROUND, "Am Boden:")
	assert_true(world.get_building_at(bandit.tile) == null or world.get_building_at(bandit.tile).is_stairs(),
			"Auf freiem Boden: %s" % str(bandit.tile))
	_until(world, func() -> bool: return not bandit.is_moving(), "Räuber steht")
	assert_eq(_keep_distance(bandit.tile), 1.0, "Durch die Lücke zum Bergfried:")


## Ring mit Treppe innen bei (5, 0); ein Soldat dieses Typs (ID 1) steht oben auf der Mauer bei
## (6, 4). Mit stairs_outside führt eine zweite Treppe bei (7, 0) von draußen hinauf.
func _soldier_on_ring(type_id: String, stairs_outside: bool) -> GameWorld:
	var world := _with_soldiers([type_id] as Array[String])
	_ring(world)
	build(world, "stairs", Vector2i(RING_X - 1, 0))
	if stairs_outside:
		build(world, "stairs", Vector2i(RING_X + 1, 0))
	_place(world, 1, _on_wall(Vector2i(RING_X, 4)))
	return world


func test_bandit_reaches_an_archer_on_the_wall_only_by_free_stairs() -> void:
	# Treppe nur innen: Der Räuber kommt nicht hinauf, der Bogenschütze schießt ihn von oben ab.
	var world := _soldier_on_ring("archer", false)
	var visited := _bandit_route(world)
	var archer := world.get_resident(1)
	for position in visited:
		assert_eq(position.z, Figure.Level.GROUND, "Räuber bleibt unten:")
	_run(world, 300)
	assert_eq(archer.hp, 50, "Bogenschütze unverletzt:")
	assert_true(world.get_enemies().is_empty(), "Räuber erschossen")
	# Treppe auch draußen: Er steigt hinauf und greift an.
	world = _soldier_on_ring("archer", true)
	archer = world.get_resident(1)
	var bandit := add_enemy(world, "bandit", Vector2i(15, 13))
	# Lambdas fangen Werte ein: Der Merker steckt deshalb in einem Array.
	var climbed: Array[bool] = [false]
	_until(world, func() -> bool:
		climbed[0] = climbed[0] or bandit.level == WALL_WALK
		return archer.hp < 50 or world.get_enemy(bandit.id) == null, "Treffer am Bogenschützen")
	assert_true(climbed[0], "Räuber auf dem Wehrgang")
	assert_true(archer.hp < 50, "Bogenschütze getroffen")


func test_melee_only_on_the_same_level_ranged_across_levels() -> void:
	var world := _soldier_on_ring("swordsman", false)
	var bandit := add_enemy(world, "bandit", Vector2i(15, 13))
	_until(world, func() -> bool: return not bandit.is_moving(), "Räuber steht")
	# Der Soldat steigt an die Kachel neben dem wartenden Räuber, oben auf der Mauer.
	var above := _on_wall(Vector2i(RING_X, bandit.tile.y))
	assert_eq(bandit.tile.x, RING_X + 1, "Räuber an der Mauer:")
	_place(world, 1, above)
	var soldier := world.get_resident(1)
	assert_eq(world.execute(Command.attack([1] as Array[int], bandit.id)), "", "Angreifen:")
	_run(world, 200)
	assert_eq([soldier.hp, bandit.hp], [100, 80], "Kein Nahkampf über Ebenen:")
	# Ein Bogenschütze trifft ihn von dort aus.
	world = _soldier_on_ring("archer", false)
	bandit = add_enemy(world, "bandit", Vector2i(15, 13))
	_until(world, func() -> bool: return bandit.hp < 80, "Pfeil trifft")


func test_save_and_load_while_defending_continues_the_same() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	_place(world, 1, Figure.ground(Vector2i(15, 8)))
	add_enemy(world, "bandit", Vector2i(15, 13))
	_run(world, 5)
	assert_true(world.get_resident(1).defending, "Verteidigt sich")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in 300:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
