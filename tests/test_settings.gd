extends TestCase
## Einstellungen (Settings) mit einem vorgegebenen Pfad in einem Wegwerf-Ordner.

## Wird beim Freigeben samt Inhalt gelöscht.
var _temp: DirAccess


func _path() -> String:
	_temp = DirAccess.create_temp("burgwacht_settings", false)
	return _temp.get_current_dir().path_join("settings.cfg")


func test_missing_file_gives_defaults() -> void:
	var settings := Settings.new(_path())
	assert_false(settings.is_fullscreen(), "Vollbild:")
	assert_eq(settings.get_camera_speed(), 1.0, "Kamerageschwindigkeit:")


func test_changes_are_kept_after_reading_again() -> void:
	var path := _path()
	var settings := Settings.new(path)
	settings.set_fullscreen(true)
	settings.set_camera_speed(1.5)
	var again := Settings.new(path)
	assert_true(again.is_fullscreen(), "Vollbild:")
	assert_eq(again.get_camera_speed(), 1.5, "Kamerageschwindigkeit:")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_broken_file_gives_defaults() -> void:
	var path := _path()
	_write(path, "{\"fullscreen\": tr")
	var settings := Settings.new(path)
	assert_false(settings.is_fullscreen(), "Vollbild:")
	assert_eq(settings.get_camera_speed(), 1.0, "Kamerageschwindigkeit:")


func test_values_of_wrong_type_or_out_of_range_give_defaults_or_limits() -> void:
	var path := _path()
	_write(path, "{\"fullscreen\": \"ja\", \"camera_speed\": 99}")
	var settings := Settings.new(path)
	assert_false(settings.is_fullscreen(), "Vollbild bei falschem Typ:")
	assert_eq(settings.get_camera_speed(), Settings.MAX_CAMERA_SPEED, "Kamerageschwindigkeit begrenzt:")
