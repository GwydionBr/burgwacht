extends TestCase
## Simulationstests: Schatz und Steuersatz. Leere Karte (nur Wiese), Bergfried bei (2, 2),
## Kornspeicher (ID 4) daneben; 4 Startbewohner ohne Arbeitsstätte.

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


func test_population_data_has_tax_rates_in_order() -> void:
	assert_eq(Population.tax_rate_ids(), ["none", "low", "medium", "high", "very_high"] as Array[String], "Steuersätze:")
	assert_eq(Population.tax_rate_name("very_high"), "sehr hoch", "Name:")
	assert_eq(Population.tax_gold("low"), 0.6, "Gold niedrig:")
	assert_eq(Population.tax_factor("none"), 2, "Faktor keine:")
	assert_eq(Population.tax_factor("very_high"), -8, "Faktor sehr hoch:")
	assert_eq(Population.default_tax_rate(), "none", "Voreinstellung:")


func test_new_world_has_no_taxes_and_start_gold() -> void:
	var world := empty_world()
	assert_eq(world.get_tax_rate(), "none", "Steuersatz:")
	assert_eq(world.get_treasury(), 0, "Schatz ohne Startgold:")
	assert_eq(new_world("tiny_gold").get_treasury(), 25, "Startgold aus dem Szenario:")


func test_set_tax_rate_command() -> void:
	var world := _founded()
	var changed: Array[bool] = []
	world.settings_changed.connect(func() -> void: changed.append(true))
	assert_eq(world.execute(Command.set_tax_rate("high")), "", "Befehl:")
	assert_eq(world.get_tax_rate(), "high", "Steuersatz:")
	assert_eq(changed.size(), 1, "Signal Einstellungen geändert:")


func test_unknown_tax_rate_is_rejected_in_german() -> void:
	var world := _founded()
	var before := world.to_data()
	assert_eq(world.execute(Command.set_tax_rate("gierig")), "Unbekannter Steuersatz „gierig“", "Befehl:")
	assert_eq(world.to_data(), before, "Spielwelt unverändert:")


func test_tax_rate_can_be_set_during_founding() -> void:
	var world := empty_world()
	assert_eq(world.execute(Command.set_tax_rate("low")), "", "Befehl:")
	assert_eq(world.get_tax_rate(), "low", "Steuersatz:")


func test_no_taxes_during_founding() -> void:
	var world := empty_world("tiny_gold")
	world.execute(Command.set_tax_rate("very_high"))
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	assert_eq(world.get_treasury(), 25, "Schatz:")


func test_residents_pay_taxes_at_day_start() -> void:
	var world := _founded("tiny_gold")
	world.execute(Command.set_tax_rate("high"))
	var count: Array[int] = [0]
	world.treasury_changed.connect(func() -> void: count[0] += 1)
	for i in GameWorld.TICKS_PER_DAY - 1:
		world.step()
	assert_eq(world.get_treasury(), 25, "Vor Tagesbeginn noch keine Steuern:")
	world.step()
	assert_eq(world.get_treasury(), 29, "25 + 4 Bewohner × 1:")
	assert_eq(count[0], 1, "Signal Schatz geändert:")


func test_taxes_are_rounded_down() -> void:
	var world := _founded()
	world.execute(Command.set_tax_rate("very_high"))
	_next_day(world)
	assert_eq(world.get_treasury(), 4, "4 × 1,2 = 4,8 → 4:")
	world.execute(Command.set_tax_rate("low"))
	_next_day(world)
	assert_eq(world.get_treasury(), 6, "4 × 0,6 = 2,4 → 2:")


func test_exact_taxes_are_not_lost_to_rounding() -> void:
	var world := _founded("tiny_five")
	world.execute(Command.set_tax_rate("low"))
	_next_day(world)
	assert_eq(world.get_treasury(), 3, "5 × 0,6 = 3:")
	world.execute(Command.set_tax_rate("medium"))
	_next_day(world)
	assert_eq(world.get_treasury(), 7, "5 × 0,8 = 4:")


func test_no_tax_means_no_gold_and_no_signal() -> void:
	var world := _founded()
	var count: Array[int] = [0]
	world.treasury_changed.connect(func() -> void: count[0] += 1)
	_next_day(world)
	assert_eq(world.get_treasury(), 0, "Schatz:")
	assert_eq(count[0], 0, "Kein Signal ohne Änderung:")


func test_tax_rate_is_a_factor() -> void:
	var world := _founded()
	assert_eq(_factors(world)[2], ["tax_rate", 2], "Vorschau keine Steuern:")
	world.execute(Command.set_tax_rate("medium"))
	assert_eq(_factors(world)[2], ["tax_rate", -4], "Vorschau mittel:")
	_next_day(world)
	assert_eq(_factors(world), [["ration", -8], ["variety", 0], ["tax_rate", -4]] as Array[Array], "Faktoren des Tags:")
	assert_eq(world.get_factors()[2].name(), "Steuersatz", "Name:")


func test_tax_rate_changes_popularity() -> void:
	var world := _founded()
	put_goods(world, GRANARY, "apples", 20)
	_next_day(world)
	assert_eq(world.get_popularity(), 52, "Keine Steuern: 50 + 0 + 0 + 2:")
	world.execute(Command.set_tax_rate("very_high"))
	_next_day(world)
	assert_eq(world.get_popularity(), 44, "Sehr hoch: 52 − 8:")


func test_save_and_load_keeps_treasury_and_tax_rate() -> void:
	var world := _founded("tiny_gold")
	world.execute(Command.set_tax_rate("medium"))
	_next_day(world)
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(loaded.get_treasury(), world.get_treasury(), "Schatz:")
	assert_eq(loaded.get_tax_rate(), "medium", "Steuersatz:")
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	for i in 2:
		_next_day(world)
		_next_day(loaded)
	assert_eq(loaded.to_data(), world.to_data(), "Daten nach weiteren 2 Tagen:")
