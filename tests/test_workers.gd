extends TestCase
## Simulationstests: Untätige werden Arbeitsstätten zugeteilt und laufen zum Eingang;
## beim Abriss werden sie wieder Untätige und laufen zum Lagerfeuer.
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), erstes Warenlager (ID 2) daneben,
## Lagerfeuer (ID 3) davor mit den 4 Startbewohnern des Testszenarios.

const KEEP_ORIGIN := Vector2i(2, 2)
## Freie Stellen für Holzfäller (2×2, Eingang unten links).
const SITE := Vector2i(12, 2)
const SITE_2 := Vector2i(15, 2)
const SITE_FAR := Vector2i(12, 8)
## Obergrenze, bis jemand angekommen sein muss.
const MAX_TICKS := 500


func _founded(scenario_id := "tiny") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _steps(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


## Lässt die Welt laufen, bis der Bewohner steht (höchstens MAX_TICKS Takte).
func _until_arrived(world: GameWorld, resident: Resident) -> void:
	for i in MAX_TICKS:
		if not resident.is_moving():
			return
		world.step()
	assert_true(false, "Bewohner %d ist nach %d Takten nicht angekommen" % [resident.id, MAX_TICKS])


func _workplace_ids(world: GameWorld) -> Array[int]:
	var result: Array[int] = []
	for resident in world.get_residents():
		result.append(resident.workplace_id)
	return result


## Setzt das Gelände auf dem Rand des Rechtecks (Ecken eingeschlossen).
func _set_border(world: GameWorld, top_left: Vector2i, bottom_right: Vector2i, terrain: String) -> void:
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			if x == top_left.x or x == bottom_right.x or y == top_left.y or y == bottom_right.y:
				world.map.set_terrain(Vector2i(x, y), terrain)


## Wassergraben rund um SITE_FAR; der Holzfäller dort ist nicht erreichbar.
func _moat(world: GameWorld, terrain := "water") -> void:
	_set_border(world, SITE_FAR - Vector2i(1, 1), SITE_FAR + Vector2i(2, 3), terrain)


func test_new_workplace_gets_idle_with_smallest_id() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	world.step()
	assert_eq(_workplace_ids(world), [id, 0, 0, 0] as Array[int], "Arbeitsstätten der Bewohner:")
	assert_eq(world.get_idle_count(), 3, "Untätige:")
	assert_eq(world.get_workers(id).size(), 1, "Arbeiter:")


func test_workplaces_in_id_order() -> void:
	var world := _founded()
	var first := build(world, "woodcutter", SITE)
	var second := build(world, "woodcutter", SITE_2)
	world.step()
	assert_eq(_workplace_ids(world), [first, second, 0, 0] as Array[int], "Arbeitsstätten der Bewohner:")


func test_no_more_workers_than_data_says() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	_steps(world, 100)
	assert_eq(world.get_building(id).worker_slots(), 1, "Arbeiterzahl des Holzfällers:")
	assert_eq(world.get_workers(id).size(), 1, "Arbeiter nach 100 Takten:")
	assert_eq(world.get_idle_count(), 3, "Untätige:")


func test_storage_gets_no_workers() -> void:
	var world := _founded()
	_steps(world, 10)
	assert_eq(world.get_idle_count(), 4, "Untätige ohne Arbeitsstätte:")


func test_no_idle_left() -> void:
	var world := found_castle(new_world("tiny_poor"))
	var id := build(world, "woodcutter", find_site(world, "woodcutter"))
	_steps(world, 10)
	assert_eq(world.get_workers(id).size(), 0, "Arbeiter ohne Bewohner:")
	assert_true(not world.get_building(id).unreachable, "Ohne Untätige gilt die Stelle nicht als unerreichbar")


func test_unreachable_workplace_gets_nobody_until_retry() -> void:
	var world := _founded()
	_moat(world)
	var id := build(world, "woodcutter", SITE_FAR)
	world.step()
	var building := world.get_building(id)
	assert_eq(world.get_workers(id).size(), 0, "Arbeiter hinter Wasser:")
	assert_true(building.unreachable, "Holzfäller gilt als nicht erreichbar")
	assert_eq(world.get_idle_count(), 4, "Untätige:")
	# Wasser weg: erst nach der Wartezeit wird erneut geprüft.
	_moat(world, "grass")
	var retry := Resident.retry_ticks()
	_steps(world, retry - 1)
	assert_eq(world.get_workers(id).size(), 0, "Arbeiter vor Ablauf der Wartezeit:")
	world.step()
	assert_eq(world.get_workers(id).size(), 1, "Arbeiter nach der Wartezeit:")
	assert_true(not building.unreachable, "Holzfäller ist wieder erreichbar")


func test_unreachable_is_cleared_when_nobody_is_idle() -> void:
	var world := _founded()
	_moat(world)
	var id := build(world, "woodcutter", SITE_FAR)
	world.step()
	assert_true(world.get_building(id).unreachable, "Erst nicht erreichbar")
	# Alle Untätigen gehen an andere Holzfäller; ohne Untätige gibt es nichts zu prüfen.
	for site: Vector2i in [SITE, SITE_2, Vector2i(6, 0), Vector2i(16, 8)]:
		build(world, "woodcutter", site)
	_steps(world, Resident.retry_ticks())
	assert_eq(world.get_idle_count(), 0, "Untätige:")
	assert_true(not world.get_building(id).unreachable, "Ohne Untätige nicht mehr „nicht erreichbar“")


func test_worker_walks_to_entrance() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	world.step()
	var worker := world.get_workers(id)[0]
	assert_true(worker.is_moving(), "Arbeiter läuft los")
	_until_arrived(world, worker)
	assert_eq(worker.tile, world.get_building(id).entrance(), "Arbeiter steht am Eingang:")


func test_worker_walks_tile_by_tile_around_obstacles() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	world.step()
	var worker := world.get_workers(id)[0]
	var ticks_per_tile := Resident.ticks_per_tile()
	var previous := worker.tile
	# Der Takt der Zuteilung zählt schon zum ersten Schritt.
	var ticks_on_step := 1
	for i in MAX_TICKS:
		if not worker.is_moving():
			break
		world.step()
		ticks_on_step += 1
		if worker.tile == previous:
			continue
		var step := worker.tile - previous
		assert_true(absi(step.x) <= 1 and absi(step.y) <= 1, "Schritt %s ist kein Nachbar" % str(step))
		var expected := ticks_per_tile if step.x == 0 or step.y == 0 else roundi(ticks_per_tile * sqrt(2.0))
		assert_eq(ticks_on_step, expected, "Takte für den Schritt %s:" % str(step))
		assert_true(world.is_walkable(worker.tile, worker.level), "%s ist nicht begehbar" % str(worker.tile))
		previous = worker.tile
		ticks_on_step = 0
	assert_eq(worker.tile, world.get_building(id).entrance(), "Angekommen:")


func test_worker_reaches_entrance_only_from_outside() -> void:
	# Lager und Bergfried stehen zwischen Lagerfeuer und Holzfäller; der Weg geht drumherum.
	var world := _founded()
	var id := build(world, "woodcutter", Vector2i(6, 0))
	world.step()
	var worker := world.get_workers(id)[0]
	for i in MAX_TICKS:
		if not worker.is_moving():
			break
		world.step()
		var building := world.get_building_at(worker.tile)
		assert_true(building == null or building.is_walkable() or building.entrance() == worker.tile,
				"Bewohner auf der Grundfläche bei %s" % str(worker.tile))
	assert_eq(worker.tile, world.get_building(id).entrance(), "Angekommen:")


func test_demolished_workplace_sends_worker_back_to_campfire() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	world.step()
	var worker := world.get_workers(id)[0]
	_until_arrived(world, worker)
	assert_eq(world.execute(Command.demolish(id)), "", "Abriss:")
	assert_true(worker.is_idle(), "Arbeiter ist wieder untätig")
	assert_eq(world.get_idle_count(), 4, "Untätige:")
	assert_true(worker.is_moving(), "Er läuft zum Lagerfeuer")
	_until_arrived(world, worker)
	var campfire := world.get_building(3)
	assert_true(campfire.is_campfire(), "Gebäude 3 ist das Lagerfeuer")
	var offset := worker.tile - campfire.origin
	assert_true(offset.length_squared() <= 2, "Steht am Lagerfeuer: Versatz %s" % str(offset))
	assert_eq(world.get_residents_at(worker.tile).size(), 1, "Allein auf seiner Kachel:")
	assert_eq(world.get_building_at(worker.tile), null, "Nicht auf dem Lagerfeuer selbst:")


func test_demolish_while_walking_reassigns_nothing_but_turns_back() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	_steps(world, 12)
	var worker := world.get_resident(1)
	assert_eq(worker.workplace_id, id, "Unterwegs zum Holzfäller:")
	world.execute(Command.demolish(id))
	_until_arrived(world, worker)
	assert_true(worker.is_idle(), "Untätig")
	assert_true((worker.tile - world.get_building(3).origin).length_squared() <= 2, "Zurück am Lagerfeuer")


func test_idle_walking_back_can_be_assigned_again() -> void:
	var world := _founded()
	var id := build(world, "woodcutter", SITE)
	world.step()
	_until_arrived(world, world.get_resident(1))
	world.execute(Command.demolish(id))
	_steps(world, 3)
	var again := build(world, "woodcutter", SITE_2)
	world.step()
	assert_eq(world.get_resident(1).workplace_id, again, "Der Untätige mit der kleinsten ID:")
	_until_arrived(world, world.get_resident(1))
	assert_eq(world.get_resident(1).tile, world.get_building(again).entrance(), "Angekommen:")


func test_activity_texts() -> void:
	var world := _founded()
	var resident := world.get_resident(1)
	assert_eq(world.activity_of(resident), "Untätig", "Am Lagerfeuer:")
	var id := build(world, "woodcutter", SITE)
	world.step()
	assert_eq(world.activity_of(resident), "Holzfäller – geht zur Arbeitsstätte", "Unterwegs:")
	_until_arrived(world, resident)
	# Auf der leeren Karte gibt es keinen Baum.
	assert_eq(world.activity_of(resident), "Holzfäller – wartet: Kein Baum erreichbar", "Angekommen:")
	world.execute(Command.demolish(id))
	assert_eq(world.activity_of(resident), "Untätig – geht zum Lagerfeuer", "Nach dem Abriss:")


func test_assignment_and_arrival_are_reported() -> void:
	var world := _founded()
	var changed: Array[int] = []
	world.resident_changed.connect(func(resident_id: int) -> void: changed.append(resident_id))
	build(world, "woodcutter", SITE)
	world.step()
	assert_eq(changed, [1] as Array[int], "Gemeldet bei der Zuteilung:")
	_until_arrived(world, world.get_resident(1))
	assert_eq(changed, [1, 1] as Array[int], "Gemeldet bei der Ankunft:")


func test_save_while_walking_gives_same_course() -> void:
	var world := _founded()
	var near := build(world, "woodcutter", SITE)
	_moat(world)
	var far := build(world, "woodcutter", SITE_FAR)
	_steps(world, 13)
	assert_true(world.get_resident(1).is_moving(), "Mitten im Laufen gespeichert")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	assert_true(loaded.get_building(far).unreachable, "Unerreichbar bleibt gespeichert")
	for each: GameWorld in [world, loaded]:
		_steps(each, 30)
		each.execute(Command.demolish(near))
		_steps(each, 200)
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach Abriss und weiteren Takten:")
