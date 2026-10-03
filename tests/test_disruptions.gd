extends TestCase
## Simulationstests: Bewohner kommen mit einer sich ändernden Burg zurecht – Bauen auf
## Bewohnern, versperrte Wege, verschwundene Vorkommen, Abriss mitten im Arbeitsgang.
## Leere Karte (nur Wiese); Bergfried (ID 1) bei (2, 2), erstes Warenlager (ID 2) bei (7, 2),
## Lagerfeuer (ID 3) bei (3, 8) mit den 4 Startbewohnern, erster Kornspeicher (ID 4) bei (7, 6).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const CAMPFIRE := 3
## Holzfäller (2×2) mit Eingang bei (12, 3), daneben ein Baum.
const WOODCUTTER_SITE := Vector2i(12, 2)
const TREE := Vector2i(14, 6)
## Holzfäller weiter weg, damit der Weg dorthin lang genug zum Versperren ist.
const SITE_FAR := Vector2i(15, 10)
## Holzfäller über einem Untätigen, daneben entsteht eine abgeschlossene Tasche.
const POCKET_SITE := Vector2i(10, 12)
## Obergrenze für einen ganzen Arbeitsgang.
const MAX_TICKS := 1000


func _founded() -> GameWorld:
	var world := empty_world()
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _steps(world: GameWorld, ticks: int) -> void:
	for i in ticks:
		world.step()


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte); false, wenn nie.
func _until(world: GameWorld, condition: Callable, what: String) -> bool:
	for i in MAX_TICKS:
		if condition.call():
			return true
		world.step()
	assert_true(false, "Nach %d Takten nicht erreicht: %s" % [MAX_TICKS, what])
	return false


## Prüft, dass jeder Bewohner auf einer begehbaren Kachel steht und sein Weg frei ist.
func _assert_all_walkable(world: GameWorld, when: String) -> void:
	for resident in world.get_residents():
		assert_true(world.is_walkable(resident.tile, resident.level),
				"%s: Bewohner %d steht auf %s" % [when, resident.id, str(resident.tile)])
		for position in resident.path:
			assert_true(world.is_walkable(Vector2i(position.x, position.y), resident.level),
					"%s: Weg von Bewohner %d führt über %s" % [when, resident.id, str(position)])


## Ursprung eines Holzfällers (2×2), dessen Grundfläche die Kachel bedeckt (nicht als
## Eingang) und der dort gebaut werden darf; sonst GameWorld.NO_SITE.
func _woodcutter_covering(world: GameWorld, tile: Vector2i) -> Vector2i:
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var origin := tile - offset
		var entrance := Building.create(0, "woodcutter", origin).entrance()
		if entrance != tile and world.build_error("woodcutter", origin) == "":
			return origin
	return GameWorld.NO_SITE


## Ein Arbeiter (Bewohner 1) unterwegs zum weit entfernten Holzfäller; liefert dessen ID.
func _walking_to_far_site(world: GameWorld) -> int:
	var id := build(world, "woodcutter", SITE_FAR)
	_steps(world, 3)
	assert_true(world.get_resident(1).is_moving(), "Arbeiter läuft")
	return id


func test_building_on_idle_moves_them_to_nearest_walkable_tile() -> void:
	var world := _founded()
	var resident := world.get_resident(2)
	var old_tile := resident.tile
	var origin := _woodcutter_covering(world, old_tile)
	assert_true(origin != GameWorld.NO_SITE, "Holzfäller über Bewohner 2 baubar")
	build(world, "woodcutter", origin)
	_assert_all_walkable(world, "Nach dem Bau")
	var offset := resident.tile - old_tile
	assert_true(offset.length_squared() <= 2, "Nur auf die nächste Kachel ausgewichen: Versatz %s" % str(offset))
	assert_eq(world.get_building_at(resident.tile), null, "Nicht auf ein Gebäude:")


func test_displacement_order_is_fixed() -> void:
	# Zwei gleiche Welten, gleicher Bau: gleiche Ausweichkacheln.
	var tiles: Array[Array] = []
	for i in 2:
		var world := _founded()
		build(world, "woodcutter", _woodcutter_covering(world, world.get_resident(2).tile))
		var each: Array[Vector2i] = []
		for resident in world.get_residents():
			each.append(resident.tile)
		tiles.append(each)
	assert_eq(tiles[1], tiles[0], "Kacheln der Bewohner:")


