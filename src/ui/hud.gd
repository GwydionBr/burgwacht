class_name Hud
extends CanvasLayer
## Bedienoberfläche: Titelleiste mit Tag, Geschwindigkeit, Bestand und Bewohnern, Meldungen oben
## rechts darunter, Steuerungshinweise, Info zur Kachel unter der Maus, ein Hinweis zum Bauen (z. B. Grund für rote Vorschau)
## und die Bauleiste mit einem Knopf je baubarem Gebäude samt Kosten und dem Abriss-Werkzeug.

## Ein Knopf der Bauleiste wurde gedrückt.
signal build_selected(type_id: String)
## Der Abriss-Knopf wurde gedrückt.
signal demolish_selected()

const PANEL_COLOR := Color(0.08, 0.07, 0.05, 0.82)
const TEXT_COLOR := Color("#e8dcc0")
const HINT_COLOR := Color("#a89c80")
const BLOCKED_COLOR := Color("#ff8a70")
## So lange bleibt eine Meldung (z. B. „Gespeichert“) stehen, in Sekunden.
const MESSAGE_SECONDS := 3.0
## Abstand des Bauhinweises und der Meldungen vom oberen Rand, unterhalb der Titelleiste.
const BUILD_HINT_TOP := 64

var _info_label: Label
var _seed_label: Label
var _day_label: Label
var _speed_label: Label
var _message_label: Label
var _message_panel: PanelContainer
var _message_timer: Timer
var _info_panel: PanelContainer
var _stock_label: Label
var _residents_label: Label
var _build_label: Label
var _build_panel: PanelContainer
var _build_bar: PanelContainer
## Gebäudetyp → Knopf der Bauleiste.
var _build_buttons: Dictionary[String, Button] = {}
var _demolish_button: Button


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
	_stock_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_stock_label)
	_residents_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_residents_label)
	add_child(bar)

	# Meldungen eigen statt in der Titelleiste, damit sie bei langem Bestand nicht abgeschnitten werden.
	_message_panel = _make_panel()
	_message_label = _make_label("", TEXT_COLOR, 16)
	_message_panel.add_child(_message_label)
	add_child(_message_panel)
	_message_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_message_panel.offset_top = BUILD_HINT_TOP
	_message_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_message_panel.visible = false
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_panel.visible = false)
	add_child(_message_timer)

	var help_panel := _make_panel()
	help_panel.add_child(_make_label(
		"Linksklick: gründen/bauen/abreißen  ·  X: Abriss  ·  Rechtsklick/Esc: beenden\n"
		+ "WASD/Pfeile, zwei Finger: bewegen  ·  Pinch/Mausrad: zoomen\n"
		+ "Leertaste: Pause  ·  1/2/3: Tempo  ·  N: neue Karte\n"
		+ "F5/F9: speichern/laden  ·  F: Vollbild",
		HINT_COLOR, 13))
	add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_info_panel = _make_panel()
	_info_label = _make_label("", TEXT_COLOR, 15)
	_info_panel.add_child(_info_label)
	add_child(_info_panel)
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.visible = false

	_build_panel = _make_panel()
	_build_label = _make_label("", TEXT_COLOR, 17)
	_build_panel.add_child(_build_label)
	add_child(_build_panel)
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, BUILD_HINT_TOP)
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.visible = false

	_build_bar = _make_panel()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_build_bar.add_child(buttons)
	for type_id in GameWorld.buildable_types():
		var button := _make_build_button(type_id)
		buttons.add_child(button)
		_build_buttons[type_id] = button
	_demolish_button = _make_tool_button("Abriss [X]\nHälfte zurück")
	_demolish_button.pressed.connect(demolish_selected.emit)
	buttons.add_child(_demolish_button)
	add_child(_build_bar)
	_build_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	_build_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN


func set_seed(map_seed: int) -> void:
	_seed_label.text = "Karte #%d" % map_seed


func show_day(day: int) -> void:
	_day_label.text = "Tag %d" % day


func show_speed(speed: int, paused: bool) -> void:
	_speed_label.text = "Pause" if paused else "%d×" % speed


## Kurze Meldung oben rechts unter der Titelleiste, verschwindet nach MESSAGE_SECONDS.
func show_message(text: String) -> void:
	_message_label.text = text
	_message_panel.visible = true
	_message_panel.reset_size()
	_message_timer.start(MESSAGE_SECONDS)


func show_tile_info(text: String) -> void:
	_info_label.text = text
	_info_panel.visible = text != ""
	_info_panel.reset_size()


## Bestand und Lagerbelegung in der Titelleiste, z. B. „Holz 100 · Stein 50 · Warenlager 150/200“.
func show_stock(text: String) -> void:
	_stock_label.text = text


## Bewohnerzahl in der Titelleiste, z. B. „Bewohner 8 (Untätig 4)“.
func show_residents(total: int, idle: int) -> void:
	_residents_label.text = "Bewohner %d (Untätig %d)" % [total, idle]


## Hinweis oben in der Mitte (leer = ausblenden); rot, wenn hier nicht gebaut werden darf.
func show_build_hint(text: String, allowed: bool) -> void:
	_build_label.text = text
	_build_label.add_theme_color_override("font_color", TEXT_COLOR if allowed else BLOCKED_COLOR)
	_build_panel.visible = text != ""
	_build_panel.reset_size()


## Bauleiste sperren (während der Gründung) oder freigeben.
func set_build_bar_enabled(enabled: bool) -> void:
	for button: Button in _build_buttons.values():
		button.disabled = not enabled
	_demolish_button.disabled = not enabled


## Hebt den Knopf des gewählten Werkzeugs hervor: Gebäudetyp im Baumodus (leer = keiner)
## oder das Abriss-Werkzeug.
func show_tool(build_type: String, demolishing: bool) -> void:
	for button_type: String in _build_buttons:
		_build_buttons[button_type].set_pressed_no_signal(button_type == build_type)
	_demolish_button.set_pressed_no_signal(demolishing)


## Knopf mit Name, Taste und Kosten, z. B. „Holzfäller [H]“ über „3 Holz“.
func _make_build_button(type_id: String) -> Button:
	var defs := GameDefs.get_instance()
	var def: Dictionary = defs.buildings[type_id]
	var cost: Dictionary = def["cost"]
	var cost_parts: PackedStringArray = []
	for good: String in cost:
		cost_parts.append("%d %s" % [int(cost[good]), defs.goods[good]["name"]])
	var button := _make_tool_button(
		"%s [%s]\n%s" % [def["name"], def["hotkey"], ", ".join(cost_parts) if not cost_parts.is_empty() else "kostenlos"])
	button.pressed.connect(func() -> void: build_selected.emit(type_id))
	return button


## Umschaltknopf der Bauleiste.
func _make_tool_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	# Kein Tastaturfokus, sonst löst die Leertaste (Pause) den Knopf aus.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size = Vector2(120, 0)
	return button


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
