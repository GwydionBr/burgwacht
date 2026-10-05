extends TestCase
## Die Tonregie (SoundDirector): Ereignisse hinein, Abspielwünsche (SoundWish) heraus – ohne
## Tonausgabe, mit festgelegtem Zufall.

const SEED := 42

var _data := SoundData.load_file()
## Die Wünsche, die die Tonregie seit dem Anlegen geäußert hat.
var _wishes: Array[SoundWish] = []


func _director(random_seed := SEED) -> SoundDirector:
	var director := SoundDirector.new(_data, random_seed)
	director.wished.connect(_wishes.append)
	return director


## Die Anlässe der bisher geäußerten Wünsche, in Reihenfolge.
func _occasions() -> Array[String]:
	var occasions: Array[String] = []
	for wish in _wishes:
		occasions.append(wish.occasion)
	return occasions


func test_button_press_wishes_button_sound() -> void:
	_director().button_pressed()
	assert_eq(_occasions(), ["button"] as Array[String], "Anlässe:")
	var wish := _wishes[0]
	assert_eq(wish.volume, _data.sound("button").volume, "Lautstärkefaktor = Grundlautstärke:")
	assert_eq(wish.pan, 0.0, "Panorama:")
	assert_true(wish.variant >= 0 and wish.variant < _data.variant_count("button"), "Variante %d" % wish.variant)
	assert_true(absf(wish.pitch - 1.0) <= _data.pitch_variation, "Tonhöhe %f" % wish.pitch)


## Variante und Tonhöhe der Wünsche zu count Knopfdrücken mit diesem Seed.
func _button_wishes(random_seed: int, count: int) -> Array[Vector2]:
	_wishes.clear()
	var director := _director(random_seed)
	for i in count:
		director.button_pressed()
	var result: Array[Vector2] = []
	for wish in _wishes:
		result.append(Vector2(wish.variant, wish.pitch))
	return result


func test_variant_and_pitch_follow_the_seed() -> void:
	var first := _button_wishes(SEED, 20)
	assert_eq(_button_wishes(SEED, 20), first, "gleicher Seed, gleiche Wünsche:")
	assert_true(_button_wishes(SEED + 1, 20) != first, "anderer Seed, andere Wünsche")
	var variants := {}
	var pitches := {}
	for wish in first:
		variants[int(wish.x)] = true
		pitches[wish.y] = true
		assert_true(absf(wish.y - 1.0) <= _data.pitch_variation, "Tonhöhe %f innerhalb der Schwankung" % wish.y)
	assert_eq(variants.size(), _data.variant_count("button"), "verschiedene Varianten in 20 Wünschen:")
	assert_true(pitches.size() > 1, "Tonhöhe schwankt")


func test_standing_time_silences_game_sounds_only() -> void:
	# Bisher löst nur die Bedienung etwas aus; hier ist der Handel daher ein Spielgeräusch.
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SoundData.PATH))
	raw["sounds"]["trade"]["group"] = SoundData.GROUP_GAME
	_data = SoundData.from_dict(raw)
	var director := _director()
	director.time_stands = true
	director.command_executed(Command.trade("wood", true), "")
	director.command_executed(Command.demolish(7), "")
	director.button_pressed()
	assert_eq(_occasions(), ["demolish", "button"] as Array[String], "Anlässe bei stehender Zeit:")
	director.time_stands = false
	director.command_executed(Command.trade("wood", true), "")
	assert_eq(_occasions(), ["demolish", "button", "trade"] as Array[String], "Anlässe, wenn die Zeit wieder läuft:")


## Ton hat einen eigenen Zufall (ADR 0001): Eine Partie mit Tonregie verläuft genau wie eine ohne.
func test_world_randomness_stays_untouched() -> void:
	var heard := run_scenario("tiny", 0)
	var silent := run_scenario("tiny", 0)
	var director := _director()
	for world: GameWorld in [heard, silent]:
		var command := Command.build("woodcutter", find_site(world, "woodcutter"))
		var error := world.execute(command)
		if world == heard:
			director.command_executed(command, error)
			for i in 10:
				director.button_pressed()
		for i in 200:
			world.step()
	assert_true(_wishes.size() == 11, "Die Tonregie hat gewünscht")
	assert_eq(world_snapshot(heard), world_snapshot(silent), "Spielwelt mit und ohne Tonregie:")
	assert_eq(heard.to_data()["rng"], silent.to_data()["rng"], "Zufall der Spielwelt mit und ohne Tonregie:")


