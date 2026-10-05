class_name SaveView
extends PanelContainer
## Die Speichern-Ansicht im Holz-Gold-Stil der Menüs: ein Namensfeld, vorbelegt mit dem Vorschlag
## der Partie („Freies Spiel – Tag 12“), dazu „Speichern“ (auch Enter) und „Zurück“ (auch Esc).
## Gibt es den Namen schon, fragt sie vor dem Überschreiben nach. Speichern muss der Aufrufer;
## scheitert es, zeigt show_error() den Grund.

## Unter diesem Namen speichern (ein gleichnamiger Spielstand darf überschrieben werden).
signal save_requested(save_name: String)
## „Zurück“ oder Esc.
signal back_requested()

const FIELD_SIZE := Vector2(460, 46)
## Längster Name; so bleibt der daraus abgeleitete Dateiname meist eindeutig.
const MAX_NAME_LENGTH := 60

var _saves: SaveGames
var _field: LineEdit
var _error_label: Label
var _confirm := ConfirmDialog.new()


## saves: um belegte Namen zu erkennen; suggested_name: die Vorbelegung des Namensfelds.
func _init(saves: SaveGames, suggested_name: String) -> void:
	_saves = saves
	add_theme_stylebox_override("panel", MenuPanel.frame_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(MenuPanel.make_label("Speichern", UiStyle.GOLD_COLOR, 36))
	var caption := MenuPanel.make_label("Name des Spielstands", UiStyle.HINT_COLOR, 15)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.uppercase = true
	column.add_child(caption)
	_field = _make_field(suggested_name)
	column.add_child(_field)
	_error_label = MenuPanel.make_label("", UiStyle.BLOCKED_COLOR, 15)
	_error_label.visible = false
	column.add_child(_error_label)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	for button: Button in [MenuPanel.make_button("Zurück", back_requested.emit), MenuPanel.make_button("Speichern", _save)]:
		button.custom_minimum_size = Vector2(170, 46)
		footer.add_child(button)
	add_child(_confirm)


func _ready() -> void:
	_field.grab_focus.call_deferred()
	_field.select_all.call_deferred()


## Zeigt, warum nicht gespeichert wurde.
func show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""


## Der eingetippte Name (für Tests und Startparameter).
func set_name_text(text: String) -> void:
	_field.text = text


## Wie „Speichern“: bei belegtem Namen erst die Rückfrage.
func submit() -> void:
	_save()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_visible_in_tree() and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _make_field(text: String) -> LineEdit:
	var field := LineEdit.new()
	field.text = text
	field.custom_minimum_size = FIELD_SIZE
	field.max_length = MAX_NAME_LENGTH
	field.add_theme_font_size_override("font_size", 18)
	field.add_theme_stylebox_override("normal", UiStyle.card_style(Color(0, 0, 0, 0.45), UiStyle.PANEL_BORDER_COLOR))
	field.add_theme_stylebox_override("focus", UiStyle.card_style(Color(0, 0, 0, 0), UiStyle.GOLD_COLOR, 2))
	field.add_theme_color_override("font_color", UiStyle.TEXT_COLOR)
	field.add_theme_color_override("caret_color", UiStyle.GOLD_COLOR)
	field.add_theme_color_override("selection_color", UiStyle.GOLD_COLOR.darkened(0.5))
	field.text_changed.connect(func(_text: String) -> void: show_error(""))
	field.text_submitted.connect(func(_text: String) -> void: _save())
	return field


func _save() -> void:
	var save_name := _field.text.strip_edges()
	if save_name != "" and _saves.is_name_taken(save_name):
		_confirm.ask("Es gibt schon einen Spielstand „%s“. Überschreiben?" % save_name, "Überschreiben",
				save_requested.emit.bind(save_name))
	else:
		save_requested.emit(save_name)
