extends TestCase
## Simulationstests: Handel am Markt (immer 5 Einheiten, ganz oder gar nicht).
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), das erste Warenlager (ID 2) daneben
## mit 100 Holz und 50 Stein, der erste Kornspeicher (ID 4) leer; 100 Gold, nach dem Markt 70.

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const GRANARY := 4
## Freie Stelle rechts vom ersten Warenlager, Platz für ein zweites dazwischen.
const SITE := Vector2i(14, 2)
const NEXT_TO_WAREHOUSE := Vector2i(10, 1)


func _founded() -> GameWorld:
	var world := empty_world("tiny_trade")
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Gegründet und mit Markt: 80 Holz, 50 Stein, 70 Gold.
func _with_market() -> GameWorld:
	var world := _founded()
	build(world, "market", SITE)
	return world


func _signal_counts(world: GameWorld) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = { "stock": 0, "treasury": 0 }
	world.stock_changed.connect(func(_id: int) -> void: counts["stock"] += 1)
	world.treasury_changed.connect(func() -> void: counts["treasury"] += 1)
	return counts


## Prüft Vorschau und Befehl auf denselben Grund und dass sich nichts geändert hat.
func _assert_rejected(world: GameWorld, good: String, buying: bool, reason: String) -> void:
	var before := world_snapshot(world)
	assert_eq(world.trade_error(good, buying), reason, "Vorschau:")
	assert_eq(world.execute(Command.trade(good, buying)), reason, "Befehl:")
	assert_eq(world_snapshot(world), before, "Nichts geändert")


func test_buy_takes_gold_and_stores_goods() -> void:
	var world := _with_market()
	var counts := _signal_counts(world)
	assert_eq(world.trade_error("wood", true), "", "Vorschau:")
	assert_eq(world.execute(Command.trade("wood", true)), "", "Kauf:")
	assert_eq(world.get_stock("wood"), 85, "80 + 5 Holz:")
	assert_eq(world.get_treasury(), 50, "70 − 5 × 4 Gold:")
	assert_eq(counts, { "stock": 1, "treasury": 1 } as Dictionary[String, int], "Signale:")


func test_sell_takes_goods_and_adds_gold() -> void:
	var world := _with_market()
	var counts := _signal_counts(world)
	assert_eq(world.execute(Command.trade("stone", false)), "", "Verkauf:")
	assert_eq(world.get_stock("stone"), 45, "50 − 5 Stein:")
	assert_eq(world.get_treasury(), 90, "70 + 5 × 4 Gold:")
	assert_eq(counts, { "stock": 1, "treasury": 1 } as Dictionary[String, int], "Signale:")


func test_food_is_bought_into_the_granary() -> void:
	var world := _with_market()
	assert_eq(world.execute(Command.trade("apples", true)), "", "Kauf:")
	assert_eq(world.get_building(GRANARY).contents, { "apples": 5 }, "Im Kornspeicher:")


func test_buy_fills_the_oldest_storage_first() -> void:
	var world := _with_market()
	var second := build(world, "warehouse", NEXT_TO_WAREHOUSE)
	put_goods(world, WAREHOUSE, "stone", 118)
	assert_eq(world.execute(Command.trade("wood", true)), "", "Kauf:")
	assert_eq(world.get_building(WAREHOUSE).contents["wood"], 82, "Ältestes bis voll:")
	assert_eq(world.get_building(second).contents, { "wood": 3 }, "Rest ins nächste:")


func test_sell_takes_from_the_oldest_storage_first() -> void:
	var world := _with_market()
	var second := build(world, "warehouse", NEXT_TO_WAREHOUSE)
	put_goods(world, WAREHOUSE, "stone", 3)
	put_goods(world, second, "stone", 10)
	assert_eq(world.execute(Command.trade("stone", false)), "", "Verkauf:")
	assert_true(not world.get_building(WAREHOUSE).contents.has("stone"), "Ältestes leer")
	assert_eq(world.get_building(second).contents["stone"], 8, "Rest aus dem nächsten:")


func test_rejected_without_market() -> void:
	_assert_rejected(_founded(), "wood", true, "Kein Markt gebaut")
	_assert_rejected(_founded(), "wood", false, "Kein Markt gebaut")


func test_rejected_during_founding() -> void:
	_assert_rejected(empty_world("tiny_trade"), "wood", true, "Kein Markt gebaut")


func test_no_trade_after_the_last_market_is_demolished() -> void:
	var world := _with_market()
	var second := build(world, "market", find_site(world, "market"))
	world.execute(Command.demolish(world.get_building_at(SITE).id))
	assert_eq(world.trade_error("wood", true), "", "Zweiter Markt reicht:")
	world.execute(Command.demolish(second))
	_assert_rejected(world, "wood", true, "Kein Markt gebaut")


func test_rejected_for_goods_that_are_not_tradable() -> void:
	var goods := GameDefs.get_instance().goods
	goods["test_relic"] = { "name": "Reliquie", "storage": "warehouse", "color": "#ffffff" }
	var world := _with_market()
	_assert_rejected(world, "test_relic", true, "Reliquie ist nicht handelbar")
	_assert_rejected(world, "test_relic", false, "Reliquie ist nicht handelbar")
	goods.erase("test_relic")


func test_rejected_for_unknown_goods() -> void:
	_assert_rejected(_with_market(), "unobtainium", true, "Diese Ware gibt es nicht")


func test_buy_rejected_without_storage_of_its_type() -> void:
	var world := _with_market()
	assert_eq(world.execute(Command.demolish(GRANARY)), "", "Kornspeicher abreißen:")
	_assert_rejected(world, "apples", true, "Kein Kornspeicher")


## Eisen kostet 5 × 20 = 100 Gold, im Schatz sind nur 70.
func test_buy_rejected_without_enough_gold() -> void:
	_assert_rejected(_with_market(), "iron", true, "Nicht genug Gold (100 nötig)")


func test_storage_is_checked_before_gold() -> void:
	var apples: Dictionary = GameDefs.get_instance().goods["apples"]
	var original := int(apples["buy"])
	apples["buy"] = 100
	var world := _with_market()
	world.execute(Command.demolish(GRANARY))
	_assert_rejected(world, "apples", true, "Kein Kornspeicher")
	apples["buy"] = original


func test_buy_rejected_without_room_for_all_five() -> void:
	var world := _with_market()
	put_goods(world, WAREHOUSE, "stone", 116)
	_assert_rejected(world, "wood", true, "Kein Platz im Lager")


func test_buy_with_exactly_enough_room() -> void:
	var world := _with_market()
	put_goods(world, WAREHOUSE, "stone", 115)
	assert_eq(world.execute(Command.trade("wood", true)), "", "Genau 5 frei:")


func test_gold_is_checked_before_room() -> void:
	var world := _with_market()
	put_goods(world, WAREHOUSE, "stone", 116)
	_assert_rejected(world, "iron", true, "Nicht genug Gold (100 nötig)")


func test_sell_rejected_with_too_few_goods() -> void:
	var world := _with_market()
	put_goods(world, WAREHOUSE, "stone", 4)
	_assert_rejected(world, "stone", false, "Zu wenig Stein (5 nötig)")


func test_sell_exactly_the_whole_stock() -> void:
	var world := _with_market()
	put_goods(world, WAREHOUSE, "stone", 5)
	assert_eq(world.execute(Command.trade("stone", false)), "", "Verkauf:")
	assert_eq(world.get_stock("stone"), 0, "Alles verkauft:")
