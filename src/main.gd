extends Node2D
## Einstiegspunkt: erzeugt die Karte und verbindet Spiellogik mit Darstellung.
##
## Startparameter (nach "--"):
##   --seed=123            feste Karte statt Zufall
##   --screenshot=pfad.png Bild speichern und beenden (für Tests/Entwicklung)

const MAP_SIZE := Vector2i(80, 80)

var map: MapData

var _deposit_views: Dictionary[Vector2i, DepositView] = {}
var _hovered := Vector2i(-1, -1)

@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _highlight: TileHighlight = $Highlight
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	var args := _parse_user_args()
	_new_map(int(args["seed"]) if args.has("seed") else randi())
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
			_new_map(randi())
		KEY_F:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _new_map(map_seed: int) -> void:
	map = MapGenerator.generate(map_seed, MAP_SIZE.x, MAP_SIZE.y)
	map.deposit_removed.connect(_on_deposit_removed)
	_terrain.show_map(map)

	for view in _deposit_views.values():
		view.queue_free()
	_deposit_views.clear()
	for tile in map.deposits:
		var view := DepositView.new()
		view.setup(tile, map.deposits[tile])
		_objects.add_child(view)
		_deposit_views[tile] = view

	_camera.bounds = Iso.map_bounds(map.width, map.height)
	_camera.focus_on(Iso.tile_to_world(map.center()))
	_hud.set_seed(map_seed)
	_update_hover()


func _on_deposit_removed(tile: Vector2i) -> void:
	if _deposit_views.has(tile):
		_deposit_views[tile].queue_free()
		_deposit_views.erase(tile)


func _update_hover() -> void:
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
