class_name Settings
extends RefCounted
## Die Einstellungen des Spiels: Vollbild/Fenster und Kamerageschwindigkeit. Getrennt von den
## Spielständen in einer JSON-Datei (im Spiel user://settings.cfg, in Tests ein vorgegebener Pfad).
## Jede Änderung wird sofort geschrieben und mit `changed` gemeldet; wer sie anwendet
## (Fenster, Kamera), hört darauf. Fehlt die Datei oder ist sie kaputt, gelten die Standardwerte;
## ein Wert mit falschem Typ ergibt seinen Standardwert.

signal changed

const PATH := "user://settings.cfg"
## Faktor auf CameraController.PAN_SPEED; 1 ist die Geschwindigkeit von vor den Einstellungen.
const DEFAULT_CAMERA_SPEED := 1.0
const MIN_CAMERA_SPEED := 0.5
const MAX_CAMERA_SPEED := 2.5
## Lautstärken in Prozent (0 = stumm, 100 = voll).
const MAX_VOLUME := 100
const DEFAULT_MASTER_VOLUME := 80
const DEFAULT_MUSIC_VOLUME := 60
const DEFAULT_SOUND_VOLUME := 80

## Die Einstellungen, die Hauptmenü und Partie gemeinsam anwenden und ändern (siehe shared()).
static var _shared: Settings

var _path: String
var _fullscreen := false
var _camera_speed := DEFAULT_CAMERA_SPEED
var _master_volume := DEFAULT_MASTER_VOLUME
var _music_volume := DEFAULT_MUSIC_VOLUME
var _sound_volume := DEFAULT_SOUND_VOLUME
## Das Fenster, das follow_window() nach jeder Änderung einstellt.
var _window: Window


## Liest die Einstellungen aus path; ein leerer Pfad hält sie nur im Speicher (nichts wird
## gelesen oder geschrieben).
func _init(path := PATH) -> void:
	_path = path
	if _path == "" or not FileAccess.file_exists(_path):
		return
	# JSON.parse() meldet Fehler nur über den Rückgabewert, ConfigFile druckt sie aus.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	var fullscreen: Variant = data.get("fullscreen", false)
	if fullscreen is bool:
		_fullscreen = fullscreen
	var speed: Variant = data.get("camera_speed", DEFAULT_CAMERA_SPEED)
	if speed is float or speed is int:
		_camera_speed = clampf(float(speed), MIN_CAMERA_SPEED, MAX_CAMERA_SPEED)
	_master_volume = _read_volume(data, "master_volume", DEFAULT_MASTER_VOLUME)
	_music_volume = _read_volume(data, "music_volume", DEFAULT_MUSIC_VOLUME)
	_sound_volume = _read_volume(data, "sound_volume", DEFAULT_SOUND_VOLUME)


## Die Lautstärke unter key, gerundet und begrenzt; fehlt sie oder ist sie keine Zahl, fallback.
static func _read_volume(data: Dictionary, key: String, fallback: int) -> int:
	var volume: Variant = data.get(key, fallback)
	if volume is float or volume is int:
		return clampi(roundi(float(volume)), 0, MAX_VOLUME)
	return fallback


## Die Einstellungen des laufenden Spiels, beim ersten Aufruf gelesen. Mit Startparametern
## (Presets, Rauchtest, Screenshots) nur im Speicher und mit Standardwerten, damit nichts in den
## Nutzerordner geschrieben wird und Bilder nicht von den eigenen Einstellungen abhängen.
static func shared() -> Settings:
	if _shared == null:
		_shared = Settings.new(PATH if Presets.user_args().is_empty() else "")
	return _shared


func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(on: bool) -> void:
	_fullscreen = on
	_store()


## Faktor auf die Geschwindigkeit, mit der Tastatur und Bildschirmrand die Kamera schieben.
func get_camera_speed() -> float:
	return _camera_speed


## Begrenzt auf MIN_CAMERA_SPEED bis MAX_CAMERA_SPEED.
func set_camera_speed(speed: float) -> void:
	_camera_speed = clampf(speed, MIN_CAMERA_SPEED, MAX_CAMERA_SPEED)
	_store()


## Gesamtlautstärke in Prozent; sie gilt zusätzlich zu Musik und Geräuschen.
func get_master_volume() -> int:
	return _master_volume


## Begrenzt auf 0 bis MAX_VOLUME, wie alle Lautstärken.
func set_master_volume(volume: int) -> void:
	_master_volume = clampi(volume, 0, MAX_VOLUME)
	_store()


func get_music_volume() -> int:
	return _music_volume


func set_music_volume(volume: int) -> void:
	_music_volume = clampi(volume, 0, MAX_VOLUME)
	_store()


func get_sound_volume() -> int:
	return _sound_volume


func set_sound_volume(volume: int) -> void:
	_sound_volume = clampi(volume, 0, MAX_VOLUME)
	_store()


## Stellt das Fenster auf Vollbild oder Fenster, wie eingestellt.
func apply_to_window(window: Window) -> void:
	var mode := Window.MODE_FULLSCREEN if _fullscreen else Window.MODE_WINDOWED
	if window.mode != mode:
		window.mode = mode


## Stellt das Fenster sofort und nach jeder Änderung ein (Hauptmenü und Partie beim Start); ein
## zweiter Aufruf ersetzt das Fenster, statt doppelt zu hören.
func follow_window(window: Window) -> void:
	if _window == null:
		changed.connect(_apply_to_followed_window)
	_window = window
	apply_to_window(window)


func _apply_to_followed_window() -> void:
	if is_instance_valid(_window):
		apply_to_window(_window)


func _store() -> void:
	if _path != "":
		var file := FileAccess.open(_path, FileAccess.WRITE)
		if file == null:
			push_warning("Einstellungen nicht gespeichert: %s" % error_string(FileAccess.get_open_error()))
		else:
			file.store_string(JSON.stringify({
				"fullscreen": _fullscreen,
				"camera_speed": _camera_speed,
				"master_volume": _master_volume,
				"music_volume": _music_volume,
				"sound_volume": _sound_volume,
			}, "\t"))
			file.close()
	changed.emit()
