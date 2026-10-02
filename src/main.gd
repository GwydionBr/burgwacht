extends Node2D
## Einstiegspunkt: erzeugt die Spielwelt und verbindet sie mit Darstellung und Eingabe.
## Enthält keine Spiellogik – die lebt in der Spielwelt (src/core/).
##
## Startparameter (nach "--"):
##   --scenario=name       Szenario aus data/scenarios/ (Standard: free_play)
##   --seed=123            feste Karte, überschreibt den Seed des Szenarios
##   --found               Burg gleich an der Stelle nächst der Kartenmitte gründen
##   --days=3              Spielwelt vorab gründen und so viele Tage laufen lassen (für Screenshots)
##   --build=woodcutter    nach der Gründung gleich im Baumodus für diesen Typ (für Screenshots)
##   --demolish            nach der Gründung gleich mit dem Abriss-Werkzeug (für Screenshots)
##   --hover=x,y           Maus gilt als über dieser Kachel (für Screenshots, sonst Kartenmitte)
##   --screenshot=pfad.png Bild speichern und beenden (für Tests/Entwicklung)
##
## F5 speichert schnell, F9 lädt diesen Spielstand (bis es ein Menü gibt).
## Eine neue Partie beginnt mit der Gründung: Vorschau von Bergfried und erstem
## Warenlager unter der Maus, Linksklick schickt den Gründungsbefehl.
## Danach wählt die Bauleiste (oder L/H/B) ein Gebäude: Vorschau unter der Maus,
## Linksklick baut und bleibt im Baumodus, Rechtsklick oder Esc beendet ihn.
## Das Abriss-Werkzeug (Bauleiste oder X) hebt das Gebäude unter der Maus hervor, rot mit
## Grund, wenn es nicht abreißbar ist; Linksklick reißt ohne Rückfrage ab.

const QUICKSAVE_PATH := "user://quicksave.sav"

var world: GameWorld

var _scenario: Scenario

var _deposit_views: Dictionary[Vector2i, DepositView] = {}
var _building_views: Dictionary[int, BuildingView] = {}
var _hovered := Vector2i(-1, -1)
## Gewählter Gebäudetyp im Baumodus, leer = kein Baumodus.
var _build_type := ""
## Abriss-Werkzeug gewählt (schließt den Baumodus aus).
var _demolishing := false

@onready var _clock: GameClock = $Clock
@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _highlight: TileHighlight = $Highlight
@onready var _preview: PlacementPreview = $Preview
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
	_hud.build_selected.connect(_select_build)
	_hud.demolish_selected.connect(_select_demolish)
	_new_world(int(args["seed"]) if args.has("seed") else _scenario.resolve_seed(randi()))
	var days := int(args.get("days", 0))
	if args.has("found") or days > 0:
		world.execute(Command.found(world.find_founding_site()))
	for i in days * GameWorld.TICKS_PER_DAY:
		world.step()
	if args.has("build"):
		_select_build(str(args["build"]))
	if args.has("demolish"):
		_select_demolish()
	if args.has("screenshot"):
		# Unabhängig vom echten Mauszeiger: Maus gilt als über der Kartenmitte oder --hover.
		set_process(false)
		_hovered = world.map.center()
		var hover := str(args.get("hover", "")).split(",")
		if hover.size() == 2:
			_hovered = Vector2i(int(hover[0]), int(hover[1]))
		_update_hover()
		_update_preview()
		_save_screenshot_and_quit(args["screenshot"])