## Kaputte Geräuschdatei: Der Fehler steht in SoundData.error; die Tonregie schweigt dann.
func test_invalid_data_stays_silent() -> void:
	_data = SoundData.from_dict({})
	var director := _director()
	director.button_pressed()
	director.command_executed(Command.trade("wood", true), "")
	assert_eq(_occasions(), [] as Array[String], "Anlässe:")


func test_successful_commands_wish_their_sound() -> void:
	var cases := [
		[Command.build("woodcutter", Vector2i(3, 3)), "building_placed"],
		[Command.build_line("wall", Vector2i(3, 3), Vector2i(6, 3)), "building_placed"],
		[Command.found(Vector2i(8, 8)), "building_placed"],
		[Command.demolish(7), "demolish"],
		[Command.recruit(7, "swordsman"), "recruit"],
		[Command.trade("wood", true), "trade"],
		[Command.trade("wood", false), "trade"],
	]
	for entry: Array in cases:
		_wishes.clear()
		var command: Command = entry[0]
		_director().command_executed(command, "")
		assert_eq(_occasions(), [entry[1]] as Array[String], "Anlässe nach Befehl %s:" % Command.Kind.keys()[command.kind])
		assert_eq(_wishes[0].volume, _data.sound(entry[1]).volume, "Lautstärkefaktor zu %s:" % entry[1])


func test_other_successful_commands_stay_silent() -> void:
	var director := _director()
	director.command_executed(Command.set_ration("half"), "")
	director.command_executed(Command.set_tax_rate("none"), "")
	director.command_executed(Command.move([1] as Array[int], Vector3i(2, 2, 0)), "")
	director.command_executed(Command.attack([1] as Array[int], 3), "")
	assert_eq(_occasions(), [] as Array[String], "Anlässe:")


func test_rejected_command_wishes_rejection_sound() -> void:
	var director := _director()
	director.command_executed(Command.build("woodcutter", Vector2i(3, 3)), "Nicht genug Holz")
	director.command_executed(Command.set_ration("half"), "Unbekannte Ration")
	director.command_executed(Command.trade("wood", true), "Kein Markt gebaut")
	assert_eq(_occasions(), ["command_rejected", "command_rejected", "command_rejected"] as Array[String], "Anlässe:")


## Ein sichtbarer Ausschnitt (Weltkoordinaten) der Breite 400 um die Mitte der Kachel tile,
## um offset verschoben.
func _area_around(tile: Vector2i, offset := Vector2.ZERO) -> Rect2:
	return Rect2(Iso.tile_to_world(tile) + offset - Vector2(200, 150), Vector2(400, 300))


func test_arrow_in_view_is_fully_audible_and_fades_outside() -> void:
	var director := _director()
	var shooter := Vector3i(10, 4, 0)
	var tile := Vector2i(10, 4)
	var base := _data.sound("arrow_shot").volume
	director.visible_area = _area_around(tile)
	director.arrow_shot(shooter, Vector3i(12, 4, 0))
	assert_eq(_occasions(), ["arrow_shot"] as Array[String], "Pfeil im Ausschnitt:")
	assert_eq(_wishes[0].volume, base, "im Ausschnitt voll hörbar:")
	# Der Ausschnitt endet links vom Schützen, halb so weit weg wie die feste Entfernung.
	director.visible_area = _area_around(tile, Vector2(-200 - SoundDirector.AUDIBLE_DISTANCE / 2.0, 0))
	director.arrow_shot(shooter, Vector3i(12, 4, 0))
	assert_eq(_wishes.size(), 2, "Pfeil außerhalb, aber nah genug:")
	assert_true(_wishes[1].volume > 0.0 and _wishes[1].volume < base, "außerhalb leiser: %f" % _wishes[1].volume)
	# Ab der festen Entfernung entfällt er.
	director.visible_area = _area_around(tile, Vector2(-200 - SoundDirector.AUDIBLE_DISTANCE - 1.0, 0))
	director.arrow_shot(shooter, Vector3i(12, 4, 0))
	assert_eq(_wishes.size(), 2, "Pfeil jenseits der festen Entfernung:")


