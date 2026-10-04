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
