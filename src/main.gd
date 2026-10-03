extends Node2D
## Einstiegspunkt: erzeugt die Spielwelt und verbindet sie mit Darstellung und Eingabe.
## Enthält keine Spiellogik – die lebt in der Spielwelt (src/core/).
##
## Startparameter (nach "--"):
##   --scenario=name       Szenario aus data/scenarios/ (Standard: free_play)
##   --seed=123            feste Karte, überschreibt den Seed des Szenarios
##   --found               Burg gleich an der Stelle nächst der Kartenmitte gründen
##   --days=3              Spielwelt vorab gründen und so viele Tage laufen lassen (für Screenshots)
##   --place=woodcutter@x,y  nach der Gründung ein Gebäude mit diesem Ursprung bauen (für Screenshots)
##   --ticks=40            danach so viele Takte laufen lassen (für Screenshots, z. B. laufende Arbeiter)
##   --build=woodcutter    nach der Gründung gleich im Baumodus für diesen Typ (für Screenshots)
##   --demolish            nach der Gründung gleich mit dem Abriss-Werkzeug (für Screenshots)
##   --hover=x,y           Maus gilt als über dieser Kachel (für Screenshots, sonst Kartenmitte)
##   --admin               Verwaltung geöffnet (für Screenshots)
##   --market              Marktansicht geöffnet (für Screenshots)
##   --barracks            Kasernenansicht der ersten Kaserne geöffnet (für Screenshots)
##   --screenshot=pfad.png Bild speichern und beenden (für Tests/Entwicklung)
##
## F5 speichert schnell, F9 lädt diesen Spielstand (bis es ein Menü gibt).
## Eine neue Partie beginnt mit der Gründung: Vorschau von Bergfried, erstem Warenlager,
## erstem Kornspeicher und Lagerfeuer unter der Maus, Linksklick schickt den Gründungsbefehl.
## Danach wählt die Bauleiste (oder L/G/H/B/J/O/P) ein Gebäude: Vorschau unter der Maus,
## Linksklick baut und bleibt im Baumodus, Rechtsklick oder Esc beendet ihn.
## Das Abriss-Werkzeug (Bauleiste oder X) hebt das Gebäude unter der Maus hervor, rot mit
## Grund, wenn es nicht abreißbar ist; Linksklick reißt ohne Rückfrage ab.
## V öffnet und schließt die Verwaltung (Esc schließt sie auch); darin stellen ◀ ▶ bzw. −/+
## die Ration und ◀ ▶ bzw. ,/. den Steuersatz per Befehl ein.
## M öffnet und schließt die Marktansicht mit dem Bestand aller Waren (Esc schließt sie auch).
## Ein Linksklick auf eine Kaserne (ohne Werkzeug) öffnet die Kasernenansicht (Esc schließt sie);
## ihre Knöpfe schicken den Befehl Anwerben.

const QUICKSAVE_PATH := "user://quicksave.sav"

var world: GameWorld

var _scenario: Scenario

