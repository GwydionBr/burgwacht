extends TestCase
## Simulationstests: Essen zu Tagesbeginn, Ration, Faktoren und Beliebtheit. Leere Karte
## (nur Wiese), Bergfried bei (2, 2), Kornspeicher (ID 4) daneben; 4 Startbewohner ohne
## Arbeitsstätte, also ändert nur das Essen den Vorrat.

const KEEP_ORIGIN := Vector2i(2, 2)
const GRANARY := 4


func _founded(scenario_id := "tiny") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Lässt die Welt bis zum nächsten Tagesbeginn laufen.
func _next_day(world: GameWorld) -> void:
	world.step()
	while world.get_tick() % GameWorld.TICKS_PER_DAY != 0:
		world.step()


## Die Faktoren als Paare [ID, Wert] zum Vergleichen.
func _factors(world: GameWorld) -> Array[Array]:
	var result: Array[Array] = []
	for factor in world.get_factors():
		result.append([factor.id, factor.value])
	return result


func _set_food(world: GameWorld, apples: int, meat: int) -> void:
	put_goods(world, GRANARY, "apples", apples)
	put_goods(world, GRANARY, "meat", meat)


func test_population_data_has_rations_in_order() -> void:
	assert_eq(Population.ration_ids(), ["none", "half", "normal", "extra", "double"] as Array[String], "Rationsstufen:")
	assert_eq(Population.ration_name("half"), "halb", "Name:")
	assert_eq(Population.consumption("extra"), 1.5, "Verbrauch extra:")
	assert_eq(Population.ration_factor("none"), -8, "Faktor keine:")
	assert_eq(Population.ration_factor("double"), 8, "Faktor doppelt:")
	assert_eq(Population.default_ration(), "normal", "Voreinstellung:")


func test_new_world_has_default_ration_and_start_popularity() -> void:
	var world := empty_world()
	assert_eq(world.get_ration(), "normal", "Ration:")
	assert_eq(world.get_popularity(), 50, "Beliebtheit:")


func test_start_popularity_comes_from_scenario() -> void:
	assert_eq(new_world("tiny_popular").get_popularity(), 97, "Beliebtheit:")


func test_set_ration_command() -> void:
	var world := _founded()
	var changed: Array[bool] = []
	world.settings_changed.connect(func() -> void: changed.append(true))
	assert_eq(world.execute(Command.set_ration("extra")), "", "Befehl:")
	assert_eq(world.get_ration(), "extra", "Ration:")
	assert_eq(changed.size(), 1, "Signal Einstellungen geändert:")


