class_name SoldierType
extends RefCounted
## Soldatentypen aus data/units.json (Einträge mit "kind": "soldier") und ihre Anwerbekosten
## ("cost": Ware → Menge, dazu optional "gold" aus dem Schatz – wie die Baukosten der Gebäude).
## Name, Kampfwerte, Gehgeschwindigkeit und Farbe liefert FighterType.

const KIND := "soldier"


## Die Soldatentypen in Datenreihenfolge.
static func ids() -> Array[String]:
	return FighterType.ids_of_kind(KIND)


static func is_soldier_type(type_id: String) -> bool:
	return FighterType.is_kind(type_id, KIND)


## Anwerbekosten in Waren: Ware → Menge (ohne Gold).
static func goods_cost_of(type_id: String) -> Dictionary[String, int]:
	return GameWorld.goods_in(_def(type_id)["cost"])


## Anwerbekosten in Gold aus dem Schatz (0, wenn keins).
static func gold_cost_of(type_id: String) -> int:
	return GameWorld.gold_in(_def(type_id)["cost"])


## Die Waren, die zum Anwerben irgendeines Soldatentyps gebraucht werden (die Waffen), in der
## Reihenfolge der Soldatentypen.
static func weapons() -> Array[String]:
	var result: Array[String] = []
	for type_id in ids():
		for good: String in goods_cost_of(type_id):
			if not result.has(good):
				result.append(good)
	return result


static func _def(type_id: String) -> Dictionary:
	return GameDefs.get_instance().units[type_id]
