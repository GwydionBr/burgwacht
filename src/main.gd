class_name MatchScene
extends Node2D
## Einstiegspunkt der Partie-Szene: startet die Partie (Match) aus der Startbeschreibung und
## verbindet ihre Spielwelt mit Darstellung und Eingabe. Enthält keine Spiellogik – die lebt in
## der Spielwelt (src/core/).
##
## Startparameter (nach "--"; jeder davon überspringt das Hauptmenü):
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
##   --load=pfad.sav       Spielstand (Datei von SaveGames) laden statt neuer Partie (für Screenshots)
##   --setup=name          Spielwelt aus tests/setups/name.gd statt neuer Partie (für Testzustände)
##   --preset=id           Startparameter des Testzustands aus tools/presets.json (eigene gehen vor)
##   --select              alle Soldaten ausgewählt (für Screenshots)
##   --box=x,y             Auswahlrahmen von dieser Kachel bis zur Kachel unter der Maus (für Screenshots)
##   --line=x,y            im Baumodus einer Mauer: Linie von dieser Kachel bis zur Kachel unter der Maus (für Screenshots)
##   --focus=x,y           Kamera auf diese Kachel richten statt auf die Kartenmitte (für Screenshots)
##   --game_menu           Spielmenü geöffnet (für Screenshots)
##   --save_view           Speichern-Ansicht geöffnet (für Screenshots)
##   --save_as=Name        Speichern-Ansicht mit diesem Namen abgeschickt, bei belegtem Namen mit Rückfrage (für Screenshots)
##   --load_view           Ladeansicht geöffnet (für Screenshots)
##   --settings            Einstellungen aus dem Spielmenü geöffnet (für Screenshots)
##   --leave               „Zum Hauptmenü“ gewählt: Rückfrage bei ungespeichertem Fortschritt (für Screenshots)
##   --spawn               nach der Gründung einen Räuber am Rand erscheinen lassen (wie F8 nur im Debug-Build, für Screenshots)
##   --saves=demo          Spielstände in einem Wegwerf-Ordner mit Beispielen statt user://saves/ (empty: leer)
##   --screenshot=pfad.png Bild speichern und beenden (für Tests/Entwicklung)
##
## F5 überschreibt den Schnellspielstand (user://saves/), F9 lädt ihn; in der Gründung und nach der
## Niederlage ist Speichern gesperrt.
## Eine neue Partie beginnt mit der Gründung: Vorschau von Bergfried, erstem Warenlager,
## erstem Kornspeicher und Lagerfeuer unter der Maus, Linksklick schickt den Gründungsbefehl.
## Danach wählt die Bauleiste (oder L/G/H/B/J/O/P) ein Gebäude: Vorschau unter der Maus,
## Linksklick baut und bleibt im Baumodus, Rechtsklick oder Esc beendet ihn. Mauern (Q) zieht
## man mit der linken Taste als Linie (grün/rot je Kachel), Loslassen schickt den Befehl Mauerlinie.
## Das Abriss-Werkzeug (Bauleiste oder X) hebt das Gebäude unter der Maus hervor, rot mit
## Grund, wenn es nicht abreißbar ist; Linksklick reißt ohne Rückfrage ab.
## V öffnet und schließt die Verwaltung (Esc schließt sie auch); darin stellen ◀ ▶ bzw. −/+
## die Ration und ◀ ▶ bzw. ,/. den Steuersatz per Befehl ein.
## M öffnet und schließt die Marktansicht mit dem Bestand aller Waren (Esc schließt sie auch).
## Ein Linksklick auf eine Kaserne (ohne Werkzeug) öffnet die Kasernenansicht (Esc schließt sie);
## ihre Knöpfe schicken den Befehl Anwerben.
## Ohne Werkzeug wählt ein Linksklick einen Soldaten (Ring), Linksziehen alle im Rahmen; ein
## Rechtsklick ohne Ziehen schickt die Auswahl per Befehl Angreifen auf den Feind unter der Maus,
## sonst per Befehl Bewegen dorthin – auf den Wehrgang, wenn unter der Maus Mauer, Tor oder Turm liegt –;
## Rechtsziehen verschiebt die Kamera. Esc hebt zuerst die Auswahl auf. F8 lässt im Debug-Build
## einen Räuber am Rand nächst dem Bergfried erscheinen, F7 die nächste Welle des Wellenplans.
## Läuft eine Ankündigung, zeigen HUD (Countdown) und Randmarkierung Seite und Erscheinungskachel.
## Ist nichts mehr davon offen (Auswahl, Ansichten, Werkzeug), öffnet Esc das Spielmenü: Die Zeit
## steht, Klicks und Tasten wirken nicht auf die Partie, Esc oder „Fortsetzen“ schließt es wieder.
## „Speichern“ öffnet die Speichern-Ansicht (Name vorbelegt, Rückfrage vor dem Überschreiben),
## „Laden“ die Ladeansicht (auch aus der Niederlage-Ansicht); Esc oder „Zurück“ führt ins Spielmenü.
## „Einstellungen“ öffnet darüber die Einstellungen; Esc oder „Zurück“ führt ins Spielmenü zurück.
## F wechselt zwischen Vollbild und Fenster, und zwar über dieselbe Einstellung (Settings).
## Fällt der Bergfried, zeigt die Niederlage-Ansicht den erreichten Tag, die abgewehrten Wellen und den Seed;
## „Neue Partie“ öffnet die Szenarioauswahl mit demselben Szenario, „Zum Hauptmenü“ wechselt ins
## Hauptmenü, „Beenden“ schließt das Spiel. N (sofort eine neue Karte) wirkt nur im Debug-Build.


