class_name MenuPanel
extends PanelContainer
## Ein Menü im Holz-Gold-Stil der Oberfläche: Titel, Untertitel und eine senkrechte Liste
## gleich breiter Knöpfe. Hauptmenü und Spielmenü bauen sich daraus; weitere Einträge kommen
## mit add_entry() dazu, andere Bedienelemente mit add_control().

const ENTRY_SIZE := Vector2(300, 48)
const ENTRY_FONT_SIZE := 20

var _entries: VBoxContainer
var _subtitle: Label


func _init(title: String, subtitle := "") -> void:
	var style := UiStyle.panel_style()
	style.set_content_margin_all(28)
	style.border_color = UiStyle.GOLD_COLOR.darkened(0.3)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.add_child(_make_label(title, UiStyle.GOLD_COLOR, 44))
	_subtitle = _make_label("", UiStyle.HINT_COLOR, 16)
	column.add_child(_subtitle)
	set_subtitle(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)
	_entries = VBoxContainer.new()
	_entries.add_theme_constant_override("separation", 12)
	column.add_child(_entries)


## Ändert den Untertitel; leer blendet ihn aus.
func set_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle.visible = text != ""


## Hängt einen Knopf an, der action aufruft; der Knopf kommt zurück (z. B. zum Sperren).
func add_entry(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = ENTRY_SIZE
	button.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	UiStyle.apply_card_style(button)
	button.add_theme_color_override("font_color", UiStyle.TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", UiStyle.GOLD_COLOR)
	button.add_theme_color_override("font_pressed_color", UiStyle.GOLD_COLOR)
	button.add_theme_color_override("font_disabled_color", UiStyle.HINT_COLOR.darkened(0.3))
	button.pressed.connect(action)
	_entries.add_child(button)
	return button


## Hängt ein beliebiges Bedienelement an (z. B. eine Zeile mit Schieberegler).
func add_control(control: Control) -> void:
	_entries.add_child(control)


static func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
