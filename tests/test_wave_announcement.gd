extends TestCase
## Simulationstests: Ankündigung der nächsten Welle eine Vorwarnzeit vor ihrem Erscheinen.
## Leere Karte (nur Wiese) 20×16; Bergfried bei (2, 2) mit der Grundfläche (2..5, 2..5).

const KEEP_ORIGIN := Vector2i(2, 2)
## Randkachel im Osten nächst dem Bergfried: Abstand 14, zeilenweise die erste solche.
const EAST_SPAWN := Vector2i(19, 2)
const DAY := GameWorld.TICKS_PER_DAY


## Spielwelt 20×16 (nur Wiese) mit diesem Wellenplan und Seed, noch in Gründung.
func _world_with_plan(plan: Dictionary, world_seed := 7) -> GameWorld:
	var scenario := Scenario.from_dict("test_announcement", {
		"name": "Test", "map": {"width": 20, "height": 16}, "seed": world_seed, "waves": plan})
	assert_eq(scenario.error, "", "Szenario:")
	return clear_map(GameWorld.create(scenario, world_seed))


## Gegründete Spielwelt mit dieser Liste und Vorwarnzeit.
func _founded(list: Array, warning_days := 1, world_seed := 7) -> GameWorld:
	var world := _world_with_plan({"list": list, "warning_days": warning_days}, world_seed)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	return world


## Die Meldungen der Welt ab jetzt.
func _notices(world: GameWorld) -> Array[String]:
	var notices: Array[String] = []
	world.notice.connect(func(text: String) -> void: notices.append(text))
	return notices


## Die Ankündigung, wie sie die Spielwelt herausgibt: [Seite, Kachel, verbleibende Takte].
func _announcement(world: GameWorld) -> Array:
	return [world.get_announced_side(), world.get_announced_tile(), world.get_announced_ticks()]


const NONE := ["", [] as Array[Vector2i], 0]


func test_announcement_starts_one_warning_time_before_and_ends_on_appearance() -> void:
	var world := _founded([{"day": 3, "enemies": {"bandit": 1}, "side": "east"}])
	var notices := _notices(world)
	_run_world(world, DAY - 1)
	assert_eq(_announcement(world), NONE, "Vor Tag 2:")
	world.step()
	assert_eq(_announcement(world), ["east", [EAST_SPAWN] as Array[Vector2i], DAY], "Zu Beginn von Tag 2:")
	assert_eq(notices.filter(func(text: String) -> bool: return text.begins_with("Welle")),
			["Welle aus Osten in 1 Tag"], "Meldung:")
	_run_world(world, DAY - 1)
	assert_eq(_announcement(world), ["east", [EAST_SPAWN] as Array[Vector2i], 1], "Kurz vor dem Erscheinen:")
	world.step()
	assert_eq(_announcement(world), NONE, "Mit dem Erscheinen vorbei:")
	assert_eq(world.get_enemies()[0].tile, EAST_SPAWN, "Erschienen:")


func test_warning_time_comes_from_the_wave_plan() -> void:
	var world := _founded([{"day": 5, "enemies": {"bandit": 1}, "side": "east"}], 2)
	var notices := _notices(world)
	_run_world(world, 2 * DAY - 1)
	assert_eq(world.get_announced_side(), "", "Vor Tag 3:")
	world.step()
	assert_eq(world.get_announced_ticks(), 2 * DAY, "Zu Beginn von Tag 3:")
	assert_eq(notices.filter(func(text: String) -> bool: return text.begins_with("Welle")),
			["Welle aus Osten in 2 Tagen"], "Meldung:")


func test_only_the_next_wave_is_announced() -> void:
	var world := _founded([{"day": 3, "enemies": {"bandit": 1}, "side": "east"},
			{"day": 4, "enemies": {"bandit": 1}, "side": "south"}], 2)
	var notices := _notices(world)
	_run_world(world, DAY)
	# Welle 2 wäre an Tag 2 schon in ihrer Vorwarnzeit, angekündigt ist aber nur Welle 1.
	assert_eq([world.get_announced_side(), world.get_announced_ticks()], ["east", DAY], "Tag 2:")
	_run_world(world, DAY)
	assert_eq([world.get_announced_side(), world.get_announced_ticks()], ["south", DAY], "Tag 3, nach Welle 1:")
	# An Tag 3 erscheint zuerst Welle 1, dann beginnt die Ankündigung von Welle 2.
	assert_eq(notices.filter(func(text: String) -> bool: return text.begins_with("Welle")),
			["Welle aus Osten!", "Welle aus Süden in 1 Tag"], "Meldungen:")


func test_no_announcement_after_the_last_wave() -> void:
	var world := _founded([{"day": 2, "enemies": {"bandit": 1}, "side": "east"}])
	_run_world(world, DAY)
	assert_eq(_announcement(world), NONE, "Nach der letzten Welle:")
	assert_eq(world.get_enemies().size(), 1, "Erschienen:")


