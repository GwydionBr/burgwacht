class_name ConfirmDialog
extends CanvasLayer
## Eine Rückfrage über allem, im Holz-Gold-Stil der Menüs: die Frage, ein Knopf, der bestätigt
## (z. B. „Überschreiben“, „Löschen“, „Verwerfen“), und einer, der abbricht (auch Esc).
## Eine Abdunkelung fängt solange alle Klicks ab. Wiederverwendbar: ask() setzt Frage, Knöpfe und
## das, was beim Bestätigen geschieht, jedes Mal neu.

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const TEXT_WIDTH := 440.0
const BUTTON_SIZE := Vector2(190, 46)

var _question: Label
var _confirm_button: Button
var _cancel_button: Button
var _on_confirm := Callable()


func _init() -> void:
	layer = 10
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuPanel.frame_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	_question = MenuPanel.make_label("", UiStyle.TEXT_COLOR, 19)
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	column.add_child(_question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	_cancel_button = MenuPanel.make_button("", cancel)
	_confirm_button = MenuPanel.make_button("", _confirm)
	for button: Button in [_cancel_button, _confirm_button]:
		button.custom_minimum_size = BUTTON_SIZE
		row.add_child(button)


## Stellt die Frage; confirm_text führt on_confirm aus, cancel_text (oder Esc) schließt nur.
func ask(question: String, confirm_text: String, on_confirm: Callable, cancel_text := "Abbrechen") -> void:
	_question.text = question
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	_on_confirm = on_confirm
	visible = true
	# Ein Textfeld mit Fokus würde Enter sonst selbst verbrauchen.
	if is_inside_tree():
		get_viewport().gui_release_focus()


## Schließt die Rückfrage, ohne etwas zu tun.
func cancel() -> void:
	visible = false
	_on_confirm = Callable()


func is_open() -> bool:
	return visible


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_confirm()


func _confirm() -> void:
	var action := _on_confirm
	cancel()
	if action.is_valid():
		action.call()
