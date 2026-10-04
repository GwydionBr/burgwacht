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
