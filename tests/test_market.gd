extends TestCase
## Marktdaten: Kauf- und Verkaufspreise je Ware aus goods.json, Lagerarten für die Titelleiste.

## Startwerte aus der Spezifikation (Meilenstein 6): Ware → [Kauf, Verkauf].
const PRICES := {
	"wood": [4, 2],
	"stone": [8, 4],
	"iron": [20, 10],
	"wheat": [8, 4],
	"apples": [8, 4],
	"meat": [8, 4],
}


func test_prices_from_the_goods_data() -> void:
	for good: String in PRICES:
		assert_true(Market.is_tradable(good), "%s ist handelbar" % good)
		assert_eq([Market.buy_price(good), Market.sell_price(good)], PRICES[good], "Preise %s:" % good)


func test_buying_costs_more_than_selling_brings() -> void:
	for good: String in GameDefs.get_instance().goods:
		if Market.is_tradable(good):
			assert_true(Market.buy_price(good) > Market.sell_price(good), "Kauf über Verkauf: %s" % good)


func test_goods_without_prices_are_not_tradable() -> void:
	var goods := GameDefs.get_instance().goods
	goods["test_relic"] = { "name": "Reliquie", "storage": "warehouse", "color": "#ffffff" }
	assert_true(not Market.is_tradable("test_relic"), "Ohne Preise nicht handelbar")
	goods["test_relic"]["buy"] = 10
	assert_true(not Market.is_tradable("test_relic"), "Nur Kaufpreis reicht nicht")
	goods.erase("test_relic")


func test_a_trade_is_five_units() -> void:
	assert_eq(Market.TRADE_AMOUNT, 5, "Einheiten je Handel:")


func test_storage_types_in_goods_order() -> void:
	assert_eq(Building.storage_types(), ["warehouse", "granary"] as Array[String], "Lagerarten:")
