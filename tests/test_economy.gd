extends TestCase
## Wirtschaftsrechner (Economy): Leistung je Arbeitsgang aus den Daten, Wertschöpfung, Nahrung
## und Ketten; dazu ein Abgleich der Schätzung mit der Simulation einer Apfelplantage auf der
## leeren Testkarte (Bergfried bei (2, 2), Kornspeicher mit ID 4).

const KEEP_ORIGIN := Vector2i(2, 2)
const GRANARY := 4
## Freie Stelle für eine Plantage (4×4) rechts vom Warenlager (wie in test_farm.gd).
const ORCHARD_SITE := Vector2i(12, 2)
## So viele Arbeitsgänge misst der Abgleich mit der Simulation.
const MEASURED_CYCLES := 4
## Erlaubte Abweichung der geschätzten von der gemessenen Dauer eines Arbeitsgangs.
const TOLERANCE := 0.05


func _ticks_per_tile() -> float:
	return float(Resident.ticks_per_tile())


func test_only_workplaces_that_deliver_goods() -> void:
	var types := Economy.workplace_types()
	for type_id: String in ["woodcutter", "orchard", "bakery"]:
		assert_true(types.has(type_id), "%s fehlt" % type_id)
	for type_id: String in ["keep", "house", "warehouse", "barracks", "wall"]:
		assert_false(types.has(type_id), "%s ist keine Arbeitsstätte" % type_id)


func test_housing_types_are_the_buildings_with_housing() -> void:
	var types := Economy.housing_types()
	assert_true(types.has("house"), "Wohnhaus fehlt")
	assert_false(types.has("woodcutter"), "Holzfäller hat keinen Wohnraum")


func test_farm_without_walking_works_all_day() -> void:
	var economy := Economy.new(0.0, 0.0)
	var orchard := Building.create(0, "orchard", Vector2i.ZERO)
	var rate := economy.rate("orchard")
	assert_eq(rate.product, "apples", "Erzeugnis:")
	assert_eq(rate.input, "", "Keine Eingangsware:")
	assert_eq(rate.walk_ticks, 0.0, "Kein Weg:")
	assert_eq(rate.product_per_day,
			float(GameWorld.TICKS_PER_DAY) / orchard.work_ticks() * orchard.carry_load(), "Äpfel pro Tag:")


func test_gatherer_walks_to_deposit_and_storage() -> void:
	var economy := Economy.new(10.0, 5.0)
	var woodcutter := Building.create(0, "woodcutter", Vector2i.ZERO)
	var rate := economy.rate("woodcutter")
	assert_eq(rate.product, "wood", "Erzeugnis aus dem Vorkommen:")
	assert_eq(rate.work_ticks, woodcutter.mine_ticks() + woodcutter.process_ticks(), "Arbeit:")
	assert_eq(rate.walk_ticks, (2 * 5.0 + 2 * 10.0) * _ticks_per_tile(), "Weg:")
	assert_eq(rate.product_per_day,
			GameWorld.TICKS_PER_DAY / rate.cycle_ticks() * woodcutter.carry_load(), "Holz pro Tag:")


func test_producer_walks_to_storage_twice_and_uses_input() -> void:
	var economy := Economy.new(10.0, 5.0)
	var bakery := Building.create(0, "bakery", Vector2i.ZERO)
	var rate := economy.rate("bakery")
	assert_eq(rate.input, "flour", "Eingangsware:")
	assert_eq(rate.walk_ticks, 4 * 10.0 * _ticks_per_tile(), "Holen und Abliefern:")
	var cycles := GameWorld.TICKS_PER_DAY / (bakery.work_ticks() + rate.walk_ticks)
	assert_eq(rate.product_per_day, cycles * bakery.carry_load(), "Brot pro Tag:")
	assert_eq(rate.input_per_day, cycles * bakery.input_amount(), "Mehl pro Tag:")


func test_cost_counts_goods_at_buy_price() -> void:
	var cost: Dictionary = GameDefs.get_instance().buildings["mill"]["cost"]
	assert_eq(Economy.cost_in_gold("mill"),
			int(cost["wood"]) * Market.buy_price("wood") + int(cost["gold"]), "Mühle:")


