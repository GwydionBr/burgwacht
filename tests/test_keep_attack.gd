extends TestCase
## Simulationstests: Lebenspunkte der Gebäude, Angriff auf den Bergfried und Niederlage.
## Leere Karte (nur Wiese) 20×16, tiny_production bzw. tiny_bandits (ein Räuber bei (16, 13));
## Bergfried (ID 1) bei (2, 2) mit der Grundfläche (2..5, 2..5), Warenlager (ID 2), Lagerfeuer
## (ID 3) bei (3, 8), Kornspeicher (ID 4).

const KEEP_ORIGIN := Vector2i(2, 2)
const KEEP := 1
const CAMPFIRE := 3
## Obergrenze für Läufe bis zu einem Ereignis.
const MAX_TICKS := 1500


func _founded(scenario_id := "tiny_production") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func test_buildings_start_with_full_hit_points_from_data() -> void:
	var world := _founded()
	var wall := build(world, "wall", Vector2i(12, 12))
	var house := build(world, "house", Vector2i(14, 2))
	var keep := world.get_building(KEEP)
	assert_eq([keep.hp, keep.max_hp()], [1000, 1000], "Bergfried:")
	assert_eq([world.get_building(wall).hp, world.get_building(wall).max_hp()], [300, 300], "Mauer:")
	assert_eq([world.get_building(house).hp, world.get_building(house).max_hp()], [150, 150], "Wohnhaus:")
	var campfire := world.get_building(CAMPFIRE)
	assert_eq(campfire.max_hp(), 0, "Lagerfeuer ohne Lebenspunkte:")
	assert_true(not campfire.is_destructible(), "Lagerfeuer unzerstörbar")
	assert_true(keep.is_destructible(), "Bergfried zerstörbar")


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte).
func _until(world: GameWorld, condition: Callable, what: String) -> void:
	for i in MAX_TICKS:
		if condition.call():
			return
		world.step()
	assert_true(false, "%s nach %d Takten nicht eingetreten" % [what, MAX_TICKS])


## Lässt die Welt laufen, bis der Bergfried zum ersten Mal getroffen ist.
func _until_keep_hit(world: GameWorld) -> void:
	var keep := world.get_building(KEEP)
	_until(world, func() -> bool: return keep.is_damaged(), "Treffer am Bergfried")


func test_bandit_at_the_keep_attacks_it_at_his_attack_pace() -> void:
	var world := _founded("tiny_bandits")
	var bandit := world.get_enemy(1)
	var keep := world.get_building(KEEP)
	var changed: Array[int] = []
	world.building_changed.connect(func(id: int) -> void: changed.append(id))
	_until_keep_hit(world)
	assert_true(not bandit.is_moving(), "Steht beim Angriff")
	assert_true(Combat._distance_to_building(bandit.tile, keep) < 1.5, "Auf einer Nachbarkachel: %s" % bandit.tile)
	assert_eq(keep.hp, 1000 - 12, "Erster Treffer:")
	assert_eq(changed, [KEEP] as Array[int], "Gemeldet:")
	assert_eq(world.enemy_activity_of(bandit), "Räuber – greift Bergfried an", "Tätigkeit:")
	for i in 9:
		world.step()
	assert_eq(keep.hp, 1000 - 12, "Vor Ablauf der Angriffsdauer:")
	world.step()
	assert_eq(keep.hp, 1000 - 24, "Nach 10 Takten:")
	# Bewohner greift er nicht an.
	assert_eq(world.get_population(), 4, "Bewohner:")