func test_arrow_pans_by_its_horizontal_place_in_view() -> void:
	var director := _director()
	var tile := Vector2i(10, 4)
	for offset: Vector2 in [Vector2(150, 0), Vector2(0, 0), Vector2(-150, 0), Vector2(-200 - SoundDirector.AUDIBLE_DISTANCE / 2.0, 0)]:
		director.visible_area = _area_around(tile, offset)
		director.arrow_shot(Vector3i(tile.x, tile.y, 0), Vector3i(12, 4, 0))
	assert_eq(_wishes.size(), 4, "Wünsche:")
	assert_true(_wishes[0].pan < -0.5, "links im Bild → Panorama links: %f" % _wishes[0].pan)
	assert_eq(_wishes[1].pan, 0.0, "Mitte des Bilds → Panorama Mitte:")
	assert_true(_wishes[2].pan > 0.5, "rechts im Bild → Panorama rechts: %f" % _wishes[2].pan)
	assert_eq(_wishes[3].pan, 1.0, "rechts außerhalb → ganz rechts:")


func test_fifth_simultaneous_wish_of_an_occasion_is_dropped() -> void:
	var director := _director()
	var tile := Vector2i(10, 4)
	director.visible_area = _area_around(tile)
	for i in 5:
		director.arrow_shot(Vector3i(tile.x, tile.y, 0), Vector3i(12, 4, 0))
	assert_eq(_wishes.size(), 4, "Wünsche bei 5 gleichzeitigen Pfeilen:")
	director.button_pressed()
	assert_eq(_wishes.size(), 5, "Ein anderer Anlass klingt trotzdem:")
	director.sound_finished(_wishes[0])
	director.arrow_shot(Vector3i(tile.x, tile.y, 0), Vector3i(12, 4, 0))
	director.arrow_shot(Vector3i(tile.x, tile.y, 0), Vector3i(12, 4, 0))
	assert_eq(_occasions(), ["arrow_shot", "arrow_shot", "arrow_shot", "arrow_shot", "button", "arrow_shot"] as Array[String], "nach einem ausgeklungenen Pfeil wieder einer:")


func test_building_hit_only_when_its_hit_points_changed() -> void:
	var director := _director()
	var building := Building.create(3, "tower", Vector2i(10, 4))
	director.visible_area = _area_around(Vector2i(10, 4))
	director.building_changed(building)
	assert_eq(_occasions(), [] as Array[String], "volle Lebenspunkte, kein Treffer:")
	building.hp -= 10
	director.building_changed(building)
	assert_eq(_occasions(), ["building_hit"] as Array[String], "Lebenspunkte gesunken:")
	assert_eq(_wishes[0].volume, _data.sound("building_hit").volume, "im Ausschnitt voll hörbar:")
	director.building_changed(building)
	assert_eq(_occasions(), ["building_hit"] as Array[String], "dieselben Lebenspunkte noch einmal gemeldet:")
	var other := Building.create(4, "tower", Vector2i(20, 4))
	other.hp -= 10
	director.building_changed(other)
	assert_eq(_occasions(), ["building_hit", "building_hit"] as Array[String], "ein anderes Gebäude getroffen:")


func test_standing_time_silences_combat_sounds() -> void:
	var director := _director()
	var building := Building.create(3, "tower", Vector2i(10, 4))
	director.visible_area = _area_around(Vector2i(10, 4))
	director.time_stands = true
	director.arrow_shot(Vector3i(10, 4, 0), Vector3i(12, 4, 0))
	building.hp -= 10
	director.building_changed(building)
	assert_eq(_occasions(), [] as Array[String], "Anlässe bei stehender Zeit:")
