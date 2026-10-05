class_name MainMenu
extends Node2D
## Einstiegspunkt des Spiels (Hauptszene): das Hauptmenü. Im Hintergrund liegt eine zufällige
## Karte des Standardszenarios (nur Kartenerzeugung und Geländeansicht, keine Spielwelt), über
## die die Kamera langsam schwenkt. „Fortsetzen“ lädt den neuesten ladbaren Spielstand (ausgegraut
## ohne), „Neue Partie“ öffnet die Szenarioauswahl, „Laden“ die Ladeansicht; eine Partie startet in
## der Partie-Szene (main.tscn) aus der Startbeschreibung, die sie liefern.
##
## Wird mit Startparametern gestartet (siehe main.gd), geht es ohne Hauptmenü gleich in die
## Partie, die die Parameter selbst liest (nur einmal, siehe MatchScene.args_used). Ausnahmen:
##   --menu                Hauptmenü trotzdem zeigen (Preset main_menu)
##   --scenario_select     gleich mit offener Szenarioauswahl (Preset scenario_select)
##   --load_view           gleich mit offener Ladeansicht (mit --menu, Preset load_menu)
##   --saves=demo          Spielstände aus einem Wegwerf-Ordner (siehe Presets.save_games_for())
##   --screenshot=pfad.png Bild des Hauptmenüs speichern und beenden (nur mit den beiden oben)

const SCENE := "res://scenes/main_menu.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"
## Die Kamera fährt eine Ellipse um die Kartenmitte; Halbachsen als Anteil der Kartengröße (Welt).
const PAN_RADIUS_SHARE := 0.2
## Sekunden für eine Runde.
const PAN_SECONDS := 240.0
const CAMERA_ZOOM := 0.8

## Mit offener Szenarioauswahl und diesem Szenario vorgewählt beginnen; leer = Hauptmenü.
var scenario_choice := ""

var _menu: MenuPanel
var _scenario_select: ScenarioSelect
var _load_view: LoadView
var _pan_center := Vector2.ZERO
var _pan_radius := Vector2.ZERO
var _pan_time := 0.0

@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _camera: Camera2D = $Camera
@onready var _ui: CanvasLayer = $UI


## Wechselt aus einer Partie ins Hauptmenü, mit scenario_id gleich in die Szenarioauswahl
## (vorgewählt).
static func show_in(tree: SceneTree, scenario_id := "") -> void:
	var scene: PackedScene = load(SCENE)
	var menu: MainMenu = scene.instantiate()
	menu.scenario_choice = scenario_id
	tree.change_scene_to_node(menu)


func _ready() -> void:
	# Die Tonausgabe entsteht hier, bevor Knöpfe entstehen, und bleibt bis zum Ende bestehen.
	SoundOutput.shared()
	# Hat die Partie die Startparameter schon gelesen, führt „Zum Hauptmenü“ hierher zurück.
	var args := {} if MatchScene.args_used else Presets.user_args()
	if not args.is_empty() and not args.has("menu") and not args.has("scenario_select"):
		get_tree().change_scene_to_file.call_deferred(MATCH_SCENE)
		return
	Settings.shared().follow_window(get_window())
	if args.has("scenario_select"):
		scenario_choice = Scenario.DEFAULT
	_show_background_map()
	_build_menu()
	if scenario_choice != "":
		_open_scenario_select(scenario_choice)
	elif args.has("load_view"):
		_open_load_view()
	if args.has("screenshot"):
		Presets.save_screenshot_and_quit(self, str(args["screenshot"]))


func _process(delta: float) -> void:
	_pan_time += delta
	var angle := TAU * _pan_time / PAN_SECONDS
	_camera.position = _pan_center + Vector2(cos(angle), sin(angle)) * _pan_radius


## Eine zufällige Karte in der Größe des Standardszenarios samt Vorkommen.
func _show_background_map() -> void:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	var map := MapGenerator.generate(randi(), scenario.map_size.x, scenario.map_size.y)
	_terrain.show_map(map)
	for tile in map.deposits:
		var view := DepositView.new()
		view.setup(tile, map.deposits[tile])
		_objects.add_child(view)
	_pan_center = Iso.tile_to_world(map.center())
	_pan_radius = Iso.map_bounds(map.width, map.height).size * PAN_RADIUS_SHARE
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_process(0.0)


func _build_menu() -> void:
	_menu = MenuPanel.new("Burgwacht", "Baue deine Burg, verteidige sie gegen die Wellen")
	var continue_entry := _menu.add_entry("Fortsetzen", _continue)
	continue_entry.disabled = Presets.save_games().newest_loadable() == null
	_menu.add_entry("Neue Partie", _open_scenario_select.bind(Scenario.DEFAULT))
	_menu.add_entry("Laden", _open_load_view)
	_menu.add_entry("Einstellungen", _open_settings)
	_menu.add_entry("Beenden", get_tree().quit)
	_add_centered(_menu)


## Die Szenarioauswahl statt des Menüs, mit diesem Szenario vorgewählt.
func _open_scenario_select(scenario_id: String) -> void:
	_scenario_select = ScenarioSelect.new(scenario_id)
	_scenario_select.start_requested.connect(_start_match)
	_scenario_select.back_requested.connect(_close_scenario_select)
	_add_centered(_scenario_select)
	_menu.visible = false


func _close_scenario_select() -> void:
	_scenario_select.get_parent().queue_free()
	_scenario_select = null
	_menu.visible = true


## Lädt den neuesten ladbaren Spielstand; scheitert es, steht der Grund unter dem Titel.
func _continue() -> void:
	var newest := Presets.save_games().newest_loadable()
	if newest != null:
		var error := _load(newest.path)
		if error != "":
			_menu.set_subtitle(error)


## Die Ladeansicht statt des Menüs.
func _open_load_view() -> void:
	_load_view = LoadView.new(Presets.save_games())
	_load_view.load_requested.connect(func(path: String) -> void: _load_view.show_error(_load(path)))
	_load_view.back_requested.connect(_close_load_view)
	_add_centered(_load_view)
	_menu.visible = false


## Zurück ins Menü; „Fortsetzen“ richtet sich nach dem, was jetzt noch zu laden ist.
func _close_load_view() -> void:
	_load_view.get_parent().queue_free()
	_load_view = null
	_menu.get_parent().queue_free()
	_build_menu()


## Wechselt in die Partie aus diesem Spielstand; liefert den Grund, wenn er sich nicht laden lässt.
func _load(path: String) -> String:
	var save := SaveGames.read(path)
	if save.error == "":
		_start_match(MatchStart.from_save(path))
	return save.error


## Mittig über den ganzen Schirm; ein CenterContainer zentriert neu, sobald umbrochene Texte
## ihre Höhe kennen.
func _add_centered(panel: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	_ui.add_child(center)


## Die Einstellungen statt des Menüs, bis „Zurück“ es wieder zeigt.
func _open_settings() -> void:
	var view := SettingsView.new(Settings.shared(), false)
	add_child(view)
	view.closed.connect(func() -> void:
		view.queue_free()
		_menu.visible = true)
	_menu.visible = false
	view.open()


## Wechselt in die Partie-Szene, die aus dieser Startbeschreibung beginnt.
func _start_match(start: MatchStart) -> void:
	var scene: PackedScene = load(MATCH_SCENE)
	var game: MatchScene = scene.instantiate()
	game.start = start
	get_tree().change_scene_to_node(game)