func test_soldier_in_reach_takes_priority_over_the_keep() -> void:
	var world := _founded()
	put_goods(world, 2, "stone", 100)
	var armory := build(world, "armory", Vector2i(10, 10))
	put_goods(world, armory, "sword", 1)
	var barracks := build(world, "barracks", Vector2i(14, 2))
	assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	assert_eq(world.execute(Command.spawn_enemy("bandit")), "", "Erscheinen:")
	var bandit := world.get_enemy(1)
	var keep := world.get_building(KEEP)
	_until_keep_hit(world)
	assert_eq(world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(6, 0)))), "", "Bewegen:")
	_until(world, func() -> bool: return bandit.target_id == 1, "Räuber greift Soldaten an")
	assert_eq(bandit.target_building_id, 0, "Lässt vom Bergfried ab:")
	var hp := keep.hp
	_until(world, func() -> bool: return world.get_enemy(1) == null, "Räuber fällt")
	assert_eq(keep.hp, hp, "Kein Treffer am Bergfried, solange er den Soldaten angreift:")


func test_first_hit_on_the_keep_is_announced_once_per_attack() -> void:
	var world := _founded()
	put_goods(world, 2, "stone", 100)
	var armory := build(world, "armory", Vector2i(10, 10))
	put_goods(world, armory, "sword", 1)
	var barracks := build(world, "barracks", Vector2i(14, 2))
	assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	world.execute(Command.spawn_enemy("bandit"))
	_until_keep_hit(world)
	for i in 50:
		world.step()
	assert_eq(notices, ["Der Bergfried wird angegriffen!"] as Array[String], "Einmal beim ersten Treffer:")
	# Der Soldat erschlägt ihn; der nächste Angriff wird wieder gemeldet.
	world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(6, 0))))
	_until(world, func() -> bool: return world.get_enemy(1) == null, "Räuber fällt")
	world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(17, 14))))
	_until(world, func() -> bool: return world.get_resident(1).tile == Vector2i(17, 14), "Soldat fort")
	notices.clear()
	var hp := world.get_building(KEEP).hp
	world.execute(Command.spawn_enemy("bandit"))
	_until(world, func() -> bool: return world.get_building(KEEP).hp < hp, "Zweiter Angriff")
	assert_eq(notices, ["Der Bergfried wird angegriffen!"] as Array[String], "Zweiter Angriff gemeldet:")


## Fünf Räuber um den Bergfried: Er fällt nach gut 160 Takten.
func _besieged() -> GameWorld:
	var world := _founded()
	for tile: Vector2i in [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 1), Vector2i(3, 1)]:
		add_enemy(world, "bandit", tile)
	return world


func test_keep_at_zero_is_defeat_time_stops_and_commands_are_rejected() -> void:
	var world := _besieged()
	var defeats: Array[int] = []
	world.defeated.connect(func() -> void: defeats.append(world.get_tick()))
	assert_true(not world.is_defeated(), "Noch nicht verloren")
	_until(world, world.is_defeated, "Niederlage")
	assert_eq(world.get_building(KEEP).hp, 0, "Bergfried:")
	assert_eq(defeats, [world.get_tick()] as Array[int], "Einmal gemeldet:")
	var data := world.to_data()
	for i in 20:
		world.step()
	assert_eq(world.get_tick(), int(data["tick"]), "Die Zeit steht:")
	assert_eq(world.get_day(), 1, "Erreichter Tag:")
	for command: Command in [Command.build("house", Vector2i(14, 2)), Command.spawn_enemy("bandit"),
			Command.set_tax_rate("none"), Command.demolish(2)]:
		assert_eq(world.execute(command), GameWorld.DEFEATED, "Abgelehnt:")
	assert_eq(world.to_data(), data, "Nichts geändert")
	assert_eq(defeats.size(), 1, "Nicht noch einmal gemeldet:")


func test_defeat_is_saved_and_loaded() -> void:
	var world := _besieged()
	_until(world, func() -> bool: return world.get_building(KEEP).hp < 500, "Bergfried beschädigt")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_building(KEEP).hp, world.get_building(KEEP).hp, "Lebenspunkte geladen:")
	for i in 300:
		world.step()
		loaded.step()
	assert_true(world.is_defeated(), "Verloren")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Gleicher Verlauf:")
	assert_eq(loaded.to_data(), world.to_data(), "Gleiche Daten:")
	var reloaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_true(reloaded.is_defeated(), "Niederlage geladen")