## Die Startparameter sind gelesen; das Hauptmenü wertet sie danach nicht mehr aus.
static var args_used := false

## Woraus die Partie startet; das Hauptmenü setzt sie vor dem Betreten des Baums, sonst gelten
## die Startparameter.
var start: MatchStart
## Die Spielwelt der Partie (_match.world), hier kurz für Darstellung und Eingabe.
var world: GameWorld

var _match := Match.new()
var _game_menu := GameMenu.new()
## „Speichern“ im Spielmenü; gesperrt, solange die Partie nicht speicherbar ist.
var _save_entry: Button
var _settings_view := SettingsView.new(Settings.shared(), true)
## Rückfrage, bevor die Partie mit ungespeichertem Fortschritt verlassen wird.
var _leave_dialog := ConfirmDialog.new()

var _deposit_views: Dictionary[Vector2i, DepositView] = {}
var _building_views: Dictionary[int, BuildingView] = {}
var _resident_views: Dictionary[int, ResidentView] = {}
var _enemy_views: Dictionary[int, EnemyView] = {}
var _hovered := Vector2i(-1, -1)
## Gewählter Gebäudetyp im Baumodus, leer = kein Baumodus.
var _build_type := ""
## Abriss-Werkzeug gewählt (schließt den Baumodus aus).
var _demolishing := false
## ID der Kaserne, deren Ansicht offen ist (0 = keine).
var _barracks_id := 0
## IDs der ausgewählten Soldaten.
var _selected: Array[int] = []
## Linke Taste ohne Werkzeug gedrückt: Klick oder Rahmen wählen Soldaten aus.
var _selecting := false
## Linke Taste im Baumodus einer Mauer gedrückt: Die Linie beginnt bei _line_start.
var _drawing_line := false
var _line_start := Vector2i.ZERO
## Wo die linke bzw. rechte Taste gedrückt wurde (Bildschirm); links auch in der Welt.
var _left_press := Vector2.ZERO
var _left_press_world := Vector2.ZERO
var _right_press := Vector2.ZERO
## Die rechte Taste wurde über der Karte gedrückt (nicht über dem HUD).
var _right_pressed_on_map := false

@onready var _clock: GameClock = $Clock
@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _wave_marker: WaveMarker = $WaveMarker
@onready var _highlight: TileHighlight = $Highlight
@onready var _preview: PlacementPreview = $Preview
@onready var _camera: CameraController = $Camera
@onready var _selection_box: SelectionBox = $SelectionBox
@onready var _hud: Hud = $HUD


