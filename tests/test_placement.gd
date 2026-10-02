extends TestCase
## Simulationstests: Darf ein Gebäude hier stehen? Prüfregeln mit Grund, in fester Reihenfolge.
## Leere Karte (nur Wiese); der Bergfried hat laut Daten 4×4 und den Eingang vorne.

const ORIGIN := Vector2i(2, 2)


func _tree() -> Deposit:
	return Deposit.create("tree", RandomNumberGenerator.new())


func _keep_front() -> Vector2i:
	return Building.front_of_entrance("keep", ORIGIN)


func test_free_site_is_allowed() -> void:
	assert_eq(empty_world().founding_error(ORIGIN), "", "Grund:")


func test_outside_map() -> void:
	var world := empty_world()
	assert_eq(world.founding_error(Vector2i(-1, 2)), "Außerhalb der Karte", "Links hinaus:")
	assert_eq(world.founding_error(Vector2i(2, world.map.height - 3)), "Außerhalb der Karte", "Unten hinaus:")


func test_terrain_must_be_buildable() -> void:
	var world := empty_world()
	world.map.set_terrain(ORIGIN + Vector2i(3, 1), "sand")
	assert_eq(world.founding_error(ORIGIN), "Ufer ist nicht bebaubar", "Grund:")


func test_no_deposits_in_footprint() -> void:
	var world := empty_world()
	world.map.add_deposit(ORIGIN + Vector2i(1, 2), _tree())
	assert_eq(world.founding_error(ORIGIN), "Baum im Weg", "Grund:")


func test_no_buildings_in_footprint() -> void:
	var world := empty_world()
	world.execute(Command.found(ORIGIN))
	assert_eq(world.placement_error("warehouse", ORIGIN + Vector2i(2, 2)), "Bergfried im Weg", "Auf dem Bergfried:")
	var storage_origin := founding_origin(world, "warehouse", ORIGIN)
	assert_eq(world.placement_error("warehouse", storage_origin + Vector2i(1, 1)), "Warenlager im Weg", "Auf dem Warenlager:")


func test_entrance_front_must_be_free() -> void:
	var world := empty_world()
	world.map.add_deposit(_keep_front(), _tree())
	assert_eq(world.founding_error(ORIGIN), "Eingang ist versperrt", "Baum vor dem Eingang:")


func test_entrance_front_must_be_walkable() -> void:
	var world := empty_world()
	world.map.set_terrain(_keep_front(), "water")
	assert_eq(world.founding_error(ORIGIN), "Eingang ist versperrt", "Wasser vor dem Eingang:")
	# Ufer ist begehbar, aber nicht bebaubar – vor dem Eingang reicht begehbar.
	world.map.set_terrain(_keep_front(), "sand")
	assert_eq(world.founding_error(ORIGIN), "", "Ufer vor dem Eingang:")


func test_entrance_front_must_be_on_map() -> void:
	var world := empty_world()
	var origin := Vector2i(2, world.map.height - 4)
	assert_eq(world.founding_error(origin), "Eingang ist versperrt", "Eingang zum Kartenrand:")


func test_entrance_front_must_not_be_a_building() -> void:
	var world := empty_world()
	var keep_origin := Vector2i(2, 6)
	world.execute(Command.found(keep_origin))
	# Ein Warenlager über dem Bergfried, dessen Eingang auf ihn zeigt.
	var origin := keep_origin + Vector2i(0, -3)
	assert_true(Building.front_of_entrance("warehouse", origin) in Building.footprint("keep", keep_origin), "Hilfsprüfung: Eingang zeigt auf den Bergfried")
	assert_eq(world.placement_error("warehouse", origin), "Eingang ist versperrt", "Grund:")


func test_rules_are_checked_in_fixed_order() -> void:
	var world := empty_world()
	world.map.add_deposit(_keep_front(), _tree())
	assert_eq(world.founding_error(ORIGIN), "Eingang ist versperrt", "Nur Eingang:")
	world.map.add_deposit(ORIGIN + Vector2i(3, 3), _tree())
	assert_eq(world.founding_error(ORIGIN), "Baum im Weg", "Vorkommen vor Eingang:")
	world.map.set_terrain(ORIGIN + Vector2i(0, 3), "water")
	assert_eq(world.founding_error(ORIGIN), "Wasser ist nicht bebaubar", "Gelände vor Vorkommen:")
	assert_eq(world.founding_error(ORIGIN + Vector2i(-3, 0)), "Außerhalb der Karte", "Karte vor Gelände:")


func test_founding_checks_first_warehouse_too() -> void:
	var world := empty_world()
	var storage_origin := founding_origin(world, "warehouse", ORIGIN)
	world.map.add_deposit(storage_origin + Vector2i(1, 1), _tree())
	assert_eq(world.founding_error(ORIGIN), "Warenlager: Baum im Weg", "Baum im Warenlager:")
	world.map.remove_deposit(storage_origin + Vector2i(1, 1))
	world.map.add_deposit(Building.front_of_entrance("warehouse", storage_origin), _tree())
	assert_eq(world.founding_error(ORIGIN), "Warenlager: Eingang ist versperrt", "Baum vor dem Warenlager:")


func test_rejected_founding_command_gives_same_reason() -> void:
	var world := empty_world()
	world.map.add_deposit(ORIGIN, _tree())
	assert_eq(world.execute(Command.found(ORIGIN)), "Baum im Weg", "Grund des Befehls:")
	assert_true(world.is_founding(), "Weiter in Gründung")
	assert_eq(world.get_building_at(ORIGIN + Vector2i(1, 1)), null, "Kein Bergfried:")


func test_founding_checks_campfire_too() -> void:
	var world := empty_world()
	var campfire := founding_origin(world, "campfire", ORIGIN)
	world.map.add_deposit(campfire, _tree())
	assert_eq(world.founding_error(ORIGIN), "Lagerfeuer: Baum im Weg", "Baum auf dem Lagerfeuer:")
	world.map.remove_deposit(campfire)
	world.map.set_terrain(campfire, "sand")
	assert_eq(world.founding_error(ORIGIN), "Lagerfeuer: Ufer ist nicht bebaubar", "Ufer unter dem Lagerfeuer:")
	assert_eq(world.founding_error(Vector2i(2, world.map.height - 6)), "Lagerfeuer: Außerhalb der Karte", "Lagerfeuer am Kartenrand:")