func test_building_on_walking_resident_replans() -> void:
	var world := _founded()
	var id := _walking_to_far_site(world)
	var worker := world.get_resident(1)
	var origin := _woodcutter_covering(world, worker.tile)
	assert_true(origin != GameWorld.NO_SITE, "Holzfäller über dem Arbeiter baubar")
	build(world, "woodcutter", origin)
	_assert_all_walkable(world, "Nach dem Bau")
	assert_true(worker.is_moving(), "Läuft weiter")
	_until(world, func() -> bool: return not worker.is_moving(), "Ankunft")
	assert_eq(worker.tile, world.get_building(id).entrance(), "Angekommen:")


func test_building_across_path_replans_at_once() -> void:
	var world := _founded()
	var id := _walking_to_far_site(world)
	var worker := world.get_resident(1)
	var ahead := worker.path[worker.path.size() / 2]
	var origin := _woodcutter_covering(world, Vector2i(ahead.x, ahead.y))
	assert_true(origin != GameWorld.NO_SITE, "Holzfäller auf dem Weg baubar")
	build(world, "woodcutter", origin)
	_assert_all_walkable(world, "Gleich nach dem Bau")
	_until(world, func() -> bool: return not worker.is_moving(), "Ankunft")
	assert_eq(worker.tile, world.get_building(id).entrance(), "Angekommen:")


func test_blocked_next_tile_replans() -> void:
	var world := _founded()
	var id := _walking_to_far_site(world)
	var worker := world.get_resident(1)
	# Auf der übernächsten Kachel erscheint ein Felsen (wie ein neues Vorkommen).
	var ahead := worker.path[1]
	var rock := Vector2i(ahead.x, ahead.y)
	add_deposit(world, rock, "stone")
	for i in MAX_TICKS:
		if not worker.is_moving():
			break
		world.step()
		assert_true(worker.tile != rock, "Läuft nicht durch den Felsen")
	assert_eq(worker.tile, world.get_building(id).entrance(), "Angekommen:")


func test_tree_growing_across_path_replans() -> void:
	var world := _founded()
	var id := _walking_to_far_site(world)
	var worker := world.get_resident(1)
	var start := worker.tile
	var next := Vector2i(worker.path[0].x, worker.path[0].y)
	var ahead := Vector2i(worker.path[1].x, worker.path[1].y)
	# Bäume seitlich neben dem Bewohner und neben der übernächsten Kachel; die andere Seite bleibt frei.
	var side := Vector2i(signi(next.y - start.y), -signi(next.x - start.x))
	add_deposit(world, start + side, "tree")
	add_deposit(world, ahead + side, "tree")
	# Einen Takt lang wächst sicher überall Wald, wo es darf.
	var spread: Dictionary = GameDefs.get_instance().deposits["tree"]["spread"]
	var old_spread := spread.duplicate()
	spread["interval_ticks"] = 1
	spread["chance"] = 1.0
	world.step()
	spread.assign(old_spread)
	assert_true(world.map.get_deposit(ahead) != null, "Baum auf dem Weg gewachsen")
	assert_true(world.map.get_deposit(next) != null, "Auch auf der nächsten Kachel")
	assert_eq(world.map.get_deposit(start), null, "Kein Baum unter dem Bewohner")
	# Danach geht er zum neuen Wald fällen; gezählt wird nur der Weg bis zur Arbeitsstätte.
	var entrance := world.get_building(id).entrance()
	for i in MAX_TICKS:
		if worker.tile == entrance:
			break
		world.step()
		assert_eq(world.map.get_deposit(worker.tile), null, "Läuft nicht durch Bäume auf %s:" % str(worker.tile))
	assert_eq(worker.tile, entrance, "Angekommen:")


