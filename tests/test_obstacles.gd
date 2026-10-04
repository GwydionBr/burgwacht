extends TestCase
## Simulationstests: Hindernisse und Zerstörung (ADR 0005). Feinde planen ihren Weg zum Bergfried
## mit Zerstörungskosten: Gebäude, auf denen sie nicht stehen dürfen, durchbrechen sie, wenn das
## schneller ist als der Umweg. Leere Karte tiny_siege (20×34) bzw. tiny_production (20×16);
## Bergfried (ID 1) bei (2, 2) mit der Grundfläche (2..5, 2..5), Warenlager (ID 2) bei (7..9, 2..4),
## Lagerfeuer (ID 3) bei (3, 8), Kornspeicher (ID 4) bei (7..9, 6..8).
##
## Ein Räuber (80 LP, 12 Schaden, 10 Takte je Angriff, 6 Takte je Kachel) braucht für eine volle
## Mauer (300 LP) so lange wie für 300 / 12 × 10 / 6 ≈ 41,7 Kacheln, für ein Tor (400 LP) ≈ 55,6.

const KEEP_ORIGIN := Vector2i(2, 2)
const KEEP := 1
const WAREHOUSE := 2
## Mauerlinie bei x = WALL_X über die ganze Höhe von tiny_siege, mit einer Lücke.
const WALL_X := 10
## Dort erscheint der Räuber, rechts der Mauer.
const BANDIT_START := Vector2i(14, 3)
## Obergrenze für Läufe bis zu einem Ereignis.
const MAX_TICKS := 1500


func _founded(scenario_id := "tiny_siege") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	put_goods(world, WAREHOUSE, "stone", 200)
	return world


func _wall(world: GameWorld, from: Vector2i, to: Vector2i) -> void:
	assert_eq(world.execute(Command.build_line("wall", from, to)), "", "Mauerlinie:")


## Mauer bei x = WALL_X über die ganze Höhe, nur bei gap_y offen.
func _wall_with_gap(world: GameWorld, gap_y: int) -> void:
	if gap_y > 0:
		_wall(world, Vector2i(WALL_X, 0), Vector2i(WALL_X, gap_y - 1))
	if gap_y < world.map.height - 1:
		_wall(world, Vector2i(WALL_X, gap_y + 1), Vector2i(WALL_X, world.map.height - 1))


## Lässt die Welt laufen, bis condition() gilt (höchstens MAX_TICKS Takte).
func _until(world: GameWorld, condition: Callable, what: String) -> void:
	for i in MAX_TICKS:
		if condition.call():
			return
		world.step()
	assert_true(false, "%s nach %d Takten nicht eingetreten" % [what, MAX_TICKS])


## Die beschädigten Gebäude, nach ID.
func _damaged(world: GameWorld) -> Array[int]:
	var result: Array[int] = []
	for building in world.get_buildings():
		if building.is_damaged():
			result.append(building.id)
	return result


func test_bandit_takes_a_short_open_detour_instead_of_breaking_the_wall() -> void:
	var world := _founded()
	# Umweg durch die Lücke bei y = 12: etwa 21 Kacheln statt 8 + 41,7.
	_wall_with_gap(world, 12)
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	_until(world, func() -> bool: return bandit.target_building_id == KEEP, "Angriff auf den Bergfried")
	assert_eq(_damaged(world), [KEEP] as Array[int], "Nur der Bergfried beschädigt:")


func test_bandit_breaks_the_wall_when_the_detour_is_too_long() -> void:
	var world := _founded()
	# Umweg durch die Lücke ganz unten: etwa 61 Kacheln statt 8 + 41,7.
	_wall_with_gap(world, world.map.height - 1)
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff")
	var target := world.get_building(bandit.target_building_id)
	assert_eq(target.type, "wall", "Greift die Mauer an:")
	assert_eq(target.origin.x, WALL_X, "Auf der Mauerlinie:")
	assert_eq(world.enemy_activity_of(bandit), "Räuber – greift Mauer an", "Tätigkeit:")
	assert_true(Combat._distance_to_building(bandit.tile, target) < 1.5, "Daneben: %s" % bandit.tile)
	assert_eq(target.hp, 300 - 12, "Erster Treffer:")


# --- Zerstörung --------------------------------------------------------------------------------

