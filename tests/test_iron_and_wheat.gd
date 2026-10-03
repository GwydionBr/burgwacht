extends TestCase
## Simulationstests: Eisenmine (Verhalten „gather“) und Weizenfarm (Verhalten „farm“) –
## reine Einträge in den Daten. Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2),
## Warenlager (ID 2) bei (7, 2), Lagerfeuer (ID 3) bei (3, 8), Kornspeicher (ID 4) bei (7, 6).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
## Freie Stelle rechts vom Warenlager.
const SITE := Vector2i(12, 2)
## Eisenvorkommen direkt rechts neben einer Eisenmine (2×2) bei SITE.
const IRON := Vector2i(14, 2)
const NOT_NEXT_TO_IRON := "Muss an ein Eisenvorkommen grenzen"
const ONLY_ON_GRASS := "Nur auf Wiese"
## Obergrenze für einen ganzen Arbeitsgang.
const MAX_TICKS := 1000


func _founded() -> GameWorld:
	var world := empty_world()
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _until(world: GameWorld, condition: Callable, what: String) -> bool:
	for i in MAX_TICKS:
		if condition.call():
			return true
		world.step()
	assert_true(false, "Nach %d Takten nicht erreicht: %s" % [MAX_TICKS, what])
	return false


func test_wheat_is_a_warehouse_good_after_iron() -> void:
	var goods: Dictionary = GameDefs.get_instance().goods
	assert_eq(goods.keys().slice(0, 4), ["wood", "stone", "iron", "wheat"], "Reihenfolge:")
	var wheat: Dictionary = goods["wheat"]
	assert_eq(str(wheat["name"]), "Weizen", "Name:")
	assert_eq(str(wheat["storage"]), "warehouse", "Lagerart:")
	assert_true(not wheat.get("food", false), "Weizen ist keine Nahrung")
	assert_true(wheat.has("color"), "Farbe für die getragene Ware")


func test_iron_mine_data() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["iron_mine"]
	assert_eq(str(def["name"]), "Eisenmine", "Name:")
	assert_eq(str(def["behavior"]), "gather", "Verhalten:")
	assert_eq(str(def["worker_name"]), "Bergarbeiter", "Arbeitername:")
	assert_eq(str(def["hotkey"]), "E", "Taste:")
	assert_eq(Building.size_of("iron_mine"), Vector2i(2, 2), "Größe:")
	assert_eq(int(def["cost"]["wood"]), 20, "Kosten Holz:")
	assert_eq((def["cost"] as Dictionary).size(), 1, "Nur Holz:")
	var mine := Building.create(1, "iron_mine", Vector2i.ZERO)
	var actual: Array = [mine.worker_slots(), mine.deposit_type(), mine.mine_ticks(), mine.process_ticks(),
			mine.carry_load(), mine.gather_range()]
	assert_eq(actual, [1, "iron", 80, 20, 2, 6], "Sammlerwerte:")
	assert_true(GameWorld.buildable_types().has("iron_mine"), "Eisenmine hat eine Bautaste")


func test_wheat_farm_data() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["wheat_farm"]
	assert_eq(str(def["name"]), "Weizenfarm", "Name:")
	assert_eq(str(def["behavior"]), "farm", "Verhalten:")
	assert_eq(str(def["worker_name"]), "Bauer", "Arbeitername:")
	assert_eq(str(def["hotkey"]), "W", "Taste:")
	assert_eq(Building.size_of("wheat_farm"), Vector2i(4, 4), "Größe:")
	assert_eq(int(def["cost"]["wood"]), 10, "Kosten Holz:")
	assert_eq((def["cost"] as Dictionary).size(), 1, "Nur Holz:")
	var farm := Building.create(1, "wheat_farm", Vector2i.ZERO)
	var actual: Array = [farm.worker_slots(), farm.work_ticks(), farm.product(), farm.carry_load(), farm.work_text()]
	assert_eq(actual, [1, 250, "wheat", 4, "baut Weizen an"], "Hofwerte:")
	assert_true(GameWorld.buildable_types().has("wheat_farm"), "Weizenfarm hat eine Bautaste")


func test_iron_mine_next_to_iron_is_allowed() -> void:
	var world := _founded()
	add_deposit(world, IRON, "iron")
	assert_eq(world.build_error("iron_mine", SITE), "", "Am Eisenvorkommen:")


func test_iron_mine_without_iron_is_rejected() -> void:
	var world := _founded()
	# Felsen und Baum daneben zählen nicht, schräg auch nicht.
	add_deposit(world, IRON, "stone")
	add_deposit(world, SITE + Vector2i(-1, 0), "tree")
	add_deposit(world, SITE + Vector2i(2, 2), "iron")
	var before := world.to_data()
	assert_eq(world.build_error("iron_mine", SITE), NOT_NEXT_TO_IRON, "Abfrage:")
	assert_eq(world.execute(Command.build("iron_mine", SITE)), NOT_NEXT_TO_IRON, "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_miner_delivers_iron_to_warehouse() -> void:
	var world := _founded()
	add_deposit(world, IRON, "iron")
	var mine := build(world, "iron_mine", SITE)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	var mining_text := ""
	var amount_before := world.map.get_deposit(IRON).amount
	for i in MAX_TICKS:
		if world.get_stock("iron") > 0:
			break
		world.step()
		if worker.task == Resident.Task.MINING:
			mining_text = world.activity_of(worker)
	assert_eq(worker.workplace_id, mine, "Zugeteilt:")
	assert_eq(world.get_building(WAREHOUSE).contents.get("iron", 0), 2, "Eisen im Warenlager (Traglast 2):")
	assert_eq(changed, [WAREHOUSE] as Array[int], "Gemeldete Lager:")
	assert_eq(world.map.get_deposit(IRON).amount, amount_before - 2, "Rest im Vorkommen:")
	assert_true(mining_text.begins_with("Bergarbeiter – "), "Tätigkeit beim Abbau: %s" % mining_text)


func test_wheat_farm_only_on_grass_and_meadow() -> void:
	var world := _founded()
	world.map.set_terrain(SITE + Vector2i(3, 0), "meadow")
	assert_eq(world.build_error("wheat_farm", SITE), "", "Wiese und Blumenwiese:")
	world.map.set_terrain(SITE + Vector2i(1, 2), "dirt")
	var before := world.to_data()
	assert_eq(world.build_error("wheat_farm", SITE), ONLY_ON_GRASS, "Abfrage:")
	assert_eq(world.execute(Command.build("wheat_farm", SITE)), ONLY_ON_GRASS, "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_farmer_delivers_wheat_to_warehouse() -> void:
	var world := _founded()
	build(world, "wheat_farm", SITE)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	var worker := world.get_resident(1)
	var ticks_inside := 0
	var farming_text := ""
	for i in MAX_TICKS:
		if world.get_stock("wheat") > 0:
			break
		world.step()
		if worker.is_inside_building():
			ticks_inside += 1
			farming_text = world.activity_of(worker)
	assert_eq(world.get_building(WAREHOUSE).contents.get("wheat", 0), 4, "Weizen im Warenlager:")
	assert_eq(changed, [WAREHOUSE] as Array[int], "Gemeldete Lager:")
	assert_eq(ticks_inside, 250, "Takte auf der Farm:")
	assert_eq(farming_text, "Bauer – baut Weizen an", "Tätigkeit:")
	_until(world, func() -> bool: return world.get_stock("wheat") == 8, "Zweiter Gang")
