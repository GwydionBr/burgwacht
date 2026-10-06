extends TestCase
## Die Ansicht zeigt den letzten Knüppelhieb auch dann, wenn die Mauer sofort verschwindet.


func test_lethal_building_hit_finishes_visual_attack_before_resuming_walk() -> void:
	var world := empty_world("tiny_production")
	assert_eq(world.execute(Command.found(Vector2i(2, 2))), "", "Gründung:")
	var wall := world.get_building(place(world, "wall", Vector2i(10, 10)))
	wall.hp = 12
	var bandit := add_enemy(world, "bandit", Vector2i(10, 11))
	bandit.path = [Figure.ground(Vector2i(10, 10)), Figure.ground(Vector2i(10, 9))] as Array[Vector3i]
	var clock := GameClock.new()
	clock.world = world
	var view := EnemyView.new()
	view.setup(bandit, clock)
	var fighter_hits: Array[Vector3i] = []
	world.melee_hit.connect(func(from: Vector3i, _to: Vector3i) -> void: fighter_hits.append(from))
	world.step()
	assert_eq(world.get_building(wall.id), null, "Mauer fällt durch diesen Hieb:")
	assert_true(bandit.is_moving(), "Der Weg zum Bergfried wird sofort neu geplant:")
	assert_eq(view.animation_name(), "attack", "Der letzte Hieb bleibt sichtbar:")
	assert_eq(view.facing, 6, "Knüppel weist weiter nach Norden zur gefallenen Mauer:")
	assert_eq(fighter_hits.size(), 0, "Gebäudetreffer lösen keinen Schwertklang für Kämpfertreffer aus:")
	for i in 10:
		world.step()
	assert_eq(view.animation_name(), "walk", "Nach dem Hieb folgt wieder die tatsächliche Bewegung:")
	view.free()
	clock.free()