func _ready() -> void:
	# Ohne Startbeschreibung (aus dem Hauptmenü) gelten die Startparameter.
	var args := Presets.user_args() if start == null else {}
	if start == null:
		start = MatchStart.from_args(args)
		args_used = true
	_clock.speed_changed.connect(_hud.show_speed)
	_hud.show_speed(_clock.get_speed(), _clock.is_paused())
	_hud.build_selected.connect(_select_build)
	_hud.demolish_selected.connect(_select_demolish)
	_hud.ration_step.connect(_step_ration)
	_hud.tax_rate_step.connect(_step_tax_rate)
	_hud.trade_requested.connect(_trade)
	_hud.recruit_requested.connect(_recruit)
	_hud.new_game_requested.connect(_leave_match.bind("Neue Partie beginnen?",
			func() -> void: MainMenu.show_in(get_tree(), _match.scenario.id)))
	_hud.load_requested.connect(_open_load_view)
	_hud.main_menu_requested.connect(_leave_to_main_menu)
	_hud.quit_requested.connect(_quit)
	# ⌘Q und das Schließen des Fensters kommen als NOTIFICATION_WM_CLOSE_REQUEST an.
	get_tree().set_auto_accept_quit(false)
	_match.saves = Presets.save_games()
	_match.world_changed.connect(_show_world)
	_build_game_menu()
	Settings.shared().follow_window(get_window())
	Settings.shared().changed.connect(_apply_camera_speed)
	_apply_camera_speed()
	var error := _start(start)
	if error != "" and start.kind != MatchStart.Kind.SCENARIO:
		printerr("--load: " if start.kind == MatchStart.Kind.SAVE else "--setup: ", error)
		error = _start(MatchStart.from_scenario(Scenario.DEFAULT))
	if error != "":
		printerr("Fehler: ", error)
		set_process(false)
		set_process_unhandled_key_input(false)
		get_tree().quit(1)
		return
	var days := int(args.get("days", 0))
	if args.has("found") or days > 0:
		_match.execute(Command.found(world.find_founding_site()))
	for i in days * GameWorld.TICKS_PER_DAY:
		world.step()
	if args.has("place"):
		var place := str(args["place"]).split("@")
		var xy := place[1].split(",") if place.size() == 2 else PackedStringArray()
		var reason := "Format: --place=typ@x,y"
		if xy.size() == 2:
			reason = _match.execute(Command.build(place[0], Vector2i(int(xy[0]), int(xy[1]))))
		if reason != "":
			printerr("--place: ", reason)
	if args.has("spawn") and OS.is_debug_build():
		var spawn_reason := _match.execute(Command.spawn_enemy(FighterType.enemy_ids()[0]))
		if spawn_reason != "":
			printerr("--spawn: ", spawn_reason)
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
	if args.has("game_menu") or args.has("settings"):
		_open_game_menu()
	if args.has("save_view") or args.has("save_as"):
		_open_save_view()
		var save_view := _game_menu.get_view() as SaveView
		if save_view == null:
			printerr("--save_view: ", _match.save_error())
		elif args.has("save_as"):
			save_view.set_name_text(str(args["save_as"]))
			save_view.submit()
	if args.has("load_view"):
		_open_load_view()
	if args.has("settings"):
		_open_settings()
	if args.has("leave"):
		_open_game_menu()
		_leave_to_main_menu()
		if not _leave_dialog.is_open():
			printerr("--leave: kein ungespeicherter Fortschritt")
	# Die folgenden Parameter melden es, wenn sie nichts bewirken (der Rauchtest scheitert daran).
	if args.has("barracks"):
		for building in world.get_buildings():
			if building.is_barracks():
				_open_barracks(building.id)
				break
		if not _hud.is_barracks_open():
			printerr("--barracks: keine Kaserne")
	if args.has("select"):
		_set_selection(_soldier_views())
		if _selected.is_empty():
			printerr("--select: keine Soldaten")
	if args.has("focus"):
		var focus := str(args["focus"]).split(",")
		if focus.size() == 2:
			_camera.focus_on(Iso.tile_to_world(Vector2i(int(focus[0]), int(focus[1]))))
		else:
			printerr("--focus: Format: --focus=x,y")
	# Unabhängig vom echten Mauszeiger: Maus gilt als über der Kartenmitte oder --hover.
	var hover_tile := world.map.center()
	var hover := str(args.get("hover", "")).split(",")
	if hover.size() == 2:
		hover_tile = Vector2i(int(hover[0]), int(hover[1]))
	if args.has("box"):
		var box := str(args["box"]).split(",")
		if box.size() == 2:
			_selection_box.show_box(Iso.tile_to_world(Vector2i(int(box[0]), int(box[1]))), Iso.tile_to_world(hover_tile))
		else:
			printerr("--box: Format: --box=x,y")
	if args.has("line"):
		var line := str(args["line"]).split(",")
		if line.size() == 2 and line[0].is_valid_int() and line[1].is_valid_int() \
				and GameWorld.is_line_type(_build_type) and not world.is_founding():
			_drawing_line = true
			_line_start = Vector2i(int(line[0]), int(line[1]))
		else:
			printerr("--line: braucht --build mit einem Linientyp, eine gegründete Burg und --line=x,y")
	if args.has("screenshot") or args.has("line"):
		# Nur automatisierte Ansichten halten die vorgegebene Mausposition fest. Im sichtbaren
		# Testzustand muss die Vorschau danach weiter dem echten Mauszeiger folgen.
		if args.has("screenshot") or DisplayServer.get_name() == "headless":
			set_process(false)
		_hovered = hover_tile
		_update_hover()
		_update_preview()
	if args.has("screenshot"):
		Presets.save_screenshot_and_quit(self, str(args["screenshot"]))


func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


## „Zum Hauptmenü“ aus Spielmenü und Niederlage-Ansicht, mit Rückfrage bei ungespeichertem Fortschritt.
func _leave_to_main_menu() -> void:
	_leave_match("Zum Hauptmenü?", MainMenu.show_in.bind(get_tree()))


