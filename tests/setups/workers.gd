extends RefCounted
## Vergrößerte Ansichtsprobe: zwei Arbeiter zum Vorkommen und alle Warenbündel.


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("gallery")
	world.execute(Command.found(Vector2i(1, 1)))
	var residents: Array[Dictionary] = []
	for index in 2:
		var resident := Resident.new()
		resident.id = index + 1
		resident.workplace_id = helper.place(world, "woodcutter" if index == 0 else "quarry", Vector2i(2 + index * 5, 8))
		resident.tile = Vector2i(12 + index * 4, 12 - index * 4)
		resident.deposit_tile = resident.tile + Vector2i(0, -1)
		resident.task = Resident.Task.MINING
		resident.timer = 10000
		var deposit := Deposit.new()
		deposit.type = "tree" if index == 0 else "stone"
		deposit.amount = 100
		world.map.add_deposit(resident.deposit_tile, deposit)
		residents.append(resident.to_data())
	var data := world.to_data()
	data["residents"] = residents
	data["next_resident_id"] = 3
	return GameWorld.from_data(data)


static func decorate(scene: Node2D, clock: GameClock) -> void:
	var goods: Node2D = load("res://tests/setups/gallery_goods.gd").new()
	goods.call("setup", clock)
	scene.add_child(goods)
