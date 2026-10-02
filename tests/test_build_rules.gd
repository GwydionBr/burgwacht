extends TestCase
## Simulationstests: Bauregeln der Gebäudetypen aus buildings.json.
## Leere Karte (nur Wiese); Bergfried bei (2, 2), das erste Warenlager (ID 2) bei (7, 2)
## mit der Grundfläche x 7–9, y 2–4, darin die Startwaren (100 Holz, 50 Stein).

const KEEP_ORIGIN := Vector2i(2, 2)
## Warenlager direkt rechts neben dem ersten (teilt die Kante x 9 | 10).
const NEXT_TO_STORAGE := Vector2i(10, 2)
## Warenlager, dessen Ecke (10, 5) nur schräg an die Ecke (9, 4) des ersten stößt.
const DIAGONAL_TO_STORAGE := Vector2i(10, 5)
## Freie Stelle mit zwei Kacheln Abstand zum ersten Warenlager.
const AWAY := Vector2i(12, 2)
const NOT_NEXT_TO_STORAGE := "Muss an ein Warenlager grenzen"
const NOT_NEXT_TO_ROCK := "Muss an Felsen grenzen"


func _founded_world() -> GameWorld:
	var world := empty_world()
	world.execute(Command.found(KEEP_ORIGIN))
	return world


func test_warehouse_next_to_warehouse_is_allowed() -> void:
	var world := _founded_world()
	assert_eq(world.execute(Command.build("warehouse", NEXT_TO_STORAGE)), "", "Grund:")


func test_warehouse_away_from_warehouse_is_rejected() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.build_error("warehouse", AWAY), NOT_NEXT_TO_STORAGE, "Abfrage:")
	assert_eq(world.execute(Command.build("warehouse", AWAY)), NOT_NEXT_TO_STORAGE, "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_diagonal_does_not_count_as_next_to() -> void:
	var world := _founded_world()
	assert_eq(world.build_error("warehouse", DIAGONAL_TO_STORAGE), NOT_NEXT_TO_STORAGE, "Nur schräg:")


func test_warehouse_next_to_a_newer_warehouse_is_allowed() -> void:
	var world := _founded_world()
	world.execute(Command.build("warehouse", NEXT_TO_STORAGE))
	assert_eq(world.build_error("warehouse", Vector2i(13, 2)), "", "An das zweite Warenlager:")


func test_warehouse_anywhere_when_no_warehouse_is_left() -> void:
	var world := _founded_world()
	put_goods(world, 2, "wood", 0)
	put_goods(world, 2, "stone", 0)
	assert_eq(world.execute(Command.demolish(2)), "", "Abriss des letzten Warenlagers:")
	assert_eq(world.execute(Command.build("warehouse", AWAY)), "", "Ohne Warenlager überall:")


func test_other_buildings_do_not_count_as_warehouse() -> void:
	var world := _founded_world()
	# Holzfäller rechts neben dem Warenlager, das neue Warenlager rechts neben dem Holzfäller.
	world.execute(Command.build("woodcutter", NEXT_TO_STORAGE))
	assert_eq(world.build_error("warehouse", Vector2i(12, 2)), NOT_NEXT_TO_STORAGE, "Neben dem Holzfäller:")


func test_quarry_next_to_rock_is_allowed() -> void:
	var world := _founded_world()
	add_deposit(world, AWAY + Vector2i(3, 1), "stone")
	assert_eq(world.execute(Command.build("quarry", AWAY)), "", "Grund:")


func test_quarry_without_rock_is_rejected() -> void:
	var world := _founded_world()
	var before := world.to_data()
	assert_eq(world.execute(Command.build("quarry", AWAY)), NOT_NEXT_TO_ROCK, "Grund:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_quarry_next_to_other_deposit_is_rejected() -> void:
	var world := _founded_world()
	add_deposit(world, AWAY + Vector2i(3, 1), "tree")
	add_deposit(world, AWAY + Vector2i(-1, 1), "iron")
	assert_eq(world.build_error("quarry", AWAY), NOT_NEXT_TO_ROCK, "Baum und Eisen zählen nicht:")


func test_quarry_with_rock_only_diagonal_is_rejected() -> void:
	var world := _founded_world()
	add_deposit(world, AWAY + Vector2i(3, -1), "stone")
	assert_eq(world.build_error("quarry", AWAY), NOT_NEXT_TO_ROCK, "Nur schräg:")


func test_woodcutter_has_no_rule() -> void:
	var world := _founded_world()
	assert_eq(world.build_error("woodcutter", AWAY), "", "Holzfäller überall:")


func test_rules_come_after_placement() -> void:
	var world := _founded_world()
	assert_eq(world.build_error("warehouse", KEEP_ORIGIN), "Bergfried im Weg", "Belegt vor Bauregel:")
	assert_eq(world.build_error("quarry", Vector2i(-1, 0)), "Außerhalb der Karte", "Karte vor Bauregel:")


func test_rules_come_before_goods() -> void:
	var world := _founded_world()
	put_goods(world, 2, "wood", 0)
	assert_eq(world.build_error("quarry", AWAY), NOT_NEXT_TO_ROCK, "Bauregel vor zu wenig Waren:")
	add_deposit(world, AWAY + Vector2i(3, 1), "stone")
	assert_eq(world.build_error("quarry", AWAY), "Zu wenig Holz (20 nötig)", "Mit Felsen dann die Waren:")


func test_adjacent_tiles_share_an_edge() -> void:
	var tiles := Building.adjacent_tiles("woodcutter", Vector2i(5, 5))
	var expected: Array[Vector2i] = [
		Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(4, 5), Vector2i(7, 5),
		Vector2i(4, 6), Vector2i(7, 6),
		Vector2i(5, 7), Vector2i(6, 7),
	]
	assert_eq(tiles, expected, "Kacheln um eine 2×2-Grundfläche ohne Ecken:")