## „Beenden“ aus Spielmenü und Niederlage-Ansicht, ebenso ⌘Q und das Schließen des Fensters.
func _quit() -> void:
	_leave_match("Burgwacht beenden?", get_tree().quit)


## Verlässt die Partie, indem leave aufgerufen wird (Hauptmenü, Laden, Beenden …); gibt es
## ungespeicherten Fortschritt, erst nach der Rückfrage („Verwerfen“ oder „Abbrechen“). Dafür
## öffnet sie das Spielmenü, damit die Zeit steht.
func _leave_match(question: String, leave: Callable) -> void:
	if not _match.has_unsaved_progress():
		leave.call()
		return
	if not _game_menu.is_open() and not _settings_view.is_open():
		_open_game_menu()
	_leave_dialog.ask(question + " Der Fortschritt seit dem letzten Speichern geht verloren.", "Verwerfen", leave)


func _process(_delta: float) -> void:
	_update_announcement()
	var tile := Iso.world_to_tile(get_global_mouse_position())
	if tile != _hovered:
		_hovered = tile
		_update_hover()
		_update_preview()


## Eine begonnene Auswahl folgt der Maus und endet beim Loslassen – auch über dem HUD, das
## diese Ereignisse sonst abfängt. Ebenso endet eine Mauerlinie beim Loslassen.
func _input(event: InputEvent) -> void:
	var release := event as InputEventMouseButton
	if _drawing_line and release != null and release.button_index == MOUSE_BUTTON_LEFT and not release.pressed:
		_drawing_line = false
		_execute_or_show(Command.build_line(_build_type, _line_start, _hovered))
		_update_preview()
	if not _selecting:
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _is_drag(_left_press, motion.position):
		_selection_box.show_box(_left_press_world, get_global_mouse_position())
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish_selection(button.position)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	# Nicht als behandelt markieren: Die Kamera zieht weiterhin mit der rechten Taste.
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			_right_press = button.position
			_right_pressed_on_map = true
		elif _right_pressed_on_map:
			_right_pressed_on_map = false
			if not _is_drag(_right_press, button.position):
				_right_click()
	elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_left_click()


## Ist die Maus zwischen Drücken und Loslassen so weit gewandert, dass es ein Ziehen ist?
static func _is_drag(from: Vector2, to: Vector2) -> bool:
	return from.distance_to(to) > CameraController.CLICK_DISTANCE


## Rechtsklick ohne Ziehen: beendet den Bau- bzw. Abrissmodus, sonst lässt er die Auswahl den
## Feind unter der Maus angreifen bzw. schickt sie an die Kachel unter der Maus.
func _right_click() -> void:
	if _build_type != "" or _demolishing:
		_select_build("")
	elif not _selected.is_empty():
		var enemy := _enemy_at(get_global_mouse_position())
		if enemy != 0:
			_execute_or_show(Command.attack(_selected, enemy))
		else:
			_execute_or_show(Command.move(_selected, _target_under_mouse()))


## Der Feind, dessen Figur den Punkt (Welt) trifft – bei mehreren der vorderste; 0, wenn keiner.
func _enemy_at(point: Vector2) -> int:
	var front := 0
	for id: int in _enemy_views:
		var view := _enemy_views[id]
		if view.hit_rect().has_point(point) and (front == 0 or view.position.y > _enemy_views[front].position.y):
			front = id
	return front


## Das Ziel für Bewegen unter der Maus: eine Wehrgang-Kachel, wenn die Maus auf Mauer, Tor oder
## Turm liegt (ihr Dach ist um die Mauerhöhe angehoben), sonst die Kachel am Boden.
func _target_under_mouse() -> Vector3i:
	var raised := Iso.world_to_tile(get_global_mouse_position() + Vector2(0, FigureView.wall_walk_height()))
	for tile: Vector2i in [raised, _hovered]:
		if world.is_walkable(tile, Figure.Level.WALL_WALK):
			return Vector3i(tile.x, tile.y, Figure.Level.WALL_WALK)
	return Figure.ground(_hovered)


## Linke Taste gedrückt: gründet, baut oder reißt ab; ohne Werkzeug beginnt die Auswahl
## (entschieden wird beim Loslassen).
func _left_click() -> void:
	var reason := ""
	if world.is_founding():
		reason = _match.execute(Command.found(_origin_under_mouse(GameWorld.FOUNDING_TYPE)))
	elif GameWorld.is_line_type(_build_type):
		_drawing_line = true
		_line_start = _hovered
		_update_preview()
	elif _build_type != "":
		reason = _match.execute(Command.build(_build_type, _origin_under_mouse(_build_type)))
	elif _demolishing:
		var building := world.get_building_at(_hovered)
		if building != null:
			reason = _match.execute(Command.demolish(building.id))
	else:
		_selecting = true
		_left_press = get_viewport().get_mouse_position()
		_left_press_world = get_global_mouse_position()
	if reason != "":
		_hud.show_message(reason)


