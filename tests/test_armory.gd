extends TestCase
## Simulationstests: Waffenkammer (Lagerart für Waffen), Schmied und Bogner (Verhalten
## „produce“, reine Daten). Leere Karte (nur Wiese), Szenario mit 100 Gold; Bergfried (ID 1)
## bei (2, 2), Warenlager (ID 2) bei (7, 2), Lagerfeuer (ID 3) bei (3, 8), Kornspeicher (ID 4)
## bei (7, 6). Eine Waffenkammer entsteht nicht bei der Gründung.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
## Waffenkammer (3×3) unten rechts, eine zweite direkt rechts daneben, eine dritte abseits.
const ARMORY_SITE := Vector2i(10, 10)
const NEXT_ARMORY_SITE := Vector2i(13, 10)
const DISTANT_ARMORY_SITE := Vector2i(16, 2)
## Schmied und Bogner (2×2) rechts vom Warenlager.
const SMITH_SITE := Vector2i(11, 2)
const BOWYER_SITE := Vector2i(11, 5)
## Markt (3×3) an derselben Stelle wie der Schmied.
const MARKET_SITE := Vector2i(11, 2)
## Obergrenze für einen ganzen Arbeitsgang.
const MAX_TICKS := 1500


func _founded() -> GameWorld:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte); false, wenn nie.
func _until(world: GameWorld, condition: Callable, what: String) -> bool:
	for i in MAX_TICKS:
		if condition.call():
			return true
		world.step()
	assert_true(false, "Nach %d Takten nicht erreicht: %s" % [MAX_TICKS, what])
	return false


func test_sword_and_bow_are_weapons_for_the_armory() -> void:
	var goods: Dictionary = GameDefs.get_instance().goods
	assert_eq(goods.keys(), ["wood", "stone", "iron", "wheat", "flour", "apples", "meat", "bread", "sword", "bow"],
			"Reihenfolge:")
	assert_eq([goods["sword"]["name"], goods["sword"]["storage"]], ["Schwert", "armory"], "Schwert:")
	assert_eq([goods["bow"]["name"], goods["bow"]["storage"]], ["Bogen", "armory"], "Bogen:")
	for good: String in ["sword", "bow"]:
		assert_true(goods[good].has("color"), "Farbe für getragenes %s" % good)
		assert_true(not goods[good].get("food", false), "%s ist keine Nahrung" % good)
	assert_eq([Market.buy_price("sword"), Market.sell_price("sword")], [60, 30], "Preise Schwert:")
	assert_eq([Market.buy_price("bow"), Market.sell_price("bow")], [30, 15], "Preise Bogen:")


func test_armory_data() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["armory"]
	var armory := Building.create(1, "armory", Vector2i.ZERO)
	assert_eq([def["name"], def["hotkey"], Building.size_of("armory"), armory.capacity(), GameWorld.goods_cost_of("armory"),
			GameWorld.gold_cost_of("armory")],
			["Waffenkammer", "A", Vector2i(3, 3), 100, {"wood": 10}, 0], "Waffenkammer:")
	assert_true(armory.is_storage(), "Ist ein Lager")
	assert_eq(Building.storage_type_of("armory"), "armory", "Lagerart:")
	assert_eq(Building.storage_name("armory"), "Waffenkammer", "Name der Lagerart:")
	assert_eq(Building.storage_missing_text("armory"), "Keine Waffenkammer", "Grund ohne Waffenkammer:")
	assert_eq(Building.storage_building_of("armory"), "armory", "Gebäude der Lagerart:")
	assert_eq(Building.storage_building_of("treasure"), "", "Lagerart ohne Gebäude:")
	assert_true(GameWorld.is_buildable("armory"), "Hat eine Bautaste")


func test_smith_and_bowyer_data() -> void:
	var expected := {
		"smith": ["Schmied", "Schmied", "S", Vector2i(2, 2), "iron", 2, "sword", 1, 300, "schmiedet ein Schwert", 20, 40],
		"bowyer": ["Bogner", "Bogner", "R", Vector2i(2, 2), "wood", 2, "bow", 1, 250, "baut einen Bogen", 10, 20],
	}
	for type_id: String in expected:
		var def: Dictionary = GameDefs.get_instance().buildings[type_id]
		var building := Building.create(1, type_id, Vector2i.ZERO)
		var actual: Array = [def["name"], building.worker_name(), def["hotkey"], Building.size_of(type_id),
				building.input_good(), building.input_amount(), building.product(), building.carry_load(),
				building.work_ticks(), building.work_text(), GameWorld.goods_cost_of(type_id)["wood"],
				GameWorld.gold_cost_of(type_id)]
		assert_eq(actual, expected[type_id], "%s:" % type_id)
		assert_eq(def["behavior"], "produce", "Verhalten %s:" % type_id)
		assert_eq(building.worker_slots(), 1, "Arbeiter %s:" % type_id)
		assert_true(GameWorld.is_buildable(type_id), "%s hat eine Bautaste" % type_id)


