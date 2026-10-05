class_name LoadView
extends PanelContainer
## Die Ladeansicht im Holz-Gold-Stil der Menüs: alle Spielstände eines Ordners, der neueste oben,
## je mit Name, Szenario, Tag und Datum; Schnell- und Autospielstand tragen eine Marke. Ein Klick
## auf einen Spielstand meldet ihn zum Laden; veraltete und beschädigte sind ausgegraut mit Grund
## und lassen sich nur löschen. Löschen fragt vorher nach. „Zurück“ (auch Esc) meldet die Rückkehr.
## Erreichbar aus Hauptmenü, Spielmenü und Niederlage-Ansicht; laden muss der Aufrufer.

## Dieser Spielstand soll geladen werden; scheitert es, zeigt show_error() den Grund.
signal load_requested(path: String)
## „Zurück“ oder Esc.
signal back_requested()

const LIST_SIZE := Vector2(640, 380)
const ROW_HEIGHT := 64.0
const DELETE_WIDTH := 110.0
## Marken der Sonder-Spielstände.
const KIND_MARKS: Dictionary[SaveGame.Kind, String] = {
	SaveGame.Kind.QUICK: "F5 / F9",
	SaveGame.Kind.AUTO: "zu Tagesbeginn",
}

var _saves: SaveGames
var _rows: VBoxContainer
var _error_label: Label
var _confirm := ConfirmDialog.new()


func _init(saves: SaveGames) -> void:
	_saves = saves
	add_theme_stylebox_override("panel", MenuPanel.frame_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(MenuPanel.make_label("Laden", UiStyle.GOLD_COLOR, 36))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_error_label = MenuPanel.make_label("", UiStyle.BLOCKED_COLOR, 15)
	_error_label.visible = false
	column.add_child(_error_label)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	var back := MenuPanel.make_button("Zurück", back_requested.emit)
	back.custom_minimum_size = Vector2(170, 46)
	footer.add_child(back)
	add_child(_confirm)
	_fill()


## Zeigt, warum ein Spielstand nicht geladen oder gelöscht werden konnte.
func show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_visible_in_tree() and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Baut die Liste neu aus dem Ordner.
func _fill() -> void:
	for row in _rows.get_children():
		row.queue_free()
	var saves := _saves.list()
	if saves.is_empty():
		var empty := MenuPanel.make_label("Noch keine Spielstände", UiStyle.HINT_COLOR, 17)
		empty.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(empty)
	for save in saves:
		_rows.add_child(_make_row(save))


func _make_row(save: SaveGame) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var loadable := save.is_loadable()
	var entry := MenuPanel.make_button("", load_requested.emit.bind(save.path))
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	entry.disabled = not loadable
	row.add_child(entry)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	entry.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(lines)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(top)
	var name_label := _make_text(save.name, UiStyle.TEXT_COLOR if loadable else UiStyle.HINT_COLOR.darkened(0.2), 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	if not loadable:
		top.add_child(_make_text("veraltet" if save.is_outdated() else "beschädigt", UiStyle.BLOCKED_COLOR, 15))
	elif KIND_MARKS.has(save.kind):
		top.add_child(_make_text(KIND_MARKS[save.kind], UiStyle.GOLD_COLOR, 15))
	lines.add_child(_make_text(_details(save), UiStyle.HINT_COLOR if loadable else UiStyle.HINT_COLOR.darkened(0.35), 14))
	var delete := MenuPanel.make_button("Löschen", _ask_delete.bind(save))
	delete.custom_minimum_size = Vector2(DELETE_WIDTH, ROW_HEIGHT)
	delete.add_theme_font_size_override("font_size", 16)
	row.add_child(delete)
	return row


## Zweite Zeile: Szenario, Tag und Datum; bei nicht ladbaren der Grund.
static func _details(save: SaveGame) -> String:
	if save.is_outdated():
		return "Aus einer früheren Spielversion – lässt sich nur löschen"
	if not save.is_loadable():
		return save.error
	return "%s  ·  Tag %d  ·  %s" % [save.scenario_title, save.day, _date_text(save.saved_at)]


## Speicherdatum in Ortszeit, z. B. „05.10.2026, 14:32“.
static func _date_text(unix_seconds: float) -> String:
	var local := int(unix_seconds) + int(Time.get_time_zone_from_system()["bias"]) * 60
	var date := Time.get_datetime_dict_from_unix_time(local)
	return "%02d.%02d.%04d, %02d:%02d" % [date["day"], date["month"], date["year"], date["hour"], date["minute"]]


static func _make_text(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _ask_delete(save: SaveGame) -> void:
	_confirm.ask("Spielstand „%s“ löschen?" % save.name, "Löschen", _delete.bind(save))


func _delete(save: SaveGame) -> void:
	show_error(_saves.delete(save))
	_fill()
