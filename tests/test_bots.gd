extends TestCase
## Szenario-Bot (ScenarioBot): Jede Referenz-Bauordnung aus tools/bots/ gewinnt ihr Szenario mit
## dessen Seed; dazu die einzelnen Einträge auf der leeren Testkarte (Bergfried bei (2, 2),
## Warenlager mit ID 2).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const MARKET_SITE := Vector2i(14, 10)
## So viele Tage darf eine Referenz-Bauordnung höchstens brauchen.
const MAX_DAYS := 40


func _founded(scenario_id := "tiny") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


func _bot(steps: Array, rules: Array = []) -> ScenarioBot:
	var bot := ScenarioBot.new()
	bot.steps.assign(steps)
	bot.rules.assign(rules)
	return bot


func test_every_scenario_with_a_goal_is_won_by_its_reference_order() -> void:
	for scenario_id in Scenario.list_ids():
		var scenario := Scenario.load_named(scenario_id)
		if scenario.goals.is_empty():
			continue
		var bot := ScenarioBot.load_named(scenario_id)
		assert_eq(bot.error, "", "Bauordnung %s:" % scenario_id)
		var world := GameWorld.create(scenario, scenario.fixed_seed)
		bot.play(world, MAX_DAYS)
		assert_true(world.is_victorious(), "%s nicht gewonnen (Tag %d): %s / %s" % [scenario_id, world.get_day(),
				"; ".join(world.goal_status()), "; ".join(bot.events)])


func test_missing_order_is_an_error() -> void:
	assert_true(ScenarioBot.load_named("gibt_es_nicht").error != "", "Fehler erwartet")


func test_build_waits_for_its_day_and_builds_until_count() -> void:
	var world := _founded()
	var bot := _bot([{"build": "house", "until": 2, "day": 2}])
	bot.act(world)
	assert_eq(ScenarioBot.count_buildings(world, "house"), 0, "Vor Tag 2:")
	while world.get_day() < 2:
		world.step()
	bot.act(world)
	assert_eq([ScenarioBot.count_buildings(world, "house"), bot.done_steps()], [1, 0], "Erstes Wohnhaus:")
	bot.act(world)
	bot.act(world)
	assert_eq([ScenarioBot.count_buildings(world, "house"), bot.done_steps()], [2, 1], "Zweites Wohnhaus, Schritt erledigt:")
	assert_true(bot.is_done(), "Alle Schritte erledigt")


func test_steps_wait_in_order() -> void:
	var world := _founded()
	var bot := _bot([{"ration": "half", "population": 99}, {"build": "house"}])
	for i in 3:
		bot.act(world)
	assert_eq([world.get_ration(), ScenarioBot.count_buildings(world, "house")], ["normal", 0], "Der erste Schritt hält auf:")


func test_ration_and_tax_are_set_once() -> void:
	var world := _founded()
	var bot := _bot([], [{"ration": "extra"}, {"tax": "low"}])
	bot.act(world)
	bot.act(world)
	assert_eq([world.get_ration(), world.get_tax_rate()], ["extra", "low"], "Gesetzt:")
	assert_eq(bot.events.size(), 2, "Nur einmal protokolliert:")


func test_sell_keeps_the_given_amount() -> void:
	var world := _founded("tiny_market")
	place(world, "market", MARKET_SITE)
	put_goods(world, WAREHOUSE, "wood", 80)
	var bot := _bot([], [{"sell": "wood", "keep": 60}])
	for i in 10:
		bot.act(world)
	assert_eq(world.get_stock("wood"), 60, "Verkauft bis auf den Rest:")


func test_buy_waits_for_its_condition_and_notes_why() -> void:
	var world := _founded("tiny_market")
	place(world, "market", MARKET_SITE)
	var bot := _bot([{"buy": "wood", "until": 105, "stock": {"stone": 60}}, {"buy": "wood", "until": 200}])
	bot.act(world)
	assert_eq(world.get_stock("wood"), 100, "Wartet auf genug Stein:")
	put_goods(world, WAREHOUSE, "stone", 60)
	bot.act(world)
	assert_eq([world.get_stock("wood"), bot.done_steps()], [105, 0], "Ein Handel:")
	bot.act(world)
	assert_eq(bot.done_steps(), 1, "Ziel erreicht, weiter mit dem nächsten Schritt:")
	for i in 10:
		bot.act(world)
	assert_true(bot.events.size() == 1 and bot.events[0].contains("Schritt 2 wartet"),
			"Grund einmal protokolliert: %s" % str(bot.events))


func test_unknown_entry_is_noted_and_skipped() -> void:
	var world := _founded()
	var bot := _bot([{"dance": "house"}, {"build": "house"}])
	bot.act(world)
	bot.act(world)
	assert_eq(ScenarioBot.count_buildings(world, "house"), 1, "Danach geht es weiter:")
	assert_true(bot.events[0].contains("unbekannter Eintrag"), "Protokolliert: %s" % str(bot.events))


func test_site_leaves_a_tile_around_the_building() -> void:
	var world := _founded()
	var site := ScenarioBot.site_near_keep(world, "house")
	assert_true(site != GameWorld.NO_SITE, "Bauplatz gefunden")
	var last := Building.last_tile_of("house", site)
	for y in range(site.y - 1, last.y + 2):
		for x in range(site.x - 1, last.x + 2):
			assert_eq(world.get_building_at(Vector2i(x, y)), null, "Frei bei %s:" % str(Vector2i(x, y)))


func test_gatherer_needs_deposits_in_range() -> void:
	var world := _founded()
	var bot := _bot([{"build": "woodcutter"}])
	bot.act(world)
	assert_eq(ScenarioBot.count_buildings(world, "woodcutter"), 0, "Ohne Bäume kein Holzfäller:")
	assert_true(bot.is_done() and bot.events[0].contains("kein Bauplatz"), "Übersprungen: %s" % str(bot.events))
	for x in ScenarioBot.MIN_DEPOSITS_IN_RANGE:
		add_deposit(world, Vector2i(2 + x, 14), "tree")
	assert_true(ScenarioBot.site_near_keep(world, "woodcutter") != GameWorld.NO_SITE, "Mit Bäumen ein Bauplatz")


func test_recruits_and_posts_soldiers_at_the_keep() -> void:
	var world := _founded("tiny_gold")
	var armory := place(world, "armory", ARMORY_SITE)
	place(world, "barracks", BARRACKS_SITE)
	put_goods(world, armory, "bow", 2)
	var bot := _bot([{"recruit": "archer", "until": 2}], [{"post": "keep"}])
	for i in 3:
		bot.act(world)
	var keep_front := world.get_building_at(KEEP_ORIGIN).entrance_front()
	var soldiers := world.get_residents().filter(func(resident: Resident) -> bool: return resident.is_soldier())
	assert_eq(soldiers.size(), 2, "Angeworben:")
	assert_true(bot.is_done(), "Schritt erledigt")
	for soldier: Resident in soldiers:
		assert_true(Vector2(soldier.post_tile() - keep_front).length() <= ScenarioBot.POST_RADIUS,
				"Posten %s am Bergfried %s" % [str(soldier.post_tile()), str(keep_front)])