## Linke Taste losgelassen: Gezogen wählt alle Soldaten im Rahmen. Ein Klick wählt den
## Soldaten unter der Maus (_soldier_at()); steht dort keiner, hebt er die Auswahl auf und
## öffnet auf einer Kaserne deren Ansicht.
func _finish_selection(release: Vector2) -> void:
	_selecting = false
	_selection_box.visible = false
	var picked: Array[int] = []
	if _is_drag(_left_press, release):
		var box := Rect2(_left_press_world, get_global_mouse_position() - _left_press_world).abs()
		for id: int in _soldier_views():
			if _resident_views[id].hit_rect().intersects(box, true):
				picked.append(id)
	else:
		var building := world.get_building_at(_hovered)
		var front := _soldier_at(get_global_mouse_position(), null if building == null else _building_views[building.id])
		if front != 0:
			picked.append(front)
		elif building != null and building.is_barracks():
			_open_barracks(building.id)
	_set_selection(picked)


## Die IDs aller Soldaten mit Figur, nach ID aufsteigend.
func _soldier_views() -> Array[int]:
	var result: Array[int] = []
	for resident in world.get_residents():
		if resident.is_soldier() and _resident_views.has(resident.id):
			result.append(resident.id)
	return result


## Der Soldat, dessen Figur den Punkt (Welt) trifft – bei mehreren der vorderste; 0, wenn keiner.
## Über einem Gebäude (building) zählt nur, wer auf der Kachel unter der Maus steht oder von
## ihm verdeckt wird (seine Silhouette liegt darüber): Figuren davor ragen sonst in die
## Kaserne hinein.
func _soldier_at(point: Vector2, building: BuildingView) -> int:
	var front := 0
	for id in _soldier_views():
		var view := _resident_views[id]
		if building != null and world.get_resident(id).tile != _hovered \
				and not building.covers_figure(view.hit_rect(), view.position.y):
			continue
		if view.hit_rect().has_point(point) and (front == 0 or view.position.y > _resident_views[front].position.y):
			front = id
	return front


## Wählt genau diese Soldaten aus (Ring) und zeigt den Hinweis dazu.
func _set_selection(ids: Array[int]) -> void:
	for id in _selected:
		if _resident_views.has(id):
			_resident_views[id].selected = false
	_selected.clear()
	for id in ids:
		if _resident_views.has(id):
			_selected.append(id)
			_resident_views[id].selected = true
	_update_preview()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# Bei offenem Spielmenü wirkt nur Esc (schließt es); aus den Einstellungen geht es zurück ins Spielmenü.
	if _settings_view.is_open():
		if key.keycode == KEY_ESCAPE:
			_settings_view.close()
		return
	if _game_menu.is_open():
		if key.keycode == KEY_ESCAPE:
			_close_game_menu()
		return
	match key.keycode:
		KEY_N:
			# Neue Karte im selben Szenario, immer mit neuem Zufallsseed (nur zum Entwickeln).
			if OS.is_debug_build():
				_start(MatchStart.from_scenario_with_seed(_match.scenario.id, randi()))
		KEY_SPACE:
			_clock.toggle_pause()
		KEY_1, KEY_2, KEY_3:
			_clock.set_speed(GameClock.SPEEDS[key.keycode - KEY_1])
		KEY_F5:
			_quick_save()
		KEY_F9:
			_quick_load()
		KEY_F8:
			if OS.is_debug_build():
				_execute_or_show(Command.spawn_enemy(FighterType.enemy_ids()[0]))
		KEY_F7:
			if OS.is_debug_build():
				_execute_or_show(Command.spawn_wave())
		KEY_ESCAPE:
			# Zuerst die Auswahl; ist die Verwaltung, die Marktansicht oder die Kasernenansicht
			# offen, schließt Esc nur sie, dann das Werkzeug. Erst danach öffnet es das Spielmenü
			# (nicht nach der Niederlage, da gilt die Niederlage-Ansicht).
			if not _selected.is_empty():
				_set_selection([])
			elif _hud.is_administration_open():
				_hud.close_administration()
			elif _hud.is_market_open():
				_hud.close_market()
			elif _hud.is_barracks_open():
				_hud.close_barracks()
			elif _build_type != "" or _demolishing:
				_select_build("")
			elif not world.is_defeated():
				_open_game_menu()
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
			Settings.shared().set_fullscreen(not Settings.shared().is_fullscreen())
		_:
			for type_id in GameWorld.buildable_types():
				if OS.find_keycode_from_string(str(GameDefs.get_instance().buildings[type_id]["hotkey"])) == key.keycode:
					_select_build(type_id)


