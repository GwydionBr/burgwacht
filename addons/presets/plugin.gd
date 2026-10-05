@tool
extends EditorPlugin
## Menü „Testzustand“ in der Werkzeugleiste des Editors: Ein Eintrag startet das Spiel in diesem
## Preset (tools/presets.json). Es bleibt gewählt, bis „Normal starten“ – auch F5 startet so lange
## darin. Das Spiel erfährt es über die Umgebungsvariable Presets.ENV (siehe Presets.user_args()).

const NORMAL_ID := 0
const LABEL := "Testzustand"

var _button: MenuButton
var _ids: Array[String] = []


func _enter_tree() -> void:
	_button = MenuButton.new()
	_button.flat = false
	_button.tooltip_text = "Spiel in einem Testzustand aus tools/presets.json starten"
	_button.about_to_popup.connect(_fill_menu)
	_button.get_popup().id_pressed.connect(_on_id_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_show_choice(OS.get_environment(Presets.ENV))


func _exit_tree() -> void:
	OS.unset_environment(Presets.ENV)
	remove_control_from_container(CONTAINER_TOOLBAR, _button)
	_button.queue_free()


## Liest die Datei bei jedem Öffnen neu, damit neue Presets ohne Neustart erscheinen.
func _fill_menu() -> void:
	var popup := _button.get_popup()
	popup.clear()
	_ids.clear()
	popup.add_item("Normal starten", NORMAL_ID)
	popup.add_separator()
	var error := Presets.error()
	if error != "":
		popup.add_item(error)
		popup.set_item_disabled(popup.item_count - 1, true)
		return
	var presets := Presets.load_all()
	for id in presets:
		_ids.append(id)
		popup.add_item(str(presets[id]["name"]), _ids.size())
		popup.set_item_tooltip(popup.item_count - 1, "%s: %s" % [id, " ".join(Presets.args_of(id))])


func _on_id_pressed(item_id: int) -> void:
	if item_id == NORMAL_ID:
		OS.unset_environment(Presets.ENV)
		_show_choice("")
		return
	var preset := _ids[item_id - 1]
	OS.set_environment(Presets.ENV, preset)
	_show_choice(preset)
	EditorInterface.play_main_scene()


func _show_choice(preset: String) -> void:
	var presets := Presets.load_all()
	_button.text = LABEL if not presets.has(preset) else "%s: %s" % [LABEL, presets[preset]["name"]]