func test_unreachable_goal_waits_and_retries() -> void:
	var world := _founded()
	var id := _walking_to_far_site(world)
	var worker := world.get_resident(1)
	# Felsen rund um den Holzfäller: der Eingang ist nicht mehr erreichbar.
	var ring: Array[Vector2i] = []
	for y in range(SITE_FAR.y - 1, SITE_FAR.y + 3):
		for x in range(SITE_FAR.x - 1, SITE_FAR.x + 3):
			var tile := Vector2i(x, y)
			if world.get_building_at(tile) == null and world.map.in_bounds(tile):
				ring.append(tile)
				add_deposit(world, tile, "stone")
	_until(world, func() -> bool: return not worker.is_moving(), "Stehenbleiben")
	assert_eq(worker.task, Resident.Task.TO_WORKPLACE, "Will weiter zur Arbeitsstätte:")
	assert_eq(worker.workplace_id, id, "Bleibt Arbeiter:")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Weg versperrt", "Tätigkeit:")
	_assert_all_walkable(world, "Beim Warten")
	var waiting_at := worker.tile
	_steps(world, Resident.retry_ticks() / 2)
	assert_eq(worker.tile, waiting_at, "Wartet auf der Stelle:")
	# Felsen weg: nach der Wartezeit geht er weiter.
	for tile in ring:
		world.map.remove_deposit(tile)
	_until(world, func() -> bool: return worker.tile == world.get_building(id).entrance(), "Ankunft nach dem Warten")


func test_trees_do_not_grow_under_residents() -> void:
	var world := _founded()
	var resident := world.get_resident(1)
	# Bäume rund um den Bewohner; bei sicherem Wachstum bleibt nur seine Kachel frei.
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1)]:
		add_deposit(world, resident.tile + offset, "tree")
	var spread: Dictionary = GameDefs.get_instance().deposits["tree"]["spread"]
	var old_chance: float = spread["chance"]
	spread["chance"] = 1.0
	_steps(world, int(spread["interval_ticks"]))
	spread["chance"] = old_chance
	assert_eq(world.map.get_deposit(resident.tile), null, "Kein Baum unter dem Bewohner")
	assert_true(world.map.get_deposit(resident.tile + Vector2i(-1, 0)) != null, "Daneben wächst einer")


func test_demolished_workplace_mid_work_leaves_no_half_state() -> void:
	for task: Resident.Task in [Resident.Task.TO_DEPOSIT, Resident.Task.MINING, Resident.Task.RETURNING,
			Resident.Task.PROCESSING, Resident.Task.TO_STORAGE]:
		var world := _founded()
		add_deposit(world, TREE, "tree")
		var id := build(world, "woodcutter", WOODCUTTER_SITE)
		var worker := world.get_resident(1)
		_until(world, func() -> bool: return worker.task == task, "Arbeitsgang %d" % task)
		assert_eq(world.execute(Command.demolish(id)), "", "Abriss (%d):" % task)
		assert_true(worker.is_idle(), "Untätig (%d)" % task)
		assert_eq([worker.task, worker.carried_amount, worker.timer], [Resident.Task.NONE, 0, 0],
				"Kein Arbeitsgang, keine Ware (%d):" % task)
		assert_true(not worker.is_targeting_deposit(TREE), "Baum nicht mehr reserviert (%d)" % task)
		assert_true(not worker.is_inside_building(), "Sichtbar (%d)" % task)
		_until(world, func() -> bool: return not worker.is_moving(), "Ankunft am Lagerfeuer")
		var offset := worker.tile - world.get_building(CAMPFIRE).origin
		assert_true(offset.length_squared() <= 2, "Am Lagerfeuer (%d): Versatz %s" % [task, str(offset)])
		assert_eq(world.activity_of(worker), "Untätig", "Tätigkeit (%d):" % task)


func test_demolished_storage_on_the_way_replans_at_once() -> void:
	var world := _founded()
	assert_eq(build(world, "warehouse", Vector2i(10, 1)), 5, "Zweites Lager:")
	add_deposit(world, Vector2i(16, 7), "tree")
	build(world, "woodcutter", Vector2i(15, 2))
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE, "Weg zum Lager")
	assert_eq(worker.storage_id, 5, "Zum näheren Lager:")
	assert_eq(world.execute(Command.demolish(5)), "", "Abriss des Lagers:")
	assert_eq(worker.task, Resident.Task.TO_STORAGE, "Weiter mit der Ware unterwegs:")
	assert_eq(worker.storage_id, WAREHOUSE, "Gleich zum anderen Lager:")
	assert_eq(worker.destination(), world.get_building(WAREHOUSE).entrance(), "Weg zum anderen Lager:")
	var wood_before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 4, "Lieferung")


