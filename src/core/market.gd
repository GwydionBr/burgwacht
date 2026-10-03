class_name Market
extends RefCounted
## Handel zu festen Preisen aus data/goods.json: Kaufpreis `buy` und Verkaufspreis `sell`
## in Gold pro Einheit. Waren ohne beide Preise sind nicht handelbar. Die Menge je Handel steht
## in data/market.json.


## Einheiten je Handel.
static func trade_amount() -> int:
	return int(GameDefs.get_instance().market["trade_amount"])


static func is_tradable(good: String) -> bool:
	var def: Dictionary = GameDefs.get_instance().goods[good]
	return def.has("buy") and def.has("sell")


## Gold pro gekaufter Einheit (0 bei nicht handelbaren Waren).
static func buy_price(good: String) -> int:
	return int(GameDefs.get_instance().goods[good].get("buy", 0))


## Gold pro verkaufter Einheit (0 bei nicht handelbaren Waren).
static func sell_price(good: String) -> int:
	return int(GameDefs.get_instance().goods[good].get("sell", 0))