func test_unknown_ration_is_rejected_in_german() -> void:
	var world := _founded()
	var before := world.to_data()
	assert_eq(world.execute(Command.set_ration("viel")), "Unbekannte Ration „viel“", "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_ration_can_be_set_during_founding() -> void:
	var world := empty_world()
	assert_eq(world.execute(Command.set_ration("half")), "", "Befehl:")
	assert_eq(world.get_ration(), "half", "Ration:")


func test_no_eating_during_founding() -> void:
	var world := empty_world("tiny_food")
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	assert_eq(world.get_popularity(), 50, "Beliebtheit:")


func test_residents_eat_at_day_start() -> void:
	var world := _founded()
	_set_food(world, 20, 0)
	for i in GameWorld.TICKS_PER_DAY - 1:
		world.step()
	assert_eq(world.get_stock("apples"), 20, "Vor Tagesbeginn noch nichts gegessen:")
	world.step()
	assert_eq(world.get_stock("apples"), 16, "4 Bewohner × normal:")


func test_need_is_rounded_up() -> void:
	var world := _founded()
	_set_food(world, 20, 0)
	world.execute(Command.set_ration("extra"))
	_next_day(world)
	assert_eq(world.get_stock("apples"), 14, "4 × 1,5 = 6:")
	world.execute(Command.set_ration("half"))
	_next_day(world)
	assert_eq(world.get_stock("apples"), 12, "4 × 0,5 = 2:")


func test_rounding_up_with_odd_residents() -> void:
	var world := _founded("tiny_three")
	_set_food(world, 20, 0)
	world.execute(Command.set_ration("half"))
	_next_day(world)
	assert_eq(world.get_stock("apples"), 18, "3 × 0,5 = 1,5 → 2:")


func test_need_is_shared_round_robin_over_kinds() -> void:
	var world := _founded()
	_set_food(world, 20, 20)
	world.execute(Command.set_ration("extra"))
	_next_day(world)
	assert_eq(world.get_stock("apples"), 17, "Äpfel (6 reihum, Äpfel zuerst):")
	assert_eq(world.get_stock("meat"), 17, "Fleisch:")


func test_round_robin_skips_empty_kind() -> void:
	var world := _founded()
	_set_food(world, 20, 1)
	_next_day(world)
	assert_eq(world.get_stock("apples"), 17, "Äpfel:")
	assert_eq(world.get_stock("meat"), 0, "Fleisch:")


func test_food_is_taken_from_granaries_in_id_order() -> void:
	var world := _founded()
	var second := build(world, "granary", founding_origin(world, "granary", KEEP_ORIGIN) + Vector2i(3, 0))
	put_goods(world, GRANARY, "apples", 2)
	put_goods(world, second, "apples", 10)
	var changed: Array[int] = []
	world.stock_changed.connect(func(id: int) -> void: changed.append(id))
	_next_day(world)
	assert_eq(world.get_building(GRANARY).contents.get("apples", 0), 0, "Erster Kornspeicher:")
	assert_eq(world.get_building(second).contents.get("apples", 0), 8, "Zweiter Kornspeicher:")
	assert_eq(changed, [GRANARY, second] as Array[int], "Gemeldete Lager:")


func test_shortage_lowers_actual_ration_and_keeps_setting() -> void:
	var world := _founded()
	_set_food(world, 3, 0)
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	_next_day(world)
	assert_eq(world.get_stock("apples"), 1, "Halbe Ration gegessen:")
	assert_eq(world.get_eaten_ration(), "half", "Tatsächliche Ration:")
	assert_eq(world.get_ration(), "normal", "Eingestellte Ration bleibt:")
	assert_eq(notices, ["Nicht genug Nahrung – Ration: halb"] as Array[String], "Meldung:")
	assert_eq(_factors(world)[0], ["ration", -4], "Faktor der tatsächlichen Ration:")


func test_no_food_means_no_ration() -> void:
	var world := _founded()
	_next_day(world)
	assert_eq(world.get_eaten_ration(), "none", "Tatsächliche Ration:")
	assert_eq(_factors(world), [["ration", -8], ["variety", 0]] as Array[Array], "Faktoren:")
	assert_eq(world.get_popularity(), 42, "Beliebtheit:")


func test_no_notice_without_shortage() -> void:
	var world := _founded()
	_set_food(world, 20, 0)
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	_next_day(world)
	assert_eq(notices, [] as Array[String], "Meldungen:")
	assert_eq(world.get_eaten_ration(), "normal", "Tatsächliche Ration:")


func test_full_ration_after_shortage_ends() -> void:
	var world := _founded()
	_set_food(world, 3, 0)
	_next_day(world)
	put_goods(world, GRANARY, "apples", 20)
	_next_day(world)
	assert_eq(world.get_eaten_ration(), "normal", "Wieder normal:")
	assert_eq(world.get_stock("apples"), 16, "Äpfel:")


func test_variety_counts_eaten_kinds() -> void:
	var world := _founded()
	_set_food(world, 20, 20)
	_next_day(world)
	assert_eq(_factors(world), [["ration", 0], ["variety", 1]] as Array[Array], "Zwei Sorten:")
	_set_food(world, 20, 0)
	_next_day(world)
	assert_eq(_factors(world), [["ration", 0], ["variety", 0]] as Array[Array], "Eine Sorte:")


func test_variety_counts_only_kinds_actually_eaten() -> void:
	var world := _founded()
	_set_food(world, 20, 20)
	world.execute(Command.set_ration("none"))
	_next_day(world)
	assert_eq(_factors(world), [["ration", -8], ["variety", 0]] as Array[Array], "Nichts gegessen:")


func test_popularity_changes_by_factor_sum() -> void:
	var world := _founded()
	_set_food(world, 50, 50)
	world.execute(Command.set_ration("double"))
	var count: Array[int] = [0]
	world.popularity_changed.connect(func() -> void: count[0] += 1)
	_next_day(world)
	assert_eq(world.get_popularity(), 59, "50 + 8 + 1:")
	assert_eq(world.get_factor_sum(), 9, "Summe:")
	assert_eq(count[0], 1, "Signal:")


func test_popularity_stays_within_bounds() -> void:
	var world := _founded("tiny_popular")
	_set_food(world, 100, 100)
	world.execute(Command.set_ration("double"))
	_next_day(world)
	assert_eq(world.get_popularity(), 100, "Obergrenze:")
	world.execute(Command.set_ration("none"))
	for i in 13:
		_next_day(world)
	assert_eq(world.get_popularity(), 0, "Untergrenze:")


func test_factors_preview_before_first_day() -> void:
	var world := _founded()
	_set_food(world, 20, 20)
	world.execute(Command.set_ration("extra"))
	assert_eq(_factors(world), [["ration", 4], ["variety", 1]] as Array[Array], "Vorschau:")
	assert_eq(world.get_stock("apples"), 20, "Vorschau isst nichts:")
	_set_food(world, 2, 0)
	assert_eq(_factors(world), [["ration", -4], ["variety", 0]] as Array[Array], "Vorschau bei Mangel:")


func test_factors_have_german_names() -> void:
	var world := _founded()
	var names: Array[String] = []
	for factor in world.get_factors():
		names.append(factor.name())
	assert_eq(names, ["Ration", "Vielfalt"] as Array[String], "Namen:")


func test_factors_stay_from_last_day_after_setting_change() -> void:
	var world := _founded()
	_set_food(world, 20, 0)
	_next_day(world)
	world.execute(Command.set_ration("double"))
	assert_eq(_factors(world), [["ration", 0], ["variety", 0]] as Array[Array], "Faktoren des letzten Tags:")


func test_day_reports_factors_changed() -> void:
	var world := _founded()
	var count: Array[int] = [0]
	world.factors_changed.connect(func() -> void: count[0] += 1)
	_next_day(world)
	assert_eq(count[0], 1, "Signal Faktoren geändert:")


func test_save_and_load_keeps_popularity_ration_and_factors() -> void:
	var world := _founded()
	_set_food(world, 30, 3)
	world.execute(Command.set_ration("extra"))
	_next_day(world)
	_next_day(world)
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_popularity(), world.get_popularity(), "Beliebtheit:")
	assert_eq(loaded.get_ration(), "extra", "Ration:")
	assert_eq(loaded.get_eaten_ration(), world.get_eaten_ration(), "Tatsächliche Ration:")
	assert_eq(_factors(loaded), _factors(world), "Faktoren:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in 3:
		_next_day(world)
		_next_day(loaded)
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren 3 Tagen:")
