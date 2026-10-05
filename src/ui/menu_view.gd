class_name MenuView
extends PanelContainer
## Grundlage der Ansichten, die an Stelle eines Menüs stehen (Szenarioauswahl, Speichern, Laden):
## Rahmen im Holz-Gold-Stil, unten rechts „Zurück“ mit weiteren Knöpfen (_make_footer()), Esc
## wirkt wie „Zurück“, und eine rote Zeile zeigt mit show_error(), warum etwas nicht ging. Wo die
## Zeile steht, bestimmt die Ansicht, indem sie _error_label einhängt.

## „Zurück“ oder Esc.
signal back_requested()

const FOOTER_BUTTON_SIZE := Vector2(170, 46)
const ERROR_FONT_SIZE := 15

var _error_label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", MenuPanel.frame_style())
	_error_label = MenuPanel.make_label("", UiStyle.BLOCKED_COLOR, ERROR_FONT_SIZE)
	_error_label.visible = false


## Zeigt, warum etwas nicht ging; leer blendet die Zeile aus.
func show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_visible_in_tree() and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Die Fußzeile: rechtsbündig „Zurück“, dahinter diese Knöpfe, alle gleich groß.
func _make_footer(buttons: Array[Button] = []) -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	for button: Button in [MenuPanel.make_button("Zurück", back_requested.emit)] + buttons:
		button.custom_minimum_size = FOOTER_BUTTON_SIZE
		footer.add_child(button)
	return footer