func test_no_armory_at_founding() -> void:
	var world := _founded()
	for building: Building in world.get_buildings():
		assert_true(building.type != "armory", "Keine Waffenkammer bei der Gründung")
	assert_eq([world.get_storage_used("armory"), world.get_storage_capacity("armory")], [0, 0], "Belegung:")


func test_further_armories_must_border_an_armory() -> void:
	var world := _founded()
	assert_eq(world.build_error("armory", DISTANT_ARMORY_SITE), "", "Die erste Waffenkammer überall:")
	build(world, "armory", ARMORY_SITE)
	assert_eq(world.build_error("armory", DISTANT_ARMORY_SITE), "Muss an eine Waffenkammer grenzen",
			"Abseits nicht:")
	assert_eq(world.build_error("armory", NEXT_ARMORY_SITE), "", "Angrenzend:")


func test_smith_forges_a_sword_into_the_armory() -> void:
	var world := _founded()
	var armory := build(world, "armory", ARMORY_SITE)
	build(world, "smith", SMITH_SITE)
	put_goods(world, WAREHOUSE, "iron", 3)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.PRODUCING and worker.is_inside_building(),
			"Schmieden")
	assert_eq(world.activity_of(worker), "Schmied – schmiedet ein Schwert", "Tätigkeit:")
	_until(world, func() -> bool: return world.get_stock("sword") == 1, "Schwert in der Waffenkammer")
	assert_eq(world.get_building(armory).contents, {"sword": 1} as Dictionary[String, int], "Waffenkammer:")
	assert_eq(world.get_stock("iron"), 1, "Genau 2 Eisen verbraucht:")


func test_bowyer_makes_a_bow_into_the_armory() -> void:
	var world := _founded()
	var armory := build(world, "armory", ARMORY_SITE)
	build(world, "bowyer", BOWYER_SITE)
	var wood := world.get_stock("wood")
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.PRODUCING and worker.is_inside_building(),
			"Bogen bauen")
	assert_eq(world.activity_of(worker), "Bogner – baut einen Bogen", "Tätigkeit:")
	_until(world, func() -> bool: return world.get_stock("bow") == 1, "Bogen in der Waffenkammer")
	assert_eq(world.get_building(armory).contents, {"bow": 1} as Dictionary[String, int], "Waffenkammer:")
	assert_eq(world.get_stock("wood"), wood - 2, "Genau 2 Holz verbraucht:")


func test_without_armory_smith_and_bowyer_wait_with_the_weapon() -> void:
	var cases := {
		"smith": [SMITH_SITE, "sword", "Schmied – wartet: Lager voll"],
		"bowyer": [BOWYER_SITE, "bow", "Bogner – wartet: Lager voll"],
	}
	for type_id: String in cases:
		var site: Vector2i = cases[type_id][0]
		var weapon: String = cases[type_id][1]
		var world := _founded()
		var workplace := world.get_building(build(world, type_id, site))
		put_goods(world, WAREHOUSE, "iron", 2)
		var worker := world.get_resident(1)
		_until(world, func() -> bool:
			return worker.task == Resident.Task.WAITING_FOR_STORAGE and not worker.is_moving(),
			"Warten mit der Waffe (%s)" % type_id)
		assert_eq(worker.tile, workplace.entrance(), "An der Arbeitsstätte (%s):" % type_id)
		assert_eq([worker.carried_good, worker.carried_amount], [weapon, 1], "Behält die Waffe (%s):" % type_id)
		assert_eq(world.activity_of(worker), cases[type_id][2], "Tätigkeit (%s):" % type_id)
		build(world, "armory", ARMORY_SITE)
		_until(world, func() -> bool: return world.get_stock(weapon) == 1,
				"Lieferung nach dem Bau der Waffenkammer (%s)" % type_id)


func test_buying_weapons_needs_an_armory() -> void:
	var world := _founded()
	build(world, "market", MARKET_SITE)
	assert_eq(world.trade_error("bow", true), "Keine Waffenkammer", "Ohne Waffenkammer:")
	build(world, "armory", ARMORY_SITE)
	# 100 Gold − 30 für den Markt reichen nicht für 5 × 30.
	assert_eq(world.trade_error("bow", true), "Nicht genug Gold (150 nötig)", "Mit Waffenkammer:")
