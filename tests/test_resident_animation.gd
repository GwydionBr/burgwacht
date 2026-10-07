extends TestCase
## Arbeitszustand und Blickrichtung folgen dem Vorkommen, unabhängig von seiner Typ-ID.


func test_worker_faces_deposit_and_chooses_its_work_animation() -> void:
	var world := empty_world("tiny")
	var resident := Resident.new()
	resident.tile = Vector2i(3, 3)
	resident.deposit_tile = Vector2i(2, 4)
	resident.task = Resident.Task.MINING
	var deposit := Deposit.new()
	deposit.type = "tree"
	world.map.add_deposit(resident.deposit_tile, deposit)
	assert_eq(ResidentAnimation.work_animation(resident, world), "axe", "Baum bearbeiten:")
	assert_eq(ResidentAnimation.work_direction(resident, 0), 3, "Zum Vorkommen:")
	deposit.type = "stone"
	assert_eq(ResidentAnimation.work_animation(resident, world), "pick", "Fels bearbeiten:")
	resident.path.append(Vector3i(4, 3, 0))
	assert_eq(ResidentAnimation.work_animation(resident, world), "", "Unterwegs keine Arbeit:")
	resident.path.clear()
	resident.task = Resident.Task.NONE
	assert_eq(ResidentAnimation.work_animation(resident, world), "", "Ohne Abbau keine Arbeit:")
	assert_eq(ResidentAnimation.work_direction(resident, 6), 6, "Untätig bleibt die Richtung:")