## Startet die Partie aus der Beschreibung; Fehler als Meldung und als Rückgabe ("" = gestartet).
func _start(description: MatchStart) -> String:
	var error := _match.start(description)
	if error != "":
		_hud.show_message(error)
	elif description.kind == MatchStart.Kind.SAVE:
		_hud.show_message("Geladen (Tag %d)" % world.get_day())
	return error


## Verbindet die neue Spielwelt der Partie mit Takt, Darstellung und HUD; alte Darstellung fliegt raus.
func _show_world() -> void:
	world = _match.world
	world.deposit_added.connect(_on_deposit_added)
	world.deposit_removed.connect(_on_deposit_removed)
	world.deposit_changed.connect(_on_deposit_changed)
	world.day_started.connect(_hud.show_day)
	world.building_added.connect(_on_building_added)
	world.building_removed.connect(_on_building_removed)
	world.building_changed.connect(_on_building_changed)
	world.stock_changed.connect(_on_stock_changed)
	world.resident_added.connect(_on_resident_added)
	world.resident_removed.connect(_on_resident_removed)
	world.resident_changed.connect(_on_resident_changed)
	world.enemy_added.connect(_on_enemy_added)
	world.enemy_removed.connect(_on_enemy_removed)
	world.enemy_changed.connect(_on_enemy_changed)
	world.shot_fired.connect(_on_shot_fired)
	world.founded.connect(_on_founded)
	world.popularity_changed.connect(_update_popularity)
	world.factors_changed.connect(_update_popularity)
	world.settings_changed.connect(_update_popularity)
	world.treasury_changed.connect(_update_treasury)
	world.notice.connect(_hud.show_message)
	world.defeated.connect(_on_defeated)
	world.announcement_changed.connect(_update_wave_marker)
	_clock.world = world
	_close_game_menu()
	_build_type = ""
	_demolishing = false
	_hud.show_tool("", false)
	_barracks_id = 0
	_hud.close_barracks()
	_selected.clear()
	_selecting = false
	_drawing_line = false
	_selection_box.visible = false
	_hud.set_build_bar_enabled(not world.is_founding())
	var map := world.map
	_terrain.show_map(map)

	for view: DepositView in _deposit_views.values():
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
	for view: EnemyView in _enemy_views.values():
		view.queue_free()
	_enemy_views.clear()
	for enemy in world.get_enemies():
		_add_enemy_view(enemy.id)

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
	_update_wave_marker()
	_update_announcement()
	if world.is_defeated():
		_on_defeated()
	else:
		_hud.hide_defeat()


## Der Bergfried ist gefallen: Werkzeuge und Ansichten schließen, Niederlage-Ansicht zeigen.
func _on_defeated() -> void:
	_select_build("")
	_set_selection([])
	_selecting = false
	_drawing_line = false
	_selection_box.visible = false
	_barracks_id = 0
	_hud.close_barracks()
	_hud.close_administration()
	_hud.close_market()
	_hud.set_build_bar_enabled(false)
	_hud.show_defeat(world.get_day(), world.get_repelled_waves(), world.get_seed())


## Einträge des Spielmenüs.
func _build_game_menu() -> void:
	add_child(_game_menu)
	_game_menu.add_entry("Fortsetzen", _close_game_menu)
	_save_entry = _game_menu.add_entry("Speichern", _open_save_view)
	_game_menu.add_entry("Laden", _open_load_view)
	_game_menu.add_entry("Einstellungen", _open_settings)
	add_child(_settings_view)
	_settings_view.closed.connect(_show_game_menu)
	_game_menu.add_entry("Zum Hauptmenü", _leave_to_main_menu)
	_game_menu.add_entry("Beenden", _quit)
	add_child(_leave_dialog)


## Öffnet das Spielmenü: Zeit anhalten, laufende Auswahl oder Mauerlinie verwerfen, Kamera ruhen lassen.
func _open_game_menu() -> void:
	_selecting = false
	_drawing_line = false
	_selection_box.visible = false
	_update_preview()
	_clock.hold()
	_set_camera_active(false)
	_save_entry.disabled = _match.save_error() != ""
	_save_entry.tooltip_text = _match.save_error()
	_show_game_menu()


## Die Speichern-Ansicht an Stelle des Spielmenüs (nicht in der Gründung, nicht nach der Niederlage).
func _open_save_view() -> void:
	if _match.save_error() != "":
		_hud.show_message(_match.save_error())
		return
	if not _game_menu.is_open():
		_open_game_menu()
	var view := SaveView.new(_match.saves, _match.suggested_save_name())
	view.save_requested.connect(_save_named.bind(view))
	view.back_requested.connect(_close_menu_view)
	_game_menu.show_view(view)


