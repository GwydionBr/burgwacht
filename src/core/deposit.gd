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
