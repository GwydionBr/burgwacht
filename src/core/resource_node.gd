class_name ResourceNode
extends RefCounted
## Ein abbaubares Vorkommen auf einer Kachel, z. B. ein Baum oder Felsen.

var type: String
var amount: int
## Nur für die Optik (Form, Größe), damit nicht alle Bäume gleich aussehen.
var variant: int


static func create(type_id: String, rng: RandomNumberGenerator) -> ResourceNode:
	var node := ResourceNode.new()
	node.type = type_id
	node.amount = int(GameDefs.get_instance().resource_nodes[type_id]["amount"])
	node.variant = rng.randi()
	return node
