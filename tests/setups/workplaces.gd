extends RefCounted
## Ansichtsprobe aller Arbeitsstätten: beschädigt, mit je einem Bewohner dahinter.
## Die Galerie enthält dieselben Typen; dieses Preset zeigt Eingänge und Verdeckung größer.

const TYPES: Array[String] = [
	"woodcutter", "quarry", "hunter", "orchard", "wheat_farm",
	"iron_mine", "mill", "bakery", "smith", "bowyer",
]


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("gallery")
	var reason := world.execute(Command.found(Vector2i(1, 1)))
	assert(reason == "", "Gründung: " + reason)
	var residents: Array[Dictionary] = []
	var next_id := 1
	for row in 2:
		var row_sum := 32 + row * 16
		var x := (row_sum - 24) / 2
		for column in 5:
			var type_id: String = TYPES[row * 5 + column]
			var size := Building.size_of(type_id).x
			var origin := Vector2i(x, row_sum - size - x)
			var id := helper.place(world, type_id, origin)
			var building := world.get_building(id)
			building.hp = building.max_hp() * 2 / 3
			var resident := Resident.new()
			resident.id = next_id
			resident.tile = origin + Vector2i(0, -1)
			residents.append(resident.to_data())
			next_id += 1
			x += size + 2
	var data := world.to_data()
	data["residents"] = residents
	data["next_resident_id"] = next_id
	return GameWorld.from_data(data)