func test_vanished_target_deposit_seeks_another_at_once() -> void:
	var world := _founded()
	add_deposit(world, TREE, "tree")
	var other := Vector2i(16, 6)
	add_deposit(world, other, "tree")
	build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_DEPOSIT, "Weg zum Baum")
	assert_eq(worker.deposit_tile, TREE, "Erst der nähere Baum:")
	world.map.remove_deposit(TREE)
	world.step()
	assert_eq(worker.task, Resident.Task.TO_DEPOSIT, "Weiter unterwegs:")
	assert_eq(worker.deposit_tile, other, "Zum anderen Baum:")


func test_vanished_deposit_while_mining_seeks_another_at_once() -> void:
	var world := _founded()
	add_deposit(world, TREE, "tree")
	build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau")
	world.map.remove_deposit(TREE)
	var other := Vector2i(16, 6)
	add_deposit(world, other, "tree")
	world.step()
	assert_eq(worker.task, Resident.Task.TO_DEPOSIT, "Sucht gleich einen neuen:")
	assert_eq(worker.deposit_tile, other, "Zum anderen Baum:")
	assert_eq(worker.carried_amount, 0, "Nichts abgebaut:")


func test_building_on_miner_seeks_deposit_again() -> void:
	var world := _founded()
	add_deposit(world, TREE, "tree")
	build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau")
	var origin := _woodcutter_covering(world, worker.tile)
	assert_true(origin != GameWorld.NO_SITE, "Holzfäller über dem Abbauenden baubar")
	build(world, "woodcutter", origin)
	_assert_all_walkable(world, "Nach dem Bau")
	assert_eq([worker.task, worker.deposit_tile], [Resident.Task.TO_DEPOSIT, TREE], "Geht wieder zum Baum:")
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau von neuer Stelle")
	assert_true(world.is_walkable(worker.tile, worker.level), "Baut von begehbarer Kachel ab")


func test_cut_off_from_workplace_without_deposit_waits_visibly() -> void:
	var world := _founded()
	add_deposit(world, TREE, "tree")
	var id := build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.task == Resident.Task.MINING, "Abbau")
	# Felsen vor dem Eingang (12, 3), dann verschwindet der Baum.
	var blockers: Array[Vector2i] = [Vector2i(11, 3), Vector2i(12, 4)]
	for tile in blockers:
		add_deposit(world, tile, "stone")
	world.map.remove_deposit(TREE)
	world.step()
	assert_true(not worker.is_moving(), "Bleibt stehen")
	assert_true(not worker.is_inside_building(), "Nicht unsichtbar draußen")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Weg versperrt", "Tätigkeit:")
	for tile in blockers:
		world.map.remove_deposit(tile)
	_until(world, func() -> bool: return worker.tile == world.get_building(id).entrance() and not worker.is_moving(),
			"Zurück in der Arbeitsstätte")
	_steps(world, 1)
	assert_eq(worker.task, Resident.Task.WAITING_FOR_DEPOSIT, "Wartet dort auf einen Baum:")


## Holzfäller am WOODCUTTER_SITE, Arbeiter mit Holz auf dem Weg ins Warenlager und schon an der
## Kachel vor dem Eingang vorbei; dann ist das Lager voll und der Eingang des Holzfällers versperrt
## (ein Felsen vor dem Eingang genügt). Liefert die Felsen.
func _full_storage_and_cut_off(world: GameWorld) -> Array[Vector2i]:
	add_deposit(world, TREE, "tree")
	var woodcutter := world.get_building(build(world, "woodcutter", WOODCUTTER_SITE))
	var worker := world.get_resident(1)
	var at_entrance: Array[Vector2i] = [woodcutter.entrance(), woodcutter.entrance_front()]
	_until(world, func() -> bool: return worker.task == Resident.Task.TO_STORAGE and not at_entrance.has(worker.tile),
			"Unterwegs zum Lager")
	var warehouse := world.get_building(WAREHOUSE)
	# Mit Stein bis unters Dach auffüllen.
	put_goods(world, WAREHOUSE, "stone", warehouse.capacity() - warehouse.stored() + warehouse.contents.get("stone", 0))
	var blockers: Array[Vector2i] = [woodcutter.entrance_front()]
	for tile in blockers:
		add_deposit(world, tile, "stone")
	return blockers


