extends TestCase
## Simulationstests: Kaserne (Verhalten „barracks“, ohne Arbeiter) und der Befehl Anwerben.
## Leere Karte (nur Wiese), tiny_production mit 100 Gold bzw. tiny ohne Gold; Bergfried (ID 1)
## bei (2, 2), Warenlager (ID 2) bei (7, 2), Lagerfeuer (ID 3) bei (3, 8), Kornspeicher (ID 4)
## bei (7, 6); 4 Startbewohner als Untätige um das Lagerfeuer.

const KEEP_ORIGIN := Vector2i(2, 2)
## Waffenkammer (3×3) unten in der Mitte, eine zweite rechts daneben.
const ARMORY_SITE := Vector2i(10, 10)
const NEXT_ARMORY_SITE := Vector2i(13, 10)
## Kaserne (3×3) oben rechts; Eingang (15, 4), davor (15, 5).
const BARRACKS_SITE := Vector2i(14, 2)
const BARRACKS_FRONT := Vector2i(15, 5)
## Holzfäller (2×2) links unten.
const WOODCUTTER_SITE := Vector2i(1, 12)
## Waffenkammer ist das erste Gebäude nach den vier der Gründung.
const ARMORY_ID := 5
## Obergrenze, bis ein Soldat an der Kaserne steht.
const MAX_TICKS := 500


func _founded(scenario_id := "tiny_production") -> GameWorld:
	var world := empty_world(scenario_id)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Gegründet, mit Waffenkammer (Schwerter und Bögen) und Kaserne; liefert die Kaserne.
func _armed(world: GameWorld, swords := 2, bows := 2) -> int:
	var armory := build(world, "armory", ARMORY_SITE)
	put_goods(world, armory, "sword", swords)
	put_goods(world, armory, "bow", bows)
	return build(world, "barracks", BARRACKS_SITE)


## Lässt die Welt laufen, bis der Bewohner steht (höchstens MAX_TICKS Takte).
func _until_settled(world: GameWorld, resident: Resident) -> void:
	for i in MAX_TICKS:
		if not resident.is_moving():
			return
		world.step()
	assert_true(false, "Bewohner %d ist nach %d Takten nicht angekommen" % [resident.id, MAX_TICKS])


func test_soldier_types_come_from_data() -> void:
	assert_eq(SoldierType.ids(), ["swordsman", "archer"] as Array[String], "Soldatentypen:")
	var expected: Dictionary[String, Array] = {
		"swordsman": ["Schwertkämpfer", 100, 20, 10, true, 0, 6, 6, {"sword": 1}, 10],
		"archer": ["Bogenschütze", 50, 10, 15, false, 7, 7, 5, {"bow": 1}, 5],
	}
	for type_id: String in expected:
		var def: Dictionary = GameDefs.get_instance().units[type_id]
		var actual: Array = [SoldierType.name_of(type_id), int(def["hp"]), int(def["damage"]), int(def["attack_ticks"]),
				bool(def.get("melee", false)), int(def.get("range", 0)), int(def["sight"]),
				SoldierType.ticks_per_tile(type_id), SoldierType.goods_cost_of(type_id), SoldierType.gold_cost_of(type_id)]
		assert_eq(actual, expected[type_id], "%s:" % type_id)
		assert_true(def.has("color"), "Farbe für %s" % type_id)


func test_barracks_data() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings["barracks"]
	var barracks := Building.create(1, "barracks", Vector2i.ZERO)
	assert_eq([def["name"], def["hotkey"], Building.size_of("barracks"), GameWorld.goods_cost_of("barracks"),
			GameWorld.gold_cost_of("barracks")],
			["Kaserne", "C", Vector2i(3, 3), {"wood": 20, "stone": 10}, 0], "Kaserne:")
	assert_true(barracks.is_barracks(), "Verhalten Kaserne")
	assert_true(not barracks.is_workplace(), "Ohne Arbeiter")
	assert_true(GameWorld.is_buildable("barracks"), "Hat eine Bautaste")


func test_barracks_is_built_like_any_building() -> void:
	var world := _founded()
	var wood := world.get_stock("wood")
	var id := build(world, "barracks", BARRACKS_SITE)
	assert_eq(world.get_building(id).type, "barracks", "Gebaut:")
	assert_eq([world.get_stock("wood"), world.get_stock("stone")], [wood - 20, 40], "Kosten:")
	world.step()
	assert_eq(world.get_idle_count(), 4, "Niemand wird dort Arbeiter:")


