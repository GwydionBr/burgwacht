class_name SaveView
extends MenuView
## Die Speichern-Ansicht im Holz-Gold-Stil der Menüs: ein Namensfeld, vorbelegt mit dem Vorschlag
## der Partie („Freies Spiel – Tag 12“), dazu „Speichern“ (auch Enter) und „Zurück“ (auch Esc).
## Gibt es den Namen schon, fragt sie vor dem Überschreiben nach. Speichern muss der Aufrufer;
## scheitert es, zeigt show_error() den Grund.

## Unter diesem Namen speichern (ein gleichnamiger Spielstand darf überschrieben werden).
signal save_requested(save_name: String)

const FIELD_SIZE := Vector2(460, 46)
## Längster Name; so bleibt der daraus abgeleitete Dateiname meist eindeutig.
const MAX_NAME_LENGTH := 60

var _saves: SaveGames
var _field: LineEdit
var _confirm := ConfirmDialog.new()


## saves: um belegte Namen zu erkennen; suggested_name: die Vorbelegung des Namensfelds.
func _init(saves: SaveGames, suggested_name: String) -> void:
	super()
	_saves = saves
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
	column.add_child(_error_label)
	column.add_child(_make_footer([MenuPanel.make_button("Speichern", _save)]))
	add_child(_confirm)


func _ready() -> void:
	_field.grab_focus.call_deferred()
	_field.select_all.call_deferred()


## Der eingetippte Name (für Tests und Startparameter).
func set_name_text(text: String) -> void:
	_field.text = text


## Wie „Speichern“: bei belegtem Namen erst die Rückfrage.
func submit() -> void:
	_save()


func _make_field(text: String) -> LineEdit:
	var field := MenuPanel.make_field(18)
	field.text = text
	field.custom_minimum_size = FIELD_SIZE
	field.max_length = MAX_NAME_LENGTH
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