func _process(_delta: float) -> void:
	var tile := Iso.world_to_tile(get_global_mouse_position())
	if tile != _hovered:
		_hovered = tile
		_update_hover()
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		# Nicht als behandelt markieren: Die Kamera zieht weiterhin mit der rechten Taste.
		_select_build("")
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	var reason := ""
	if world.is_founding():
		reason = world.execute(Command.found(_origin_under_mouse(GameWorld.FOUNDING_TYPE)))
	elif _build_type != "":
		reason = world.execute(Command.build(_build_type, _origin_under_mouse(_build_type)))
	elif _demolishing:
		var building := world.get_building_at(_hovered)
		if building != null:
			reason = world.execute(Command.demolish(building.id))
	if reason != "":
		_hud.show_message(reason)


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
		KEY_F5:
			_quick_save()
		KEY_F9:
			_quick_load()
		KEY_ESCAPE:
			_select_build("")
		KEY_X:
			_select_demolish()
		KEY_F:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		_:
			for type_id in GameWorld.buildable_types():
				if OS.find_keycode_from_string(str(GameDefs.get_instance().buildings[type_id]["hotkey"])) == key.keycode:
					_select_build(type_id)


func _new_world(world_seed: int) -> void:
	_show_world(GameWorld.create(_scenario, world_seed))


## Verbindet eine Spielwelt mit Takt, Darstellung und HUD; alte Darstellung fliegt raus.
func _show_world(new_world: GameWorld) -> void:
	world = new_world
	world.deposit_added.connect(_on_deposit_added)
	world.deposit_removed.connect(_on_deposit_removed)
	world.day_started.connect(_hud.show_day)
	world.building_added.connect(_on_building_added)
	world.building_removed.connect(_on_building_removed)
	world.stock_changed.connect(_on_stock_changed)
	world.founded.connect(_on_founded)
	_clock.world = world
	_build_type = ""
	_demolishing = false
	_hud.show_tool("", false)
	_hud.set_build_bar_enabled(not world.is_founding())
	var map := world.map
	_terrain.show_map(map)

	for view in _deposit_views.values():
		view.queue_free()
	_deposit_views.clear()
	for tile in map.deposits:
		_add_deposit_view(tile)
	for view: BuildingView in _building_views.values():
		view.queue_free()
	_building_views.clear()
	for building in world.get_buildings():
		_add_building_view(building.id)

	_camera.bounds = Iso.map_bounds(map.width, map.height)
	_camera.focus_on(Iso.tile_to_world(map.center()))
	_hud.set_seed(world.get_seed())
	_hud.show_day(world.get_day())
	_update_stock()
	_update_hover()
	_update_preview()