func test_value_subtracts_input_at_sell_price() -> void:
	var economy := Economy.new()
	var rate := economy.rate("mill")
	var expected := rate.product_per_day * Market.sell_price("flour") - rate.input_per_day * Market.sell_price("wheat")
	assert_eq(economy.value_per_day("mill"), expected, "Wertschöpfung der Mühle:")
	assert_eq(economy.payback_days("mill"), Economy.cost_in_gold("mill") / expected, "Amortisation:")


func test_fed_residents_follow_ration() -> void:
	var economy := Economy.new()
	var apples := economy.rate("orchard").product_per_day
	assert_eq(economy.fed_residents("orchard", "normal"), apples / Population.consumption("normal"), "Normal:")
	assert_eq(economy.fed_residents("orchard", "half"), apples / Population.consumption("half"), "Halb:")
	assert_true(is_inf(economy.fed_residents("orchard", "none")), "Ohne Verbrauch unbegrenzt")
	assert_eq(economy.fed_residents("woodcutter", "normal"), 0.0, "Holz ist keine Nahrung:")


func test_chain_goes_down_to_raw_material() -> void:
	var economy := Economy.new()
	var links := economy.chain("bakery")
	var types: Array[String] = []
	for link in links:
		types.append(link.type)
	assert_eq(types, ["bakery", "mill", "wheat_farm"] as Array[String], "Glieder:")
	assert_eq(links[0].count, 1.0, "Endglied:")
	assert_eq(links[1].count, economy.suppliers_needed("bakery", "mill"), "Mühlen je Bäcker:")
	assert_eq(links[2].count, links[1].count * economy.suppliers_needed("mill", "wheat_farm"),
			"Weizenfarmen je Bäcker:")
	assert_eq(links[2].depth, 2, "Stufe des Rohstoffs:")
	assert_eq(economy.suppliers_needed("mill", "wheat_farm"),
			economy.rate("mill").input_per_day / economy.rate("wheat_farm").product_per_day, "Verhältnis:")


func test_estimate_matches_simulated_orchard() -> void:
	var world := empty_world()
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	var orchard := world.get_building(build(world, "orchard", ORCHARD_SITE))
	var granary := world.get_building(GRANARY)
	var worker := world.get_resident(1)
	var deliveries: Array[int] = []
	var carried := 0
	for i in GameWorld.TICKS_PER_DAY * 4:
		world.step()
		if carried > 0 and worker.carried_amount == 0:
			deliveries.append(world.get_tick())
		carried = worker.carried_amount
		if deliveries.size() > MEASURED_CYCLES:
			break
	assert_eq(worker.workplace_id, orchard.id, "Arbeiter in der Plantage:")
	assert_true(deliveries.size() > MEASURED_CYCLES, "Zu wenige Gänge: %d" % deliveries.size())
	if deliveries.size() <= MEASURED_CYCLES:
		return
	var measured := float(deliveries.back() - deliveries.front()) / (deliveries.size() - 1)
	# Die echte Weglänge: Der Kornspeicher liegt im Weg, es geht nicht auf gerader Linie.
	var distance := Pathfinder.path_length(world._find_path(Figure.ground(orchard.entrance()),
			Figure.ground(granary.entrance()), GameWorld.Walker.GROUND_ONLY))
	var estimated := Economy.new(distance, 0.0).rate("orchard")
	assert_true(absf(estimated.cycle_ticks() - measured) <= measured * TOLERANCE,
			"Arbeitsgang geschätzt %.1f, gemessen %.1f Takte" % [estimated.cycle_ticks(), measured])
	var apples_per_day := GameWorld.TICKS_PER_DAY / measured * orchard.carry_load()
	assert_true(absf(estimated.product_per_day - apples_per_day) <= apples_per_day * TOLERANCE,
			"Äpfel pro Tag geschätzt %.2f, gemessen %.2f" % [estimated.product_per_day, apples_per_day])
