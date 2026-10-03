class_name Deposit
extends RefCounted
## Ein abbaubares Vorkommen auf einer Kachel, z. B. ein Baum oder Felsen.

var type: String
var amount: int
## Nur für die Optik (Form, Größe), damit nicht alle Bäume gleich aussehen.
var variant: int


static func create(type_id: String, rng: RandomNumberGenerator) -> Deposit:
	var deposit := Deposit.new()
	deposit.type = type_id
	deposit.amount = int(GameDefs.get_instance().deposits[type_id]["amount"])
	deposit.variant = rng.randi()
	return deposit


## Dürfen Bewohner die Kachel dieses Vorkommens betreten?
func is_walkable() -> bool:
	return bool(GameDefs.get_instance().deposits[type].get("walkable", false))


## Darf es nur ein Arbeiter zugleich abbauen ("exclusive", z. B. Bäume)?
func is_exclusive() -> bool:
	return bool(GameDefs.get_instance().deposits[type].get("exclusive", false))


## Die Ware, die es liefert ("yields").
func good() -> String:
	return str(GameDefs.get_instance().deposits[type]["yields"])


## Der Name eines Vorkommenstyps, z. B. „Baum“.
static func name_of(type_id: String) -> String:
	return str(GameDefs.get_instance().deposits[type_id]["name"])


## Was ein Arbeiter beim Abbau tut, z. B. „baut Baum ab“ oder „erlegt Wild“ ("mining_text").
static func mining_text_of(type_id: String) -> String:
	var deposit_def: Dictionary = GameDefs.get_instance().deposits[type_id]
	return str(deposit_def.get("mining_text", "baut %s ab" % deposit_def["name"]))


## Die Gelände, auf denen sich ein Vorkommenstyp vermehrt ("spread" → "terrain");
## leer: auf jedem bebaubaren Gelände.
static func spread_terrains_of(type_id: String) -> Array[String]:
	var spread: Dictionary = GameDefs.get_instance().deposits[type_id].get("spread", {})
	var terrains: Array[String] = []
	terrains.assign(spread.get("terrain", []))
	return terrains


## Als reine Daten für den Spielstand (ohne Kachel – die gehört der Karte).
func to_data() -> Dictionary:
	return {"type": type, "amount": amount, "variant": variant}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Deposit:
	var deposit := Deposit.new()
	deposit.type = str(data["type"])
	deposit.amount = int(data["amount"])
	deposit.variant = int(data["variant"])
	return deposit