func test_recruit_reasons_in_order() -> void:
	var world := _founded()
	var keep := 1
	assert_eq(world.recruit_error(keep, "swordsman"), "Keine Kaserne", "Bergfried statt Kaserne:")
	assert_eq(world.recruit_error(99, "swordsman"), "Keine Kaserne", "Unbekanntes Gebäude:")
	var barracks := _armed(world, 0, 0)
	assert_eq(world.recruit_error(barracks, "knight"), "Unbekannter Soldatentyp „knight“", "Unbekannter Typ:")
	assert_eq(world.recruit_error(barracks, "swordsman"), "Kein Schwert in der Waffenkammer", "Ohne Schwert:")
	assert_eq(world.recruit_error(barracks, "archer"), "Kein Bogen in der Waffenkammer", "Ohne Bogen:")
	put_goods(world, ARMORY_ID, "sword", 1)
	assert_eq(world.recruit_error(barracks, "swordsman"), "", "Mit Schwert und Gold:")
	# Ohne Gold: tiny hat keins.
	var poor := _founded("tiny")
	var poor_barracks := _armed(poor)
	assert_eq(poor.recruit_error(poor_barracks, "swordsman"), "Nicht genug Gold (10 nötig)", "Ohne Gold:")
	assert_eq(poor.recruit_error(poor_barracks, "archer"), "Nicht genug Gold (5 nötig)", "Ohne Gold (Bogen):")


func test_no_idle_comes_before_missing_weapon_and_gold() -> void:
	var world := _founded("tiny")
	var barracks := _armed(world, 0, 0)
	# Vier Holzfäller beschäftigen alle vier Startbewohner.
	for site: Vector2i in [WOODCUTTER_SITE, Vector2i(5, 12), Vector2i(16, 13), Vector2i(18, 7)]:
		build(world, "woodcutter", site)
	world.step()
	assert_eq(world.get_idle_count(), 0, "Alle arbeiten:")
	assert_eq(world.recruit_error(barracks, "swordsman"), "Kein Untätiger", "Ohne Untätigen:")


func test_rejected_recruiting_changes_nothing() -> void:
	var world := _founded("tiny")
	var barracks := _armed(world)
	var before := world.to_data()
	assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "Nicht genug Gold (10 nötig)", "Abgelehnt:")
	assert_eq(world.to_data(), before, "Unverändert:")


func test_recruiting_takes_weapon_and_gold_and_makes_the_smallest_idle_a_soldier() -> void:
	var world := _founded()
	var barracks := _armed(world, 2, 1)
	var treasury := world.get_treasury()
	var changed: Array[int] = []
	world.resident_changed.connect(func(id: int) -> void: changed.append(id))
	assert_eq(world.execute(Command.recruit(barracks, "swordsman")), "", "Anwerben:")
	assert_eq([world.get_stock("sword"), world.get_treasury()], [1, treasury - 10], "Abzug:")
	var soldier := world.get_resident(1)
	assert_eq(soldier.soldier_type, "swordsman", "Untätiger mit kleinster ID ist Soldat:")
	assert_true(soldier.is_soldier() and not soldier.is_idle(), "Nicht mehr untätig")
	assert_eq(changed, [1] as Array[int], "Gemeldet:")
	assert_eq([world.get_idle_count(), world.get_population(), world.get_soldier_count()], [3, 4, 1],
			"Untätige, Bewohner, Soldaten:")
	assert_eq(world.execute(Command.recruit(barracks, "archer")), "", "Bogenschütze:")
	assert_eq(world.get_resident(2).soldier_type, "archer", "Nächster Untätiger:")
	assert_eq([world.get_stock("bow"), world.get_treasury()], [0, treasury - 15], "Abzug Bogen:")


func test_weapon_comes_from_the_oldest_armory_first() -> void:
	var world := _founded()
	var barracks := _armed(world, 1, 0)
	var second := build(world, "armory", NEXT_ARMORY_SITE)
	put_goods(world, second, "sword", 1)
	world.execute(Command.recruit(barracks, "swordsman"))
	assert_eq(world.get_building(ARMORY_ID).contents.get("sword", 0), 0, "Älteste Waffenkammer zuerst:")
	assert_eq(world.get_building(second).contents.get("sword", 0), 1, "Zweite unberührt:")


func test_soldier_walks_to_a_free_post_at_the_barracks() -> void:
	var world := _founded()
	var barracks := _armed(world)
	world.execute(Command.recruit(barracks, "swordsman"))
	world.execute(Command.recruit(barracks, "archer"))
	var first := world.get_resident(1)
	var second := world.get_resident(2)
	assert_eq(first.post, Resident.ground(BARRACKS_FRONT), "Erster Posten vor dem Eingang:")
	assert_true(second.post != first.post, "Zweiter Posten ist ein anderer")
	var adjacent := Building.adjacent_tiles("barracks", BARRACKS_SITE)
	assert_true(second.post_tile() in adjacent, "Zweiter Posten grenzt an die Kaserne")
	assert_true(first.is_moving(), "Läuft los")
	assert_eq(world.activity_of(first), "Schwertkämpfer – geht zum Posten", "Tätigkeit unterwegs:")
	_until_settled(world, first)
	_until_settled(world, second)
	assert_eq([first.position(), second.position()], [first.post, second.post], "Am Posten:")
	assert_eq(world.activity_of(second), "Bogenschütze – auf Posten", "Tätigkeit am Posten:")


