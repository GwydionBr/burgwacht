extends TestCase


func test_buildable_depends_on_terrain_and_deposits() -> void:
	var map := MapData.new(4, 4)
	var rng := RandomNumberGenerator.new()
	assert_true(map.is_buildable(Vector2i(1, 1)), "Wiese sollte bebaubar sein")
	map.set_terrain(Vector2i(2, 2), "water")
	assert_true(not map.is_buildable(Vector2i(2, 2)), "Wasser sollte nicht bebaubar sein")
	map.add_deposit(Vector2i(1, 1), Deposit.create("tree", rng))
	assert_true(not map.is_buildable(Vector2i(1, 1)), "Kachel mit Baum sollte nicht bebaubar sein")
	assert_true(not map.is_buildable(Vector2i(4, 0)), "Außerhalb der Karte")


func test_remove_deposit_emits_signal() -> void:
	var map := MapData.new(4, 4)
	var removed: Array[Vector2i] = []
	map.deposit_removed.connect(func(tile: Vector2i) -> void: removed.append(tile))
	map.add_deposit(Vector2i(1, 2), Deposit.create("stone", RandomNumberGenerator.new()))
	map.remove_deposit(Vector2i(1, 2))
	map.remove_deposit(Vector2i(1, 2))
	assert_eq(removed, [Vector2i(1, 2)] as Array[Vector2i], "Signal:")
	assert_eq(map.get_deposit(Vector2i(1, 2)), null, "Vorkommen:")


func test_deposit_amount_comes_from_data() -> void:
	var deposit := Deposit.create("tree", RandomNumberGenerator.new())
	assert_eq(deposit.amount, int(GameDefs.get_instance().deposits["tree"]["amount"]), "Menge:")
