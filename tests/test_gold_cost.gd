extends TestCase
## Simulationstests: Gebäude mit Gold in den Baukosten (Markt: 20 Holz + 30 Gold).
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), das erste Warenlager (ID 2) daneben
## mit den Startwaren des Testszenarios (100 Holz, 50 Stein).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
## Freie Stelle rechts vom ersten Warenlager.
const SITE := Vector2i(12, 2)


func _founded(scenario_id := "tiny_market") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func test_market_is_buildable_with_market_behavior() -> void:
	assert_true(GameWorld.is_buildable("market"), "Markt baubar")
	var def: Dictionary = GameDefs.get_instance().buildings["market"]
	assert_eq(def["behavior"], "market", "Verhalten:")
	assert_eq(def["hotkey"], "T", "Taste:")
	assert_eq(int(def["cost"]["wood"]), 20, "Holz:")
	assert_eq(GameWorld.gold_cost_of("market"), 30, "Gold:")
	assert_true(not def.has("workers"), "Keine Arbeiter")


func test_build_takes_gold_from_treasury() -> void:
	var world := _founded()
	var signals: Array[bool] = []
	world.treasury_changed.connect(func() -> void: signals.append(true))
	build(world, "market", SITE)
	assert_eq(world.get_treasury(), 15, "45 − 30 Gold:")
	assert_eq(world.get_stock("wood"), 80, "100 − 20 Holz:")
	assert_eq(signals.size(), 1, "treasury_changed einmal:")


func test_gold_is_not_a_good() -> void:
	var world := _founded()
	build(world, "market", SITE)
	assert_true(not world.get_building(WAREHOUSE).contents.has("gold"), "Kein Gold im Lager")


func test_build_rejected_without_enough_gold() -> void:
	var world := _founded("tiny_gold")
	assert_eq(world.build_error("market", SITE), "Nicht genug Gold (30 nötig)", "Vorschau:")
	assert_eq(world.execute(Command.build("market", SITE)), "Nicht genug Gold (30 nötig)", "Befehl:")
	assert_eq(world.get_treasury(), 25, "Schatz unverändert:")
	assert_eq(world.get_stock("wood"), 100, "Holz unverändert:")
	assert_eq(world.get_building_at(SITE), null, "Nicht gebaut:")


func test_goods_are_checked_before_gold() -> void:
	var world := _founded("tiny_gold")
	put_goods(world, WAREHOUSE, "wood", 10)
	assert_eq(world.build_error("market", SITE), "Zu wenig Holz (20 nötig)", "Waren zuerst:")


func test_demolish_refunds_half_the_gold() -> void:
	var world := _founded()
	var id := build(world, "market", SITE)
	var signals: Array[bool] = []
	world.treasury_changed.connect(func() -> void: signals.append(true))
	assert_eq(world.execute(Command.demolish(id)), "", "Abriss:")
	assert_eq(world.get_treasury(), 30, "15 + 30 / 2 Gold:")
	assert_eq(world.get_stock("wood"), 90, "80 + 20 / 2 Holz:")
	assert_eq(signals.size(), 1, "treasury_changed einmal:")


func test_gold_refund_is_rounded_down() -> void:
	var cost: Dictionary = GameDefs.get_instance().buildings["market"]["cost"]
	var original := int(cost["gold"])
	cost["gold"] = 31
	var world := _founded()
	var id := build(world, "market", SITE)
	world.execute(Command.demolish(id))
	cost["gold"] = original
	assert_eq(world.get_treasury(), 29, "45 − 31 + 15 Gold:")


func test_has_market() -> void:
	var world := _founded()
	assert_true(not world.has_market(), "Vorher kein Markt")
	var id := build(world, "market", SITE)
	assert_true(world.has_market(), "Markt steht")
	world.execute(Command.demolish(id))
	assert_true(not world.has_market(), "Nach Abriss kein Markt")

