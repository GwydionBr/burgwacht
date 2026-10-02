extends Node2D
## Einstiegspunkt: erzeugt die Spielwelt und verbindet sie mit Darstellung und Eingabe.
## Enthält keine Spiellogik – die lebt in der Spielwelt (src/core/).
##
## Startparameter (nach "--"):
##   --scenario=name       Szenario aus data/scenarios/ (Standard: free_play)
##   --seed=123            feste Karte, überschreibt den Seed des Szenarios
##   --days=3              Spielwelt vorab so viele Tage laufen lassen (für Screenshots)
##   --screenshot=pfad.png Bild speichern und beenden (für Tests/Entwicklung)

var world: GameWorld

var _scenario: Scenario

var _deposit_views: Dictionary[Vector2i, DepositView] = {}
var _hovered := Vector2i(-1, -1)

@onready var _clock: GameClock = $Clock
@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _highlight: TileHighlight = $Highlight
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	var args := _parse_user_args()
	_scenario = Scenario.load_named(args.get("scenario", Scenario.DEFAULT))
	if _scenario.error != "":
		printerr("Fehler: ", _scenario.error)
		set_process(false)
		set_process_unhandled_key_input(false)
		get_tree().quit(1)
		return
	_clock.speed_changed.connect(_hud.show_speed)
	_hud.show_speed(_clock.get_speed(), _clock.is_paused())
	_new_world(int(args["seed"]) if args.has("seed") else _scenario.resolve_seed(randi()))
	for i in int(args.get("days", 0)) * GameWorld.TICKS_PER_DAY:
		world.step()
	if args.has("screenshot"):
		_save_screenshot_and_quit(args["screenshot"])


func _process(_delta: float) -> void:
	var tile := Iso.world_to_tile(get_global_mouse_position())
	if tile != _hovered:
		_hovered = tile
		_update_hover()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_N:
			# Neue Karte im selben Szenario, immer mit neuem Zufallsseed.
			_new_world(randi())
		KEY_SPACE:
			_clock.toggle_pause()
		KEY_1, KEY_2, KEY_3:
			_clock.set_speed(GameClock.SPEEDS[key.keycode - KEY_1])
		KEY_F:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _new_world(world_seed: int) -> void:
	world = GameWorld.create(_scenario, world_seed)
	world.deposit_added.connect(_on_deposit_added)
	world.deposit_removed.connect(_on_deposit_removed)
	world.day_started.connect(_hud.show_day)
	_clock.world = world
	var map := world.map
	_terrain.show_map(map)

	for view in _deposit_views.values():
		view.queue_free()
	_deposit_views.clear()
	for tile in map.deposits:
		_add_deposit_view(tile)

	_camera.bounds = Iso.map_bounds(map.width, map.height)
	_camera.focus_on(Iso.tile_to_world(map.center()))
	_hud.set_seed(world_seed)
	_hud.show_day(world.get_day())
	_update_hover()


func _add_deposit_view(tile: Vector2i) -> void:
	var view := DepositView.new()
	view.setup(tile, world.map.deposits[tile])
	_objects.add_child(view)
	_deposit_views[tile] = view


func _on_deposit_added(tile: Vector2i) -> void:
	_add_deposit_view(tile)
	if tile == _hovered:
		_update_hover()


func _on_deposit_removed(tile: Vector2i) -> void:
	if _deposit_views.has(tile):
		_deposit_views[tile].queue_free()
		_deposit_views.erase(tile)
	if tile == _hovered:
		_update_hover()


func _update_hover() -> void:
	var map := world.map
	if not map.in_bounds(_hovered):
		_highlight.visible = false
		_hud.show_tile_info("")
		return
	_highlight.show_tile(_hovered)
	var defs := GameDefs.get_instance()
	var text := "%s  (%d, %d)" % [defs.terrain[map.get_terrain(_hovered)]["name"], _hovered.x, _hovered.y]
	var deposit := map.get_deposit(_hovered)
	if deposit != null:
		var deposit_def: Dictionary = defs.deposits[deposit.type]
		text += "  ·  %s: %d %s" % [deposit_def["name"], deposit.amount, defs.goods[deposit_def["yields"]]["name"]]
	_hud.show_tile_info(text)


func _parse_user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args


func _save_screenshot_and_quit(path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
