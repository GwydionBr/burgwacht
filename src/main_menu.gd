extends Node2D
## Einstiegspunkt des Spiels (Hauptszene): das Hauptmenü. Im Hintergrund liegt eine zufällige
## Karte des Standardszenarios (nur Kartenerzeugung und Geländeansicht, keine Spielwelt), über
## die die Kamera langsam schwenkt. Eine Partie startet in der Partie-Szene (main.tscn) aus
## einer Startbeschreibung.
##
## Wird mit Startparametern gestartet (siehe main.gd), geht es ohne Hauptmenü gleich in die
## Partie, die die Parameter selbst liest (nur einmal, siehe MatchScene.args_used). Ausnahmen:
##   --menu                Hauptmenü trotzdem zeigen (Preset main_menu)
##   --screenshot=pfad.png Bild des Hauptmenüs speichern und beenden (nur mit --menu)

const MATCH_SCENE := "res://scenes/main.tscn"
## Die Kamera fährt eine Ellipse um die Kartenmitte; Halbachsen als Anteil der Kartengröße (Welt).
const PAN_RADIUS_SHARE := 0.2
## Sekunden für eine Runde.
const PAN_SECONDS := 240.0
const CAMERA_ZOOM := 0.8

var _pan_center := Vector2.ZERO
var _pan_radius := Vector2.ZERO
var _pan_time := 0.0

@onready var _terrain: TerrainRenderer = $Terrain
@onready var _objects: Node2D = $Objects
@onready var _camera: Camera2D = $Camera
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	# Hat die Partie die Startparameter schon gelesen, führt „Zum Hauptmenü“ hierher zurück.
	var args := {} if MatchScene.args_used else Presets.user_args()
	if not args.is_empty() and not args.has("menu"):
		get_tree().change_scene_to_file.call_deferred(MATCH_SCENE)
		return
	Settings.shared().changed.connect(_apply_settings)
	_apply_settings()
	_show_background_map()
	_build_menu()
	if args.has("screenshot"):
		_save_screenshot_and_quit(str(args["screenshot"]))


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
	var menu := MenuPanel.new("Burgwacht", "Baue deine Burg, verteidige sie gegen die Wellen")
	menu.add_entry("Neue Partie", _new_match)
	menu.add_entry("Einstellungen", _open_settings.bind(menu))
	menu.add_entry("Beenden", get_tree().quit)
	_ui.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH


## Die Einstellungen ersetzen das Hauptmenü, bis „Zurück“ es wieder zeigt.
func _open_settings(menu: MenuPanel) -> void:
	var view := SettingsView.new(Settings.shared(), false)
	add_child(view)
	view.closed.connect(func() -> void:
		view.queue_free()
		menu.visible = true)
	menu.visible = false
	view.open()


## Wendet die Einstellungen an: beim Start und nach jeder Änderung.
func _apply_settings() -> void:
	Settings.shared().apply_to_window(get_window())


## Neue Partie im Standardszenario mit dessen Seed (im freien Spiel ein zufälliger), bis es
## die Szenarioauswahl gibt.
func _new_match() -> void:
	var scene: PackedScene = load(MATCH_SCENE)
	var game: MatchScene = scene.instantiate()
	game.start = MatchStart.from_scenario(Scenario.DEFAULT)
	get_tree().change_scene_to_node(game)


func _save_screenshot_and_quit(path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
