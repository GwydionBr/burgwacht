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
