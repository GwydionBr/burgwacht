extends SceneTree
## Headless-Messung: wächst Taktzeit, Speicher oder die Node-Zahl mit der Spieldauer?
## Aufruf: tools/profile.sh [Tage]
## Unterscheidet Leak (gleicher Weltumfang, mehr Kosten) von wachsender Simulation.

const DEFAULT_DAYS := 12
const VIEW_SAMPLE_FRAMES := 20
const WOODCUTTERS := 4
const HOUSES := 4


func _initialize() -> void:
	var days := _days()
	print("PROFILE\tcore idle founded free_play, %d Tage, Seed 1" % days)
	_profile_core(_founded_world(), days)
	print("PROFILE\tcore busy houses+woodcutters+extra ration, %d Tage, Seed 1" % days)
	_profile_core(_busy_world(), days)
	_start_view(days)


func _days() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-days="):
			return int(arg.get_slice("=", 1))
	return DEFAULT_DAYS


func _founded_world() -> GameWorld:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	var world := GameWorld.create(scenario, 1)
	var reason := world.execute(Command.found(world.find_founding_site()))
	assert(reason == "", "Gründung: %s" % reason)
	return world


func _busy_world() -> GameWorld:
	var world := _founded_world()
	var helper := TestCase.new()
	world.execute(Command.set_ration("extra"))
	for i in HOUSES:
		var site := helper.find_site(world, "house")
		assert(site != GameWorld.NO_SITE, "Kein Platz für Wohnhaus %d" % (i + 1))
		helper.build(world, "house", site)
	for i in WOODCUTTERS:
		var site := helper.find_site(world, "woodcutter")
		assert(site != GameWorld.NO_SITE, "Kein Platz für Holzfäller %d" % (i + 1))
		helper.build(world, "woodcutter", site)
	return world


func _profile_core(world: GameWorld, days: int) -> void:
	print("PROFILE\tday\tus_per_tick\tmax_tick_ms\tresidents\tbuildings\tdeposits\tenemies\tmem_kb\tobjects\tpath_n\tpath_ms\tdist_n\tdist_ms")
	Pathfinder.reset_profile()
	_print_core_row(world, 0.0, 0)
	for day in days:
		Pathfinder.reset_profile()
		var started := Time.get_ticks_usec()
		var longest := 0
		for i in GameWorld.TICKS_PER_DAY:
			var tick_started := Time.get_ticks_usec()
			world.step()
			longest = maxi(longest, Time.get_ticks_usec() - tick_started)
		var us_per_tick := float(Time.get_ticks_usec() - started) / float(GameWorld.TICKS_PER_DAY)
		_print_core_row(world, us_per_tick, longest)


## longest_us: der längste einzelne Takt – ein Ruckler im Spiel, auch wenn der Schnitt klein ist.
func _print_core_row(world: GameWorld, us_per_tick: float, longest_us: int) -> void:
	print("PROFILE\t%d\t%.1f\t%.1f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.1f\t%d\t%.1f" % [
		world.get_day(),
		us_per_tick,
		float(longest_us) / 1000.0,
		world.get_residents().size(),
		world.get_buildings().size(),
		world.map.deposits.size(),
		world.get_enemies().size(),
		OS.get_static_memory_usage() / 1024,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Pathfinder.path_calls,
		float(Pathfinder.path_us) / 1000.0,
		Pathfinder.distance_calls,
		float(Pathfinder.distance_us) / 1000.0,
	])


func _start_view(days: int) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene := packed.instantiate() as MatchScene
	root.add_child(scene)
	var sampler := ViewSampler.new()
	sampler.days = days
	root.add_child(sampler)


class ViewSampler:
	extends Node

	var days := 12
	var _scene: MatchScene
	var _clock: GameClock
	var _phase := 0
	var _frames := 0
	var _process_us := 0
	var _last_usec := 0


	func _ready() -> void:
		_scene = get_parent().get_node("Main") as MatchScene
		_clock = _scene.get_node("Clock") as GameClock
		if not _clock.is_paused():
			_clock.toggle_pause()
		_last_usec = Time.get_ticks_usec()
		print("PROFILE\tview paused frames after founding, then after %d more days" % days)


	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		_process_us += now - _last_usec
		_last_usec = now
		_frames += 1
		if _frames < VIEW_SAMPLE_FRAMES:
			return
		_print_view_row("after_founding" if _phase == 0 else "after_%d_days" % days)
		if _phase == 0:
			var world := _scene.world
			var started := Time.get_ticks_usec()
			for i in days * GameWorld.TICKS_PER_DAY:
				world.step()
			print("PROFILE\tview bulk_step_ms\t%.1f" % (float(Time.get_ticks_usec() - started) / 1000.0))
			_phase = 1
			_frames = 0
			_process_us = 0
			_last_usec = Time.get_ticks_usec()
			return
		get_tree().quit()


	func _print_view_row(label: String) -> void:
		var world := _scene.world
		print("PROFILE\tview\t%s\tus_per_frame\t%.1f\tnodes\t%d\torphans\t%d\tmem_kb\t%d\tobjects\t%d\tresidents\t%d\tbuildings\t%d\tdeposits\t%d\tenemies\t%d" % [
			label,
			float(_process_us) / float(_frames),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			OS.get_static_memory_usage() / 1024,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			world.get_residents().size(),
			world.get_buildings().size(),
			world.map.deposits.size(),
			world.get_enemies().size(),
		])