var _deposit_views: Dictionary[Vector2i, DepositView] = {}
var _building_views: Dictionary[int, BuildingView] = {}
var _resident_views: Dictionary[int, ResidentView] = {}
var _hovered := Vector2i(-1, -1)
## Gewählter Gebäudetyp im Baumodus, leer = kein Baumodus.
var _build_type := ""
## Abriss-Werkzeug gewählt (schließt den Baumodus aus).
var _demolishing := false
## ID der Kaserne, deren Ansicht offen ist (0 = keine).
var _barracks_id := 0

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
	_hud.ration_step.connect(_step_ration)
	_hud.tax_rate_step.connect(_step_tax_rate)
	_hud.trade_requested.connect(_trade)
	_hud.recruit_requested.connect(_recruit)
	_new_world(int(args["seed"]) if args.has("seed") else _scenario.resolve_seed(randi()))
	var days := int(args.get("days", 0))
	if args.has("found") or days > 0:
		world.execute(Command.found(world.find_founding_site()))
	for i in days * GameWorld.TICKS_PER_DAY:
		world.step()
	if args.has("place"):
		var place := str(args["place"]).split("@")
		var xy := place[1].split(",") if place.size() == 2 else PackedStringArray()
		var reason := "Format: --place=typ@x,y"
		if xy.size() == 2:
			reason = world.execute(Command.build(place[0], Vector2i(int(xy[0]), int(xy[1]))))
		if reason != "":
			printerr("--place: ", reason)
	for i in int(args.get("ticks", 0)):
		world.step()
	if args.has("build"):
		_select_build(str(args["build"]))
	if args.has("demolish"):
		_select_demolish()
	if args.has("admin"):
		_hud.toggle_administration()
	if args.has("market"):
		_hud.toggle_market()
	if args.has("barracks"):
		for building in world.get_buildings():
			if building.is_barracks():
				_open_barracks(building.id)
				break
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
	else:
		var building := world.get_building_at(_hovered)
		if building != null and building.is_barracks():
			_open_barracks(building.id)
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
			# Ist die Verwaltung, die Marktansicht oder die Kasernenansicht offen, schließt Esc nur sie.
			if _hud.is_administration_open():
				_hud.close_administration()
			elif _hud.is_market_open():
				_hud.close_market()
			elif _hud.is_barracks_open():
				_hud.close_barracks()
			else:
				_select_build("")
		KEY_V:
			_hud.toggle_administration()
		KEY_M:
			_hud.toggle_market()
		KEY_MINUS, KEY_KP_SUBTRACT:
			if _hud.is_administration_open():
				_step_ration(-1)
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			if _hud.is_administration_open():
				_step_ration(1)
		KEY_COMMA:
			if _hud.is_administration_open():
				_step_tax_rate(-1)
		KEY_PERIOD:
			if _hud.is_administration_open():
				_step_tax_rate(1)
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
	world.deposit_changed.connect(_on_deposit_changed)
	world.day_started.connect(_hud.show_day)
	world.building_added.connect(_on_building_added)
	world.building_removed.connect(_on_building_removed)
	world.stock_changed.connect(_on_stock_changed)
	world.resident_added.connect(_on_resident_added)
	world.resident_removed.connect(_on_resident_removed)
	world.resident_changed.connect(_on_resident_changed)
	world.founded.connect(_on_founded)
	world.popularity_changed.connect(_update_popularity)
	world.factors_changed.connect(_update_popularity)
	world.settings_changed.connect(_update_popularity)
	world.treasury_changed.connect(_update_treasury)
	world.notice.connect(_hud.show_message)
	_clock.world = world
	_build_type = ""
	_demolishing = false
	_hud.show_tool("", false)
	_barracks_id = 0
	_hud.close_barracks()
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
	for view: ResidentView in _resident_views.values():
		view.queue_free()
	_resident_views.clear()
	for resident in world.get_residents():
		_add_resident_view(resident.id)

	_camera.bounds = Iso.map_bounds(map.width, map.height)
	_camera.focus_on(Iso.tile_to_world(map.center()))
	_hud.set_seed(world.get_seed())
	_hud.show_day(world.get_day())
	_update_stock()
	_update_residents()
	_update_popularity()
	_update_treasury()
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


func _on_deposit_changed(tile: Vector2i) -> void:
	if tile == _hovered:
		_update_hover()


func _add_building_view(id: int) -> void:
	var view := BuildingView.new()
	view.setup(world.get_building(id))
	_objects.add_child(view)
	_building_views[id] = view


func _on_building_added(id: int) -> void:
	_add_building_view(id)
	_update_residents()
	_update_stock()
	_update_hover()
	_update_preview()


func _on_building_removed(id: int) -> void:
	if _building_views.has(id):
		_building_views[id].queue_free()
		_building_views.erase(id)
	if id == _barracks_id:
		_barracks_id = 0
		_hud.close_barracks()
	_update_residents()
	_update_stock()
	_update_hover()
	_update_preview()


func _add_resident_view(id: int) -> void:
	var view := ResidentView.new()
	view.setup(world.get_resident(id), _clock)
	_objects.add_child(view)
	_resident_views[id] = view


func _on_resident_added(id: int) -> void:
	_add_resident_view(id)
	_update_residents()
	_update_hover()


func _on_resident_removed(id: int) -> void:
	if _resident_views.has(id):
		_resident_views[id].queue_free()
		_resident_views.erase(id)
	_update_residents()
	_update_hover()


func _on_resident_changed(_id: int) -> void:
	_update_residents()
	_update_hover()


func _on_stock_changed(_building_id: int) -> void:
	_update_stock()
	# Vor dem ersten Tag hängt die Vorschau der Faktoren am Vorrat.
	_update_popularity()
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
	_preview.show_parts(world.founding_buildings(origin), reason == "")
	if reason == "":
		_hud.show_build_hint("Gründung: Bergfried, Warenlager, Kornspeicher und Lagerfeuer setzen (Linksklick)", true)
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