func test_full_storage_and_cut_off_from_workplace_waits_visibly() -> void:
	var world := _founded()
	var blockers := _full_storage_and_cut_off(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return not worker.is_moving(), "Stehenbleiben")
	assert_true(worker.is_blocked(), "Versperrt")
	assert_eq(worker.carried_amount, 4, "Behält die Ware:")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Weg versperrt", "Tätigkeit:")
	_assert_all_walkable(world, "Beim Warten")
	# Weg frei, Lager noch voll: nach der Wartezeit geht er zur Arbeitsstätte und wartet dort.
	for tile in blockers:
		world.map.remove_deposit(tile)
	_until(world, func() -> bool: return worker.task == Resident.Task.WAITING_FOR_STORAGE and not worker.is_moving(),
			"Warten an der Arbeitsstätte")
	assert_eq(worker.tile, world.get_building(worker.workplace_id).entrance(), "An der Arbeitsstätte:")
	assert_eq(world.activity_of(worker), "Holzfäller – wartet: Lager voll", "Tätigkeit:")


func test_full_storage_and_cut_off_delivers_once_storage_has_room() -> void:
	var world := _founded()
	_full_storage_and_cut_off(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.is_blocked(), "Versperrt")
	# Platz im Lager, Arbeitsstätte weiter versperrt: nach der Wartezeit liefert er ab.
	put_goods(world, WAREHOUSE, "stone", 0)
	var wood_before := world.get_stock("wood")
	_until(world, func() -> bool: return world.get_stock("wood") == wood_before + 4, "Lieferung")
	assert_eq(worker.carried_amount, 0, "Ware abgeliefert:")


func test_save_while_full_storage_and_cut_off_gives_same_course() -> void:
	var world := _founded()
	_full_storage_and_cut_off(world)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.is_blocked(), "Versperrt")
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	assert_eq(loaded.activity_of(loaded.get_resident(1)), "Holzfäller – wartet: Weg versperrt", "Tätigkeit nach dem Laden:")
	for each: GameWorld in [world, loaded]:
		put_goods(each, WAREHOUSE, "stone", 0)
		_steps(each, 300)
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten:")


## Holzfäller am WOODCUTTER_SITE, Arbeiter angekommen, dann Felsen rund um ihn und Abriss:
## Der neue Untätige kommt nicht zum Lagerfeuer. Liefert die Felsen.
func _idle_walled_in(world: GameWorld) -> Array[Vector2i]:
	var id := build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.workplace_id == id and not worker.is_moving(), "Ankunft")
	var rocks: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x != 0 or y != 0:
				rocks.append(worker.tile + Vector2i(x, y))
				add_deposit(world, worker.tile + Vector2i(x, y), "stone")
	assert_eq(world.execute(Command.demolish(id)), "", "Abriss:")
	assert_true(worker.is_idle() and not worker.is_moving(), "Untätig, kommt nicht weg")
	return rocks


func test_blocked_idle_retries_way_to_campfire() -> void:
	var world := _founded()
	var rocks := _idle_walled_in(world)
	var idle := world.get_resident(1)
	for tile in rocks:
		world.map.remove_deposit(tile)
	_steps(world, Resident.retry_ticks())
	assert_true(idle.is_moving(), "Nach der Wartezeit unterwegs zum Lagerfeuer")
	_until(world, func() -> bool: return not idle.is_moving(), "Ankunft am Lagerfeuer")
	var offset := idle.tile - world.get_building(CAMPFIRE).origin
	assert_true(offset.length_squared() <= 2, "Am Lagerfeuer: Versatz %s" % str(offset))