## Speichert unter dem Namen aus der Speichern-Ansicht; danach geht die Partie weiter.
func _save_named(save_name: String, view: SaveView) -> void:
	var error := _match.save(SaveGame.Kind.NAMED, save_name)
	if error != "":
		view.show_error(error)
		return
	_close_game_menu()
	_hud.show_message("Gespeichert: „%s“" % save_name)


## Die Ladeansicht an Stelle des Spielmenüs; aus der Niederlage-Ansicht öffnet sie es dafür.
func _open_load_view() -> void:
	if not _game_menu.is_open():
		_open_game_menu()
	_hud.hide_defeat()
	var view := LoadView.new(_match.saves)
	view.load_requested.connect(_load_chosen.bind(view))
	view.back_requested.connect(_close_menu_view)
	_game_menu.show_view(view)


## Lädt den gewählten Spielstand; scheitert es, steht der Grund in der Ladeansicht.
func _load_chosen(path: String, view: LoadView) -> void:
	_leave_match("Spielstand laden?", func() -> void:
		var error := _load_from(path)
		if error != "":
			view.show_error(error))


## Zurück aus Speichern- oder Ladeansicht ins Spielmenü; nach der Niederlage zur Niederlage-Ansicht.
func _close_menu_view() -> void:
	if world.is_defeated():
		_close_game_menu()
		_on_defeated()
	else:
		_game_menu.close_view()


func _show_game_menu() -> void:
	_game_menu.open(_match.scenario.title, world.get_seed())


## Die Einstellungen ersetzen das Spielmenü, bis „Zurück“ es wieder zeigt; die Zeit steht weiter.
func _open_settings() -> void:
	_game_menu.close()
	_settings_view.open()


## Übernimmt die Kamerageschwindigkeit: beim Start und nach jeder Änderung (das Fenster stellt
## Settings.follow_window() selbst ein).
func _apply_camera_speed() -> void:
	_camera.speed_factor = Settings.shared().get_camera_speed()


## Schließt das Spielmenü; die Zeit läuft mit der vorigen Geschwindigkeit weiter.
func _close_game_menu() -> void:
	_game_menu.close()
	_clock.release()
	_set_camera_active(true)


func _set_camera_active(active: bool) -> void:
	_camera.set_process(active)
	_camera.set_process_unhandled_input(active)


func _quick_save() -> void:
	var error := _match.save(SaveGame.Kind.QUICK)
	_hud.show_message(error if error != "" else "Gespeichert (Tag %d)" % world.get_day())


func _quick_load() -> void:
	if not _match.saves.has(SaveGame.Kind.QUICK):
		_hud.show_message("Noch kein Schnellspielstand – erst mit F5 speichern")
		return
	_leave_match("Schnellspielstand laden?", _load_from.bind(_match.saves.path_for(SaveGame.Kind.QUICK)))


## Lädt den Spielstand aus dieser Datei; Fehler als Meldung und als Rückgabe ("" = geladen).
func _load_from(path: String) -> String:
	return _start(MatchStart.from_save(path))


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


## Ankündigung samt Countdown in der Titelleiste (in jedem Bild, da der Countdown mit der Zeit läuft).
func _update_announcement() -> void:
	_hud.show_announcement(world.get_announced_side(), world.get_announced_ticks())


## Die Randmarkierung auf die Erscheinungskachel der angekündigten Welle; Gebäude am Rand können
## die Kachel verschieben.
func _update_wave_marker() -> void:
	var tile := world.get_announced_tile()
	if tile.is_empty():
		_wave_marker.visible = false
	else:
		_wave_marker.show_at(tile[0], world.get_announced_side())


func _on_building_added(id: int) -> void:
	_add_building_view(id)
	_update_wave_marker()
	_update_residents()
	_update_stock()
	_update_hover()
	_update_preview()


func _on_building_changed(id: int) -> void:
	if _building_views.has(id):
		_building_views[id].update_health()
	if world.get_building_at(_hovered) == world.get_building(id):
		_update_hover()


func _on_building_removed(id: int) -> void:
	_update_wave_marker()
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
	view.occluders = _building_views
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
	if _selected.has(id):
		_selected.erase(id)
		_update_preview()
	_update_residents()
	_update_hover()


func _on_resident_changed(_id: int) -> void:
	_update_residents()
	_update_hover()


func _add_enemy_view(id: int) -> void:
	var view := EnemyView.new()
	view.occluders = _building_views
	view.setup(world.get_enemy(id), _clock)
	_objects.add_child(view)
	_enemy_views[id] = view


func _on_enemy_added(id: int) -> void:
	_add_enemy_view(id)
	_update_hover()


func _on_enemy_removed(id: int) -> void:
	if _enemy_views.has(id):
		_enemy_views[id].queue_free()
		_enemy_views.erase(id)
	_update_hover()


func _on_enemy_changed(_id: int) -> void:
	_update_hover()


