extends RefCounted
## Roden-Ansichtsprobe: markierte und freie Bäume, Holzfäller und ein unerreichbarer Baum.


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("gallery")
	var data := world.to_data()
	data["start_residents"] = 4
	data["start_goods"] = {"wood": 100, "stone": 50, "apples": 40}
	world = GameWorld.from_data(data)
	world.execute(Command.found(Vector2i(2, 2)))
	helper.place(world, "woodcutter", Vector2i(12, 8))
	for tile: Vector2i in [Vector2i(15, 9), Vector2i(17, 9), Vector2i(15, 12), Vector2i(17, 12), Vector2i(19, 14), Vector2i(38, 12)]:
		helper.add_deposit(world, tile, "tree")
	world.execute(Command.mark_clearing([Vector2i(17, 9), Vector2i(17, 12), Vector2i(38, 12)]))
	world.step()
	return world