## Baut ein Gebäude dieses Typs bei origin, dessen rechte Spalte in der Mauerlinie x = WALL_X
## liegt, und schließt die Linie darüber und darunter. Liefert seine ID.
func _in_line(world: GameWorld, type_id: String, origin: Vector2i) -> int:
	var id := build(world, type_id, origin)
	var size := Building.size_of(type_id)
	assert_eq(origin.x + size.x - 1, WALL_X, "Rechte Spalte in der Linie:")
	_wall(world, Vector2i(WALL_X, 0), Vector2i(WALL_X, origin.y - 1))
	_wall(world, Vector2i(WALL_X, origin.y + size.y), Vector2i(WALL_X, world.map.height - 1))
	return id


## Ein Räuber von rechts auf Höhe von building_id zerstört es; vorher auf hp Lebenspunkte gesetzt,
## damit es schnell geht und das Gebäude sicher das billigste Hindernis ist.
func _destroy_by_bandit(world: GameWorld, building_id: int, hp := 12) -> void:
	var building := world.get_building(building_id)
	building.hp = hp
	add_enemy(world, "bandit", Vector2i(16, building.origin.y))
	_until(world, func() -> bool: return world.get_building(building_id) == null, "Zerstörung")


func test_destroyed_storage_vanishes_with_its_goods_without_refund() -> void:
	var world := _founded()
	var armory := _in_line(world, "armory", Vector2i(WALL_X - 2, 10))
	put_goods(world, armory, "sword", 4)
	var wood := world.get_stock("wood")
	var gold := world.get_treasury()
	var removed: Array[int] = []
	world.building_removed.connect(func(id: int) -> void: removed.append(id))
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	_destroy_by_bandit(world, armory)
	assert_eq(removed, [armory] as Array[int], "Abgemeldet:")
	assert_true(notices.has("Waffenkammer zerstört"), "Meldung: %s" % str(notices))
	assert_eq(world.get_stock("sword"), 0, "Lagerinhalt verloren:")
	assert_eq(world.get_stock("wood"), wood, "Keine Erstattung in Holz:")
	assert_eq(world.get_treasury(), gold, "Keine Erstattung in Gold:")


func test_workers_of_a_destroyed_workplace_become_idle() -> void:
	var world := _founded()
	var woodcutter := _in_line(world, "woodcutter", Vector2i(WALL_X - 1, 10))
	_until(world, func() -> bool: return world.get_workers(woodcutter).size() == 1, "Holzfäller angestellt")
	var worker := world.get_workers(woodcutter)[0]
	var idle := world.get_idle_count()
	_destroy_by_bandit(world, woodcutter)
	assert_eq(worker.workplace_id, 0, "Ohne Arbeitsstätte:")
	assert_eq(world.get_idle_count(), idle + 1, "Untätige:")


func test_destroyed_house_takes_its_housing() -> void:
	var world := _founded()
	var house := _in_line(world, "house", Vector2i(WALL_X - 1, 10))
	var housing := world.get_housing()
	_destroy_by_bandit(world, house)
	assert_eq(world.get_housing(), housing - 8, "Wohnraum:")


## Gegründet, mit Waffenkammer und Kaserne links der Mauerlinie und angeworbenen Soldaten dieser
## Typen (IDs 1, 2, …).
func _with_soldiers(types: Array[String]) -> GameWorld:
	var world := _founded()
	var armory := build(world, "armory", Vector2i(2, 12))
	put_goods(world, armory, "sword", 4)
	put_goods(world, armory, "bow", 4)
	var barracks := build(world, "barracks", Vector2i(6, 12))
	for type_id in types:
		assert_eq(world.execute(Command.recruit(barracks, type_id)), "", "Anwerben:")
	return world


## Schickt den Soldaten dorthin und wartet, bis er steht.
func _place(world: GameWorld, id: int, target: Vector3i) -> void:
	assert_eq(world.execute(Command.move([id] as Array[int], target)), "", "Bewegen:")
	_until(world, func() -> bool: return world.get_resident(id).position() == target, "Ankunft")


