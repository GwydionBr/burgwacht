extends SceneTree
## Szenario-Bot: spielt ein Szenario mit seiner Bauordnung aus tools/bots/ und gibt je Tag den
## Stand aus, am Ende das Ergebnis; über mehrere Seeds eine Übersicht.
## Aufruf: tools/bot.sh <szenario> [--seeds=Anzahl] [--days=Tage] [--quiet]

const DEFAULT_DAYS := 40


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario_id := ""
	for arg in args:
		if not arg.begins_with("--"):
			scenario_id = arg
	if scenario_id == "":
		printerr("Aufruf: tools/bot.sh <szenario> [--seeds=Anzahl] [--days=Tage] [--quiet]")
		quit(1)
		return
	var scenario := Scenario.load_named(scenario_id)
	var bot_error := ScenarioBot.load_named(scenario_id).error
	if scenario.error != "" or bot_error != "":
		printerr(scenario.error if scenario.error != "" else bot_error)
		quit(1)
		return
	var seeds := int(_arg("seeds", "1"))
	var days := int(_arg("days", str(DEFAULT_DAYS)))
	var quiet := args.has("--quiet")
	var results: PackedStringArray = []
	for world_seed in _seeds(scenario, seeds):
		results.append(_play(scenario_id, world_seed, days, quiet))
	if seeds > 1:
		print("\nÜbersicht %s" % scenario_id)
		for line in results:
			print("  " + line)
	quit()


## Die Seeds der Läufe: zuerst der des Szenarios (bei zufälligem 1), dann 1, 2, … ohne Doppelte.
func _seeds(scenario: Scenario, count: int) -> Array[int]:
	var result: Array[int] = [scenario.resolve_seed(1)]
	var next := 1
	while result.size() < count:
		if not result.has(next):
			result.append(next)
		next += 1
	return result


## Spielt eine Partie und liefert die Ergebniszeile.
func _play(scenario_id: String, world_seed: int, days: int, quiet: bool) -> String:
	var bot := ScenarioBot.load_named(scenario_id)
	var world := GameWorld.create(Scenario.load_named(scenario_id), world_seed)
	if not quiet:
		print("\n%s, Seed %d" % [scenario_id, world_seed])
		print("  Tag  Bewohner  Beliebtheit  Gold  Nahrung  Holz  Stein  Soldaten  Feinde  Wellen  Bergfried  Ziele  Schritte")
	var print_row := func(each: GameWorld) -> void:
		if not quiet:
			print("  %3d  %8d  %11d  %4d  %7d  %4d  %5d  %8d  %6d  %6d  %9d  %5s  %8s" % [each.get_day(),
					each.get_population(), each.get_popularity(), each.get_treasury(), _food(each),
					each.get_stock("wood"), each.get_stock("stone"), each.get_soldier_count(),
					each.get_enemies().size(), each.get_repelled_waves(), _keep_hp(each), _goals(each),
					"%d/%d" % [bot.done_steps(), bot.steps.size()]])
	bot.play(world, days, print_row)
	# Der letzte, angebrochene Tag (Sieg, Niederlage oder Ende der Tage).
	if world.get_tick() % GameWorld.TICKS_PER_DAY != 0:
		print_row.call(world)
	if not quiet:
		for line in bot.events:
			print("  " + line)
		for line in world.goal_status():
			print("  " + line)
	var result := "Sieg" if world.is_victorious() else "Niederlage" if world.is_defeated() else "offen"
	var line := "Seed %d: %s an Tag %d, %d Wellen abgewehrt, %d/%d Schritte" % [world_seed, result, world.get_day(),
			world.get_repelled_waves(), bot.done_steps(), bot.steps.size()]
	if not quiet:
		print("  " + line)
	return line


## Lebenspunkte des Bergfrieds (0, wenn er gefallen ist).
func _keep_hp(world: GameWorld) -> int:
	for building in world.get_buildings():
		if building.type == GameWorld.FOUNDING_TYPE:
			return building.hp
	return 0


## Erfüllte Bedingungen des Ziels, z. B. „1/2“; „–“ ohne Ziel.
func _goals(world: GameWorld) -> String:
	var done := 0
	var total := 0
	for line in world.goal_status():
		if line.begins_with("✓") or line.begins_with("○"):
			total += 1
			if line.begins_with("✓"):
				done += 1
	return "–" if total == 0 else "%d/%d" % [done, total]


func _food(world: GameWorld) -> int:
	var total := 0
	for good: String in GameDefs.get_instance().goods:
		if Population.is_food(good):
			total += world.get_stock(good)
	return total


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback
