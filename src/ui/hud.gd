class_name Hud
extends CanvasLayer
## Bedienoberfläche: Titelleiste mit Tag, Geschwindigkeit und Steuerungshinweisen
## sowie Info zur Kachel unter der Maus.

const PANEL_COLOR := Color(0.08, 0.07, 0.05, 0.82)
const TEXT_COLOR := Color("#e8dcc0")
const HINT_COLOR := Color("#a89c80")

var _info_label: Label
var _seed_label: Label
var _day_label: Label
var _speed_label: Label
var _info_panel: PanelContainer


func _ready() -> void:
	var bar := _make_panel()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bar.add_child(row)
	row.add_child(_make_label("Burgwacht", TEXT_COLOR, 20))
	_seed_label = _make_label("", HINT_COLOR, 14)
	row.add_child(_seed_label)
	_day_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_day_label)
	_speed_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_speed_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_make_label(
		"WASD/Pfeile oder zwei Finger: bewegen  ·  Pinch/Mausrad: zoomen  ·  Leertaste: Pause  ·  1/2/3: Tempo"
		+ "  ·  N: neue Karte  ·  F: Vollbild",
		HINT_COLOR, 14))
	add_child(bar)

	_info_panel = _make_panel()
	_info_label = _make_label("", TEXT_COLOR, 15)
	_info_panel.add_child(_info_label)
	add_child(_info_panel)
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.visible = false


func set_seed(map_seed: int) -> void:
	_seed_label.text = "Karte #%d" % map_seed


func show_day(day: int) -> void:
	_day_label.text = "Tag %d" % day


func show_speed(speed: int, paused: bool) -> void:
	_speed_label.text = "Pause" if paused else "%d×" % speed


func show_tile_info(text: String) -> void:
	_info_label.text = text
	_info_panel.visible = text != ""
	_info_panel.reset_size()


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_content_margin_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