func test_soldiers_walk_at_their_own_speed() -> void:
	var swordsman := Resident.create(1, Vector2i.ZERO, Resident.Level.GROUND)
	swordsman.soldier_type = "swordsman"
	var archer := Resident.create(2, Vector2i.ZERO, Resident.Level.GROUND)
	archer.soldier_type = "archer"
	var resident := Resident.create(3, Vector2i.ZERO, Resident.Level.GROUND)
	var from := Vector3i(0, 0, 0)
	var to := Vector3i(1, 0, 0)
	assert_eq([swordsman.step_ticks(from, to), archer.step_ticks(from, to), resident.step_ticks(from, to)],
			[6, 5, Resident.ticks_per_tile()], "Gerader Schritt:")


func test_soldier_never_gets_work() -> void:
	var world := _founded()
	var barracks := _armed(world)
	for i in 4:
		world.execute(Command.recruit(barracks, "swordsman" if i < 2 else "archer"))
	build(world, "woodcutter", WOODCUTTER_SITE)
	for i in 50:
		world.step()
	for resident in world.get_residents():
		assert_true(resident.is_soldier() and resident.workplace_id == 0, "Bewohner %d bleibt Soldat" % resident.id)
	assert_eq(world.recruit_error(barracks, "swordsman"), "Kein Untätiger", "Keiner mehr übrig:")


func test_soldiers_never_leave() -> void:
	var world := _founded("tiny_production")
	var barracks := _armed(world)
	world.execute(Command.recruit(barracks, "swordsman"))
	world.execute(Command.recruit(barracks, "archer"))
	# Beliebtheit 0: Wer kann, geht – die beiden Soldaten nicht.
	var data := world.to_data()
	data["popularity"] = 0
	world = GameWorld.from_data(data)
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	var ids: Array[int] = []
	for resident in world.get_residents():
		ids.append(resident.id)
	assert_eq(ids, [1, 2] as Array[int], "Nur die Soldaten bleiben:")
	assert_eq([world.get_population(), world.get_soldier_count()], [2, 2], "Bewohner und Soldaten:")


func test_soldiers_stay_even_without_housing() -> void:
	var world := _founded()
	var barracks := _armed(world)
	for type_id: String in ["swordsman", "swordsman", "archer"]:
		world.execute(Command.recruit(barracks, type_id))
	# Per Daten 6 weitere Soldaten: 9 Soldaten und 1 Untätiger bei Wohnraum 8.
	var data := world.to_data()
	for i in 6:
		var copy: Dictionary = data["residents"][0].duplicate(true)
		copy["id"] = 5 + i
		data["residents"].append(copy)
	data["next_resident_id"] = 11
	world = GameWorld.from_data(data)
	assert_eq([world.get_population(), world.get_housing()], [10, 8], "Zu viele Bewohner:")
	world.step()
	assert_eq(world.get_population(), 9, "Nur der Untätige geht:")
	assert_true(world.get_resident(4).is_leaving(), "Bewohner 4 geht")
	assert_eq(world.get_soldier_count(), 9, "Alle Soldaten bleiben:")


func test_soldier_counts_as_resident() -> void:
	var world := _founded()
	var barracks := _armed(world)
	world.execute(Command.recruit(barracks, "swordsman"))
	# Essen und Steuern richten sich nach der Bewohnerzahl.
	assert_eq(world.get_population(), 4, "Soldat zählt als Bewohner:")


func test_building_over_a_post_moves_the_post() -> void:
	var world := _founded()
	var barracks := _armed(world)
	world.execute(Command.recruit(barracks, "swordsman"))
	var soldier := world.get_resident(1)
	_until_settled(world, soldier)
	# Ein Wohnhaus (2×2) genau auf den Posten vor der Kaserne.
	build(world, "house", BARRACKS_FRONT)
	assert_true(world.is_walkable(soldier.post_tile(), Resident.Level.GROUND),
			"Neuer Posten ist begehbar")
	_until_settled(world, soldier)
	assert_eq(soldier.position(), soldier.post, "Steht am neuen Posten:")


func test_save_and_load_keeps_soldier_and_post() -> void:
	var world := _founded()
	var barracks := _armed(world)
	world.execute(Command.recruit(barracks, "archer"))
	for i in 7:
		world.step()
	var loaded := GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))
	assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden:")
	assert_eq([loaded.get_resident(1).soldier_type, loaded.get_resident(1).post],
			[world.get_resident(1).soldier_type, world.get_resident(1).post], "Soldatentyp und Posten:")
	for i in 200:
		world.step()
		loaded.step()
	assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf:")
