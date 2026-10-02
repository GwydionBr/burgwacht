extends TestCase
## Simulationstests: Wohnraum aus Bergfried und Wohnhäusern. Leere Karte (nur Wiese),
## Bergfried (ID 1) bei (2, 2); Warenlager, Lagerfeuer und Kornspeicher daneben, darin die
## Startwaren des Testszenarios (100 Holz, 50 Stein).

const KEEP_ORIGIN := Vector2i(2, 2)
## Freie Stelle rechts vom ersten Warenlager.
const SITE := Vector2i(12, 2)
## Freie Stelle neben SITE.
const SITE_NEXT := Vector2i(15, 2)


func _founded_world() -> GameWorld:
	var world := empty_world()
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func test_house_is_buildable_housing() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["house"]
	assert_eq(str(def["behavior"]), "housing", "Verhalten:")
	assert_eq(str(def["name"]), "Wohnhaus", "Name:")
	assert_eq(Building.size_of("house"), Vector2i(2, 2), "Größe:")
	assert_eq(int(def["housing"]), 8, "Wohnraum:")
	assert_eq(int(def["cost"]["wood"]), 6, "Kosten Holz:")
	assert_eq((def["cost"] as Dictionary).size(), 1, "Nur Holz:")
	assert_true(GameWorld.buildable_types().has("house"), "Wohnhaus hat eine Bautaste")


func test_keep_has_base_housing() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["keep"]
	assert_eq(int(def["housing"]), 8, "Grundwohnraum:")


func test_no_housing_before_founding() -> void:
	assert_eq(empty_world().get_housing(), 0, "Wohnraum vor der Gründung:")


func test_founding_gives_base_housing() -> void:
	assert_eq(_founded_world().get_housing(), 8, "Wohnraum nach der Gründung:")


func test_each_house_adds_housing() -> void:
	var world := _founded_world()
	build(world, "house", SITE)
	assert_eq(world.get_housing(), 16, "Mit einem Wohnhaus:")
	build(world, "house", SITE_NEXT)
	assert_eq(world.get_housing(), 24, "Mit zwei Wohnhäusern:")
	assert_eq(world.get_stock("wood"), 88, "Holz nach den Kosten:")


func test_demolishing_house_lowers_housing() -> void:
	var world := _founded_world()
	var first := build(world, "house", SITE)
	build(world, "house", SITE_NEXT)
	assert_eq(world.execute(Command.demolish(first)), "", "Abriss:")
	assert_eq(world.get_housing(), 16, "Nach dem Abriss:")


func test_other_buildings_add_no_housing() -> void:
	var world := _founded_world()
	build(world, "woodcutter", SITE)
	assert_eq(world.get_housing(), 8, "Holzfäller ohne Wohnraum:")


func test_house_has_no_workers() -> void:
	var world := _founded_world()
	var id := build(world, "house", SITE)
	assert_true(not world.get_building(id).is_workplace(), "Wohnhaus ist keine Arbeitsstätte")
	assert_eq(world.get_building(id).housing(), 8, "Wohnraum des Gebäudes:")
	for i in 20:
		world.step()
	assert_eq(world.get_idle_count(), 4, "Alle bleiben untätig:")


func test_save_and_load_keeps_housing() -> void:
	var world := _founded_world()
	build(world, "house", SITE)
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_housing(), 16, "Wohnraum nach dem Laden:")