func test_soldier_on_a_destroyed_wall_walk_lands_on_the_ground_and_is_posted_there() -> void:
	var world := _with_soldiers(["archer"] as Array[String])
	_wall(world, Vector2i(WALL_X, 0), Vector2i(WALL_X, world.map.height - 1))
	build(world, "stairs", Vector2i(WALL_X - 1, 10))
	var archer := world.get_resident(1)
	var spot := Vector2i(WALL_X, 11)
	_place(world, 1, Vector3i(spot.x, spot.y, Figure.Level.WALL_WALK))
	var wall := world.get_building_at(spot).id
	_destroy_by_bandit(world, wall)
	assert_eq(archer.position(), Figure.ground(spot), "Darunter am Boden:")
	assert_eq(archer.post, archer.position(), "Neuer Posten:")
	assert_eq(archer.hp, 50, "Ohne Schaden:")


# --- Wahl des Hindernisses und Neuplanen -------------------------------------------------------

## Mauerlinie mit einem Tor bei (WALL_X, 11) mit diesen Lebenspunkten (dahinter frei); ein
## Räuber davor. Liefert den Typ des Gebäudes, das er angreift.
func _gate_or_wall(gate_hp: int) -> String:
	var world := _founded()
	_wall_with_gap(world, 11)
	var gate := build(world, "gate", Vector2i(WALL_X, 11))
	world.get_building(gate).hp = gate_hp
	var bandit := add_enemy(world, "bandit", Vector2i(14, 11))
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff")
	return world.get_building(bandit.target_building_id).type


func test_damaged_gate_is_preferred_over_a_full_wall_once_it_is_cheaper() -> void:
	assert_eq(_gate_or_wall(400), "wall", "Volles Tor (≈ 55,6) teurer als die Mauer daneben (≈ 41,7):")
	assert_eq(_gate_or_wall(240), "gate", "Angeschlagenes Tor (≈ 33,3) billiger:")


func test_bandit_walks_on_through_the_destroyed_wall() -> void:
	var world := _founded()
	_wall_with_gap(world, world.map.height - 1)
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff auf die Mauer")
	var wall := bandit.target_building_id
	_until(world, func() -> bool: return bandit.target_building_id == KEEP, "Angriff auf den Bergfried")
	assert_eq(world.get_building(wall), null, "Mauer zerstört")
	assert_eq(_damaged(world), [KEEP] as Array[int], "Sonst nichts beschädigt:")


func test_bandit_replans_after_building_and_demolishing() -> void:
	var world := _founded()
	_wall_with_gap(world, 12)
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	for i in 10:
		world.step()
	# Die Lücke wird geschlossen: Der Umweg ist zu lang, er greift die Mauer an.
	build(world, "wall", Vector2i(WALL_X, 12))
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff auf die Mauer")
	var wall := world.get_building(bandit.target_building_id)
	assert_eq(wall.type, "wall", "Mauer:")
	# Die angegriffene Mauer wird abgerissen: Er läuft durch die neue Lücke.
	assert_eq(world.execute(Command.demolish(wall.id)), "", "Abriss:")
	assert_true(bandit.is_moving(), "Plant neu")
	_until(world, func() -> bool: return bandit.target_building_id == KEEP, "Angriff auf den Bergfried")
	assert_eq(_damaged(world), [KEEP] as Array[int], "Sonst nichts beschädigt:")


func test_soldier_takes_priority_over_the_obstacle() -> void:
	var world := _with_soldiers(["swordsman"] as Array[String])
	_wall_with_gap(world, world.map.height - 1)
	# Der Schwertkämpfer geht durch die Lücke unten hinaus, außer Sicht des Räubers.
	_place(world, 1, Figure.ground(Vector2i(16, 26)))
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff auf die Mauer")
	assert_eq(world.execute(Command.move([1] as Array[int], Figure.ground(Vector2i(14, 6)))), "", "Bewegen:")
	_until(world, func() -> bool: return bandit.target_id == 1, "Räuber greift den Soldaten an")
	assert_eq(bandit.target_building_id, 0, "Lässt von der Mauer ab:")


func test_save_and_load_while_breaking_a_wall_continues_the_same() -> void:
	var world := _founded()
	_wall_with_gap(world, world.map.height - 1)
	var bandit := add_enemy(world, "bandit", BANDIT_START)
	_until(world, func() -> bool: return bandit.target_building_id != 0, "Angriff auf die Mauer")
	var wall := bandit.target_building_id
	for i in 5:
		world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	for i in 400:
		world.step()
		loaded.step()
	assert_eq(world.get_building(wall), null, "Mauer inzwischen zerstört")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Gleicher Verlauf:")
	assert_eq(loaded.to_data(), world.to_data(), "Gleiche Daten:")
