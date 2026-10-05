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