func test_wave_due_soon_is_announced_at_founding() -> void:
	var world := _world_with_plan({"list": [{"day": 2, "enemies": {"bandit": 1}, "side": "east"}], "warning_days": 3})
	var notices := _notices(world)
	assert_eq(world.execute(Command.found(KEEP_ORIGIN)), "", "Gründung:")
	assert_eq(_announcement(world), ["east", [EAST_SPAWN] as Array[Vector2i], DAY], "Bei der Gründung:")
	assert_eq(notices, ["Welle aus Osten in 1 Tag"] as Array[String], "Meldung mit der wirklichen Zeit:")


func test_random_side_is_chosen_at_announcement_and_matches_the_appearance() -> void:
	var sides: Dictionary[String, bool] = {}
	for world_seed in range(1, 11):
		var world := _founded([{"day": 3, "enemies": {"bandit": 1}}], 1, world_seed)
		_run_world(world, DAY)
		var side := world.get_announced_side()
		var tile := world.get_announced_tile()
		assert_true(MapSide.is_side(side), "Seite gewählt (Seed %d): %s" % [world_seed, side])
		var notices := _notices(world)
		_run_world(world, DAY)
		assert_eq([world.get_enemies()[0].tile] as Array[Vector2i], tile, "Kachel (Seed %d):" % world_seed)
		assert_true(notices.has("Welle aus %s!" % MapSide.name_of(side)), "Seite (Seed %d): %s" % [world_seed, notices])
		sides[side] = true
	assert_true(sides.size() > 1, "Bei verschiedenen Seeds verschiedene Seiten: %s" % str(sides.keys()))


func test_announced_tile_follows_buildings_on_the_edge() -> void:
	var world := _founded([{"day": 3, "enemies": {"bandit": 1}, "side": "east"}])
	put_goods(world, 2, "stone", 100)
	_run_world(world, DAY)
	build(world, "wall", EAST_SPAWN)
	var tile := world.get_announced_tile()
	assert_true(tile.size() == 1 and tile[0] != EAST_SPAWN and tile[0].x == 19,"Andere Randkachel im Osten: %s" % str(tile))
	_run_world(world, DAY)
	assert_eq(world.get_enemies()[0].tile, tile[0], "Erscheint dort:")


func _reload(world: GameWorld) -> GameWorld:
	return GameWorld.from_data(bytes_to_var(var_to_bytes(world.to_data())))


func test_save_and_load_mid_announcement_keeps_the_side_and_the_course() -> void:
	for world_seed in range(1, 5):
		var world := _founded([{"day": 3, "enemies": {"bandit": 2}}, {"day": 4, "enemies": {"bandit": 1}}], 1, world_seed)
		_run_world(world, DAY + 100)
		var loaded := _reload(world)
		assert_eq(world_snapshot(loaded), world_snapshot(world), "Zustand nach dem Laden (Seed %d):" % world_seed)
		assert_eq(_announcement(loaded), _announcement(world), "Ankündigung geladen (Seed %d):" % world_seed)
		_run_world(world, DAY)
		_run_world(loaded, DAY)
		assert_eq(loaded.to_data(), world.to_data(), "Gleicher Verlauf (Seed %d):" % world_seed)


func test_debug_wave_takes_the_announced_side_and_the_next_announcement_begins() -> void:
	var world := _founded([{"day": 2, "enemies": {"bandit": 1}}, {"day": 3, "enemies": {"bandit": 1}, "side": "south"}])
	var side := world.get_announced_side()
	var tile := world.get_announced_tile()
	assert_eq(world.execute(Command.spawn_wave()), "", "Debug-Welle:")
	assert_eq([world.get_enemies()[0].tile] as Array[Vector2i], tile, "Auf der angekündigten Kachel (%s):" % side)
	# Welle 2 kommt an Tag 3; ihre Vorwarnzeit beginnt an Tag 2, also noch nicht.
	assert_eq(_announcement(world), NONE, "Keine Ankündigung an Tag 1:")
	_run_world(world, DAY)
	assert_eq(world.get_announced_side(), "south", "Ankündigung von Welle 2 an Tag 2:")
	assert_eq(world.get_enemies().size(), 1, "An Tag 2 keine weitere Welle:")


func test_after_the_debug_wave_the_next_announcement_begins_at_once() -> void:
	# Vorwarnzeit 2 Tage: Welle 2 (Tag 3) ist schon an Tag 1 in ihrer Vorwarnzeit.
	var world := _founded([{"day": 2, "enemies": {"bandit": 1}, "side": "east"},
			{"day": 3, "enemies": {"bandit": 1}, "side": "south"}], 2)
	var notices := _notices(world)
	assert_eq(world.execute(Command.spawn_wave()), "", "Debug-Welle:")
	assert_eq([world.get_announced_side(), world.get_announced_ticks()], ["south", 2 * DAY], "Sofort, ohne Takt:")
	assert_eq(notices.filter(func(text: String) -> bool: return text.begins_with("Welle")),
			["Welle aus Osten!", "Welle aus Süden in 2 Tagen"], "Meldungen:")