## Titelleiste: Belegung je Lagerart (Warenlager, Kornspeicher, Waffenkammer); Marktansicht: Bestand je Ware.
func _update_stock() -> void:
	var parts: PackedStringArray = []
	for storage_type: String in Building.storage_types():
		parts.append("%s %d/%d" % [Building.storage_name(storage_type), world.get_storage_used(storage_type),
				world.get_storage_capacity(storage_type)])
	_hud.show_storage("  ·  ".join(parts))
	var stock: Dictionary[String, int] = {}
	for good: String in GameDefs.get_instance().goods:
		stock[good] = world.get_stock(good)
	_hud.show_market_stock(stock)
	_update_market()
	_update_barracks()


## Marktansicht: Handelsknöpfe je Ware mit dem Grund, warum Kauf bzw. Verkauf gerade nicht geht.
func _update_market() -> void:
	var buy_errors: Dictionary[String, String] = {}
	var sell_errors: Dictionary[String, String] = {}
	for good: String in GameDefs.get_instance().goods:
		buy_errors[good] = world.trade_error(good, true)
		sell_errors[good] = world.trade_error(good, false)
	_hud.show_trade_errors(world.market_error(), buy_errors, sell_errors)


## Handel aus der Marktansicht als Befehl abschicken.
func _trade(good: String, buying: bool) -> void:
	_execute_or_show(Command.trade(good, buying))


## Titelleiste: Bewohner, Wohnraum, Untätige und Soldaten.
func _update_residents() -> void:
	_hud.show_residents(world.get_population(), world.get_housing(), world.get_idle_count(),
			world.get_soldier_count())
	_update_barracks()


## Kasernenansicht für die Kaserne mit dieser ID öffnen.
func _open_barracks(id: int) -> void:
	_barracks_id = id
	_hud.open_barracks()
	_update_barracks()


## Kasernenansicht: Untätige, Waffen (die Waren der Anwerbekosten) und je Soldatentyp der
## Grund, warum Anwerben gerade nicht geht.
func _update_barracks() -> void:
	if _barracks_id == 0:
		return
	var weapons: Dictionary[String, int] = {}
	var errors: Dictionary[String, String] = {}
	for good in SoldierType.weapons():
		weapons[good] = world.get_stock(good)
	for type_id in SoldierType.ids():
		errors[type_id] = world.recruit_error(_barracks_id, type_id)
	_hud.show_barracks(world.get_idle_count(), weapons, errors)


## Anwerben aus der Kasernenansicht als Befehl abschicken.
func _recruit(type_id: String) -> void:
	_execute_or_show(Command.recruit(_barracks_id, type_id))


## Ration um delta Stufen ändern (in den Grenzen der Stufen) und als Befehl abschicken.
func _step_ration(delta: int) -> void:
	_execute_or_show(Command.set_ration(_stepped(Population.ration_ids(), world.get_ration(), delta)))


## Steuersatz um delta Stufen ändern (in den Grenzen der Stufen) und als Befehl abschicken.
func _step_tax_rate(delta: int) -> void:
	_execute_or_show(Command.set_tax_rate(_stepped(Population.tax_rate_ids(), world.get_tax_rate(), delta)))


## Die Stufe delta Schritte neben current, begrenzt auf die Liste.
static func _stepped(levels: Array[String], current: String, delta: int) -> String:
	return levels[clampi(levels.find(current) + delta, 0, levels.size() - 1)]


func _execute_or_show(command: Command) -> void:
	var reason := world.execute(command)
	if reason != "":
		_hud.show_message(reason)


## Titelleiste (Beliebtheit, Tendenz) und Verwaltung (Ration, Steuersatz, Faktoren).
func _update_popularity() -> void:
	var total := world.get_factor_sum()
	_hud.show_popularity(world.get_popularity(), total)
	var eaten := Population.ration_name(world.get_eaten_ration()) if world.is_short_of_food() else ""
	_hud.show_administration(Population.ration_name(world.get_ration()), eaten,
			Population.tax_rate_name(world.get_tax_rate()), world.get_factors(), total)


## Titelleiste: Gold im Schatz.
func _update_treasury() -> void:
	_hud.show_treasury(world.get_treasury())
	_update_market()
	_update_barracks()


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
		if building.housing() > 0:
			text += "  ·  Wohnraum +%d" % building.housing()
		if building.is_producer():
			text += "  ·  %d %s → %d %s" % [building.input_amount(), defs.goods[building.input_good()]["name"],
					building.carry_load(), defs.goods[building.product()]["name"]]
		if building.is_workplace():
			text += "  ·  Arbeiter %d/%d" % [world.get_workers(building.id).size(), building.worker_slots()]
			if building.unreachable:
				text += "  ·  Nicht erreichbar"
	var activities: PackedStringArray = []
	for resident in world.get_residents_at(_hovered):
		activities.append(world.activity_of(resident))
	if not activities.is_empty():
		text += "\nBewohner: %s" % ", ".join(activities)
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