func _quick_save() -> void:
	var file := FileAccess.open(QUICKSAVE_PATH, FileAccess.WRITE)
	if file == null:
		_hud.show_message("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_var(world.to_data())
	file.close()
	_hud.show_message("Gespeichert (Tag %d)" % world.get_day())


func _quick_load() -> void:
	if not FileAccess.file_exists(QUICKSAVE_PATH):
		_hud.show_message("Noch kein Spielstand – erst mit F5 speichern")
		return
	var file := FileAccess.open(QUICKSAVE_PATH, FileAccess.READ)
	var data: Variant = file.get_var() if file != null else null
	if not data is Dictionary:
		_hud.show_message("Spielstand ist beschädigt")
		return
	var error := GameWorld.data_error(data)
	if error != "":
		_hud.show_message(error)
		return
	var loaded := GameWorld.from_data(data)
	# Neue Karte (N) danach im Szenario des Spielstands.
	var scenario := Scenario.load_named(loaded.get_scenario_id())
	if scenario.error == "":
		_scenario = scenario
	_show_world(loaded)
	_hud.show_message("Geladen (Tag %d)" % world.get_day())


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


func _add_building_view(id: int) -> void:
	var view := BuildingView.new()
	view.setup(world.get_building(id))
	_objects.add_child(view)
	_building_views[id] = view


func _on_building_added(id: int) -> void:
	_add_building_view(id)
	_update_hover()
	_update_preview()


func _on_building_removed(id: int) -> void:
	if _building_views.has(id):
		_building_views[id].queue_free()
		_building_views.erase(id)
	_update_hover()
	_update_preview()


func _on_stock_changed(_building_id: int) -> void:
	_update_stock()
	_update_hover()
	_update_preview()


func _on_founded() -> void:
	_hud.set_build_bar_enabled(true)
	_update_preview()
	_hud.show_message("Burg gegründet – Leertaste startet die Zeit")


## Ursprung eines Gebäudes dieses Typs, dessen Grundfläche mittig unter der Maus liegt.
@warning_ignore("integer_division")
func _origin_under_mouse(type_id: String) -> Vector2i:
	return _hovered - Building.size_of(type_id) / 2


## Baumodus für einen Gebäudetyp beginnen (leer = beenden, auch den Abriss); in der
## Gründung gesperrt.
func _select_build(type_id: String) -> void:
	_select_tool(type_id, false)


## Abriss-Werkzeug wählen; in der Gründung gesperrt.
func _select_demolish() -> void:
	_select_tool("", true)


func _select_tool(build_type: String, demolishing: bool) -> void:
	if (build_type != "" or demolishing) and world.is_founding():
		_hud.show_message(GameWorld.FOUNDING_FIRST)
		build_type = ""
		demolishing = false
	_build_type = build_type
	_demolishing = demolishing
	_hud.show_tool(build_type, demolishing)
	_update_preview()


func _update_preview() -> void:
	if not world.is_founding():
		_update_build_preview()
		return
	var origin := _origin_under_mouse(GameWorld.FOUNDING_TYPE)
	var reason := world.founding_error(origin)
	var parts: Array[Array] = [
		[GameWorld.FOUNDING_TYPE, origin],
		[world.founding_storage_type(), world.founding_storage_origin(origin)],
	]
	_preview.show_parts(parts, reason == "")
	if reason == "":
		_hud.show_build_hint("Gründung: Bergfried und Warenlager setzen (Linksklick)", true)
	else:
		_hud.show_build_hint("Gründung: %s" % reason, false)


func _update_build_preview() -> void:
	if _demolishing:
		_update_demolish_preview()
		return
	if _build_type == "":
		_preview.visible = false
		_hud.show_build_hint("", true)
		return
	var origin := _origin_under_mouse(_build_type)
	var reason := world.build_error(_build_type, origin)
	_preview.show_parts([[_build_type, origin]] as Array[Array], reason == "")
	var building_name: String = GameDefs.get_instance().buildings[_build_type]["name"]
	if reason == "":
		_hud.show_build_hint("%s setzen (Linksklick)  ·  Rechtsklick/Esc: beenden" % building_name, true)
	else:
		_hud.show_build_hint("%s: %s" % [building_name, reason], false)


## Abriss: Gebäude unter der Maus hervorheben, mit Grund, wenn es nicht abreißbar ist.
func _update_demolish_preview() -> void:
	var building := world.get_building_at(_hovered)
	if building == null:
		_preview.visible = false
		_hud.show_build_hint("Abriss: Gebäude anklicken  ·  Rechtsklick/Esc: beenden", true)
		return
	var reason := world.demolish_error(building.id)
	_preview.show_demolish(building.type, building.origin, reason == "")
	var building_name: String = building.def()["name"]
	if reason == "":
		_hud.show_build_hint("%s abreißen (Linksklick)  ·  Rechtsklick/Esc: beenden" % building_name, true)
	else:
		_hud.show_build_hint("Abriss: %s" % reason, false)


## Titelleiste: Bestand je Ware der Lagerart Warenlager und Belegung.
func _update_stock() -> void:
	var defs := GameDefs.get_instance()
	var parts: PackedStringArray = []
	for good: String in defs.goods:
		if defs.goods[good]["storage"] == "warehouse":
			parts.append("%s %d" % [defs.goods[good]["name"], world.get_stock(good)])
	parts.append("Lager %d/%d" % [world.get_storage_used("warehouse"), world.get_storage_capacity("warehouse")])
	_hud.show_stock("  ·  ".join(parts))


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
	var building := world.get_building_at(_hovered)
	if building != null:
		text += "  ·  %s" % building.def()["name"]
		if building.is_storage():
			var stored: PackedStringArray = []
			for good: String in building.contents:
				stored.append("%d %s" % [building.contents[good], defs.goods[good]["name"]])
			text += " (%d/%d): %s" % [building.stored(), building.capacity(), ", ".join(stored) if not stored.is_empty() else "leer"]
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