func test_blocked_idle_can_be_assigned_at_once() -> void:
	var world := _founded()
	var rocks := _idle_walled_in(world)
	var idle := world.get_resident(1)
	for tile in rocks:
		world.map.remove_deposit(tile)
	var id := build(world, "woodcutter", Vector2i(15, 2))
	world.step()
	assert_eq(idle.workplace_id, id, "Eingeteilt:")
	_until(world, func() -> bool: return not idle.is_moving(), "Ankunft")
	assert_eq(idle.tile, world.get_building(id).entrance(), "An der neuen Arbeitsstätte:")
	_steps(world, 1)
	assert_eq(idle.task, Resident.Task.WAITING_FOR_DEPOSIT, "Arbeitet dort weiter:")


func test_save_while_waiting_for_blocked_way_gives_same_course() -> void:
	var world := _founded()
	_walking_to_far_site(world)
	var worker := world.get_resident(1)
	var ahead := worker.path[0]
	add_deposit(world, Vector2i(ahead.x, ahead.y), "stone")
	_steps(world, 7)
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for each: GameWorld in [world, loaded]:
		_steps(each, 300)
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren Takten:")


## Stellt Untätigen 2 auf POCKET_SITE; die Kachel direkt über ihm ist nach dem Bau eines
## Holzfällers dort ringsum von Felsen und Grundfläche eingeschlossen. Liefert sie.
func _idle_next_to_pocket(world: GameWorld) -> Vector2i:
	var idle := world.get_resident(2)
	idle.tile = POCKET_SITE
	var pocket := POCKET_SITE + Vector2i(0, -1)
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
			Vector2i(1, 0), Vector2i(-1, 1)]:
		add_deposit(world, pocket + offset, "stone")
	return pocket


func test_displaced_resident_skips_closed_pocket() -> void:
	var world := _founded()
	var pocket := _idle_next_to_pocket(world)
	var idle := world.get_resident(2)
	build(world, "woodcutter", POCKET_SITE)
	_assert_all_walkable(world, "Nach dem Bau")
	assert_true(idle.tile != pocket, "Nicht in die abgeschlossene Tasche")
	var campfire := Figure.ground(world.get_building(CAMPFIRE).origin)
	assert_true(not Pathfinder.find_path(idle.position(), campfire, world._is_walkable_position).is_empty(),
			"Erreicht von %s aus das Lagerfeuer" % str(idle.tile))
	# Über ihm die Tasche, rechts die Grundfläche, darunter der Eingang.
	assert_eq(idle.tile, POCKET_SITE + Vector2i(0, 1), "Nächste erreichbare Kachel:")


## Umringt das Lagerfeuer mit Felsen (Bewohner dort stehen dann im Felsen; egal für die Tests).
func _wall_in_campfire(world: GameWorld) -> void:
	var campfire := world.get_building(CAMPFIRE).origin
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if x != 0 or y != 0:
				add_deposit(world, campfire + Vector2i(x, y), "stone")


func test_displaced_worker_measures_way_to_workplace() -> void:
	# Das Lagerfeuer ist abgeschnitten, die Arbeitsstätte nicht: Der Arbeiter weicht so aus,
	# dass er sie erreicht.
	var world := _founded()
	var id := build(world, "woodcutter", WOODCUTTER_SITE)
	var worker := world.get_resident(1)
	_until(world, func() -> bool: return worker.workplace_id == id and not worker.is_moving(), "Ankunft")
	var pocket := _idle_next_to_pocket(world)
	worker.tile = POCKET_SITE
	world.get_resident(2).tile = world.get_building(id).entrance()
	_wall_in_campfire(world)
	build(world, "woodcutter", POCKET_SITE)
	assert_true(worker.tile != pocket, "Nicht in die abgeschlossene Tasche")
	assert_true(not Pathfinder.find_path(worker.position(), Figure.ground(world.get_building(id).entrance()),
			world._is_walkable_position).is_empty(), "Erreicht von %s aus die Arbeitsstätte" % str(worker.tile))


func test_displaced_resident_into_pocket_when_nothing_else_reachable() -> void:
	# Ist das Lagerfeuer von nirgends erreichbar, bleibt es bei der nächsten begehbaren Kachel.
	var world := _founded()
	var pocket := _idle_next_to_pocket(world)
	_wall_in_campfire(world)
	build(world, "woodcutter", POCKET_SITE)
	assert_eq(world.get_resident(2).tile, pocket, "In der Tasche:")
