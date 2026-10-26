extends TestCase
## Szenarioziele: Validierung, gleichzeitige Erfüllung, Ende der Partie und Spielstände.


func _scenario(goals: Variant) -> Scenario:
	return Scenario.from_dict("test_goals", {
		"name": "Zieltest", "map": {"width": 24, "height": 24}, "seed": 1,
		"start_goods": {"wood": 100, "apples": 80}, "start_residents": 8,
		"goals": goals})


func _world(goals: Array) -> GameWorld:
	var scenario := _scenario(goals)
	assert_eq(scenario.error, "", "Szenario:")
	return clear_map(GameWorld.create(scenario, 1))


func test_invalid_goals_are_rejected() -> void:
	for invalid: Variant in [null, {}, [false], [{"kind": "unknown", "amount": 1, "text": "Ziel"}],
			[{"kind": "building", "type": "missing", "amount": 1, "text": "Ziel"}],
			[{"kind": "goods", "type": "missing", "amount": 1, "text": "Ziel"}],
			[{"kind": "goods", "amount": 1, "text": "Ziel"}],
			[{"kind": "population", "amount": 0, "text": "Ziel"}],
			[{"kind": "population", "amount": 1.5, "text": "Ziel"}],
			[{"kind": "population", "amount": 1, "text": false}],
			[{"kind": "population", "amount": 1, "text": "Ziel", "hint": []}]]:
		assert_true(_scenario(invalid).error != "", "Ungültig: %s" % str(invalid))


func test_founding_can_fulfil_a_goal_and_victory_stops_commands_and_time() -> void:
	var world := _world([{"kind": "population", "amount": 8, "text": "Bewohner"}])
	var events: Array[bool] = []
	world.victorious.connect(func() -> void: events.append(true))
	assert_false(world.is_victorious(), "Nicht vor der Gründung")
	found_castle(world)
	assert_true(world.is_victorious(), "Ziel erfüllt")
	assert_eq(events.size(), 1, "Ein Sieg-Signal")
	var before := world.to_data()
	assert_true(world.execute(Command.set_ration("normal")) != "", "Befehle gesperrt")
	world.step()
	assert_eq(world.to_data(), before, "Zeit und Zustand stehen still")
	assert_eq(events.size(), 1, "Kein weiteres Signal")
	var loaded := GameWorld.from_data(before)
	assert_true(loaded.is_victorious(), "Sieg gespeichert")
	assert_eq(loaded.to_data(), before, "Vollständiger Zustand")


func test_conditions_must_be_met_together_and_survive_reload() -> void:
	var world := found_castle(_world([
		{"kind": "building", "type": "house", "amount": 1, "text": "Wohnraum"},
		{"kind": "building", "type": "woodcutter", "amount": 1, "text": "Holz", "hint": "Bei Bäumen bauen."}]))
	var house := build(world, "house", find_site(world, "house"))
	assert_false(world.is_victorious(), "Nur eine Bedingung erfüllt")
	assert_eq(world.execute(Command.demolish(house)), "", "Wohnhaus abreißen")
	build(world, "woodcutter", find_site(world, "woodcutter"))
	assert_false(world.is_victorious(), "Früheres Wohnhaus zählt nicht")
	var loaded := GameWorld.from_data(world.to_data())
	assert_eq(loaded.goal_status(), world.goal_status(), "Fortschritt geladen")
	for each: GameWorld in [world, loaded]:
		build(each, "house", find_site(each, "house"))
		assert_true(each.is_victorious(), "Alle Bedingungen erfüllt")
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher weiterer Verlauf")


func test_gold_goods_and_day_are_read_from_the_world() -> void:
	var world := found_castle(_world([
		{"kind": "gold", "amount": 1, "text": "Gold"},
		{"kind": "goods", "type": "wood", "amount": 100, "text": "Holz"},
		{"kind": "day", "amount": 2, "text": "Tag 2"}]))
	assert_eq(world.goal_status(), PackedStringArray(["○ Gold (0/1)", "✓ Holz (100/100)", "○ Tag 2 (1/2)"]), "Nach der Gründung")
	assert_eq(world.execute(Command.set_tax_rate("low")), "", "Steuern erheben")
	for i in GameWorld.TICKS_PER_DAY - 1:
		world.step()
	assert_false(world.is_victorious(), "Noch Tag 1 ohne Steuern")
	var loaded := GameWorld.from_data(world.to_data())
	assert_eq(loaded.goal_status(), world.goal_status(), "Neue Zielarten geladen")
	for each: GameWorld in [world, loaded]:
		each.step()
		assert_true(each.is_victorious(), "Tag 2 mit Steuern und unverbrauchtem Holz")


func test_spent_goods_no_longer_count() -> void:
	var world := found_castle(_world([
		{"kind": "goods", "type": "wood", "amount": 100, "text": "Holz"},
		{"kind": "building", "type": "house", "amount": 1, "text": "Wohnraum"}]))
	build(world, "house", find_site(world, "house"))
	assert_false(world.is_victorious(), "Das Wohnhaus hat Holz gekostet")
	assert_eq(world.goal_status()[0], "○ Holz (94/100)", "Fortschritt nach dem Bau")


