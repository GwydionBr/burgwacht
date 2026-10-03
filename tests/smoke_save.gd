extends SceneTree
## Schreibt einen Spielstand für den Rauchtest (tools/smoke.sh): leere tiny_production-Karte,
## gegründet, mit Waffenkammer, Kaserne und zwei Schwertkämpfern, die schon zum Posten laufen.
## Aufruf: godot --headless --path . --script res://tests/smoke_save.gd -- /pfad/zum.sav
## Wird bei jedem Rauchtest neu erzeugt und passt deshalb immer zum Speicherformat.

const KEEP_ORIGIN := Vector2i(2, 2)
const ARMORY_SITE := Vector2i(10, 10)
const BARRACKS_SITE := Vector2i(14, 2)
const SOLDIERS := 2
## So viele Takte nach dem Anwerben: Die Soldaten sind unterwegs.
const TICKS := 20


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Aufruf: … --script res://tests/smoke_save.gd -- /pfad/zum.sav")
		quit(1)
		return
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	var reason := world.execute(Command.found(KEEP_ORIGIN))
	var armory := helper.build(world, "armory", ARMORY_SITE)
	helper.put_goods(world, armory, "sword", SOLDIERS)
	var barracks := helper.build(world, "barracks", BARRACKS_SITE)
	for i in SOLDIERS:
		if reason == "":
			reason = world.execute(Command.recruit(barracks, "swordsman"))
	if reason != "":
		printerr("Spielstand für den Rauchtest: ", reason)
		quit(1)
		return
	for i in TICKS:
		world.step()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("Spielstand für den Rauchtest: ", error_string(FileAccess.get_open_error()))
		quit(1)
		return
	file.store_var(world.to_data())
	file.close()
	quit()