## Ein Pfeil fliegt sichtbar vom Schützen zum Ziel (über den Figuren).
func _on_shot_fired(from: Vector3i, to: Vector3i) -> void:
	var arrow := ArrowView.new()
	arrow.z_index = 1
	arrow.setup(from, to)
	add_child(arrow)


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
	# Mit einem Werkzeug ist keine Auswahl sichtbar; Esc soll dann gleich das Werkzeug beenden.
	if build_type != "" or demolishing:
		_set_selection([])
	_build_type = build_type
	_demolishing = demolishing
	_drawing_line = false
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
		var hint := ""
		if not _selected.is_empty():
			hint = "%s ausgewählt  ·  Rechtsklick: dorthin bewegen bzw. Feind angreifen  ·  Esc: Auswahl aufheben" \
					% ("1 Soldat" if _selected.size() == 1 else "%d Soldaten" % _selected.size())
		_hud.show_build_hint(hint, true)
		return
	if GameWorld.is_line_type(_build_type):
		_update_line_preview()
		return
	var origin := _origin_under_mouse(_build_type)
	var reason := world.build_error(_build_type, origin)
	_preview.show_parts([[_build_type, origin]] as Array[Array], reason == "")
	var building_name: String = GameDefs.get_instance().buildings[_build_type]["name"]
	if reason == "":
		_hud.show_build_hint("%s setzen (Linksklick)  ·  Rechtsklick/Esc: beenden" % building_name, true)
	else:
		_hud.show_build_hint("%s: %s" % [building_name, reason], false)


## Mauer: die Linie vom Start bis zur Maus (vor dem Drücken nur die Kachel unter der Maus),
## grün, was entsteht, rot, was nicht; der Hinweis nennt, wie viele Kacheln entstehen.
func _update_line_preview() -> void:
	var plan := world.line_plan(_build_type, _line_start if _drawing_line else _hovered, _hovered)
	_preview.show_line(_build_type, plan)
	var building_name: String = GameDefs.get_instance().buildings[_build_type]["name"]
	var reason := GameWorld.line_error(plan)
	if reason != "":
		_hud.show_build_hint("%s: %s" % [building_name, reason], false)
	elif _drawing_line:
		var built := plan.values().count("")
		_hud.show_build_hint("%s: %d von %d Kacheln (Loslassen baut)" % [building_name, built, plan.size()], true)
	else:
		_hud.show_build_hint("%s ziehen (Linksziehen)  ·  Rechtsklick/Esc: beenden" % building_name, true)


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
	for storage_type: String in Building.storage_types():
		_hud.show_storage(storage_type, world.get_storage_used(storage_type),
				world.get_storage_capacity(storage_type))
	var stock: Dictionary[String, int] = {}
	for good: String in GameDefs.get_instance().goods:
		stock[good] = world.get_stock(good)
	_hud.show_market_stock(stock)
	_update_market()
	_update_barracks()
	_update_build_costs()


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


## Kasernenansicht: Untätige, Waffen (die Waren der Anwerbekosten), Gold und je Soldatentyp
## der Grund, warum Anwerben gerade nicht geht.
func _update_barracks() -> void:
	if _barracks_id == 0:
		return
	var weapons: Dictionary[String, int] = {}
	var errors: Dictionary[String, String] = {}
	for good in SoldierType.weapons():
		weapons[good] = world.get_stock(good)
	for type_id in SoldierType.ids():
		errors[type_id] = world.recruit_error(_barracks_id, type_id)
	_hud.show_barracks(world.get_idle_count(), weapons, world.get_treasury(), errors)


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
	var reason := _match.execute(command)
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
	_update_build_costs()


## Bauleiste: je Gebäudetyp, ob Waren und Gold reichen.
func _update_build_costs() -> void:
	var errors: Dictionary[String, String] = {}
	for type_id in GameWorld.buildable_types():
		errors[type_id] = world.cost_error(type_id)
	_hud.show_build_costs(errors)


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
		if building.is_destructible():
			text += " (%d/%d LP)" % [building.hp, building.max_hp()]
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
		activities.append(world.activity_of(resident) + (_health_text(resident) if resident.is_soldier() else ""))
	if not activities.is_empty():
		text += "\nBewohner: %s" % ", ".join(activities)
	var enemies: PackedStringArray = []
	for enemy in world.get_enemies_at(_hovered):
		enemies.append(world.enemy_activity_of(enemy) + _health_text(enemy))
	if not enemies.is_empty():
		text += "\nFeinde: %s" % ", ".join(enemies)
	_hud.show_tile_info(text)


## Lebenspunkte eines Kämpfers für die Kachel-Info, z. B. „ (64/100 LP)“.
static func _health_text(figure: Figure) -> String:
	return " (%d/%d LP)" % [figure.hp, FighterType.max_hp(figure.fighter_type())]