func test_last_wave_is_checked_at_the_end_of_the_tick() -> void:
	var scenario := _scenario([{"kind": "repelled_waves", "amount": 1, "text": "Welle abwehren"}])
	var world := found_castle(clear_map(GameWorld.create(scenario, 1)))
	var enemy := add_enemy(world, "bandit", Vector2i(23, 23), 1)
	kill_enemy(world, enemy)
	world.step()
	assert_true(world.is_victorious(), "Nach letzter Abwehr gewonnen")


func test_free_play_and_older_saves_have_no_goal() -> void:
	var world := found_castle(empty_world())
	var data := world.to_data()
	data.erase("goals")
	data.erase("victorious")
	var loaded := GameWorld.from_data(data)
	assert_false(loaded.is_finished(), "Älterer Spielstand läuft weiter")
	assert_true(loaded.goal_status().is_empty(), "Kein Ziel")
	assert_true(Scenario.load_named(Scenario.DEFAULT).goals.is_empty(), "Freies Spiel bleibt ohne Ziel")


func test_defeat_takes_precedence_over_unchecked_goals() -> void:
	var world := found_castle(_world([{"kind": "population", "amount": 9, "text": "Bewohner"}]))
	world._lose()
	world.step()
	assert_true(world.is_defeated(), "Bergfried gefallen")
	assert_false(world.is_victorious(), "Kein Sieg nach Niederlage")


func test_intro_can_be_won_with_its_start_goods_and_market() -> void:
	var scenario := Scenario.load_named("first_castle")
	assert_eq(scenario.error, "", "Einstiegsszenario:")
	var world := found_castle(GameWorld.create(scenario, scenario.fixed_seed))
	for type_id: String in ["woodcutter", "orchard", "house", "armory", "market", "barracks"]:
		build(world, type_id, find_site(world, type_id))
	assert_eq(world.execute(Command.trade("bow", true)), "", "Bögen kaufen")
	var barracks: Building = null
	for building in world.get_buildings():
		if building.type == "barracks":
			barracks = building
	assert_true(barracks != null, "Kaserne gebaut")
	for i in 4:
		assert_eq(world.execute(Command.recruit(barracks.id, "archer")), "", "Bogenschütze anwerben")
	# Soldaten am Eingang des Bergfrieds aufstellen, bis die Räuber dort ankommen.
	var soldiers: Array[int] = []
	for resident in world.get_residents():
		if resident.is_soldier():
			soldiers.append(resident.id)
	var keep: Building = null
	for building in world.get_buildings():
		if building.type == GameWorld.FOUNDING_TYPE:
			keep = building
	assert_eq(world.execute(Command.move(soldiers, Figure.ground(keep.entrance() + Vector2i(0, 1)))), "", "Bergfried verteidigen")
	for i in 13 * GameWorld.TICKS_PER_DAY:
		if world.is_finished():
			break
		world.step()
	assert_true(world.is_victorious(), "Einstiegsszenario gewonnen: Tag %d, Niederlage %s, Feinde %d, Soldaten %d, Ziele %s" % [world.get_day(), str(world.is_defeated()), world.get_enemies().size(), world.get_soldier_count(), str(world.goal_status())])


func test_victory_queries_and_commands_share_the_same_rejection() -> void:
	var world := found_castle(_world([{"kind": "building", "type": "house", "amount": 1, "text": "Wohnraum"}]))
	var site := find_site(world, "house")
	var house := build(world, "house", site)
	assert_true(world.is_victorious(), "Wohnhaus erfüllt das Ziel")
	var reason := world.command_error()
	assert_true(reason != "", "Befehle gesperrt")
	var before := world.to_data()
	assert_eq(world.demolish_error(house), reason, "Abrissvorschau")
	assert_eq(world.execute(Command.demolish(house)), reason, "Abrissbefehl")
	assert_eq(world.build_error("woodcutter", Vector2i(0, 0)), reason, "Bauvorschau")
	assert_eq(GameWorld.line_error(world.line_plan("wall", Vector2i(0, 0), Vector2i(1, 0))), reason, "Mauerlinie")
	assert_eq(world.clearing_tool_error(), reason, "Roden")
	assert_eq(world.founding_error(site), reason, "Gründung")
	assert_eq(world.market_error(), reason, "Markt")
	assert_eq(world.trade_error("wood", true), reason, "Handel")
	assert_eq(world.recruit_error(0, "archer"), reason, "Anwerben")
	assert_eq(world.move_error([], Figure.ground(site)), reason, "Bewegen")
	assert_eq(world.attack_error([], 0), reason, "Angreifen")
	assert_eq(world.spawn_enemy_error("bandit"), reason, "Feind erscheinen lassen")
	assert_eq(world._waves().spawn_next_error(), reason, "Nächste Welle")
	assert_eq(world.to_data(), before, "Alle Abfragen verändern nichts")
