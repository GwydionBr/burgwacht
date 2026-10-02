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
