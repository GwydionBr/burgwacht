class_name SettingsView
extends CanvasLayer
## Die Einstellungen-Ansicht (aus Hauptmenü und Spielmenü): ein MenuPanel mit Vollbild/Fenster,
## Kamerageschwindigkeit und „Zurück“. Jede Änderung geht sofort an Settings, das sie speichert
## und meldet; angewendet wird sie dort, wo man auf Settings.changed hört. „Zurück“ meldet
## `closed`, wohin es zurückgeht, entscheidet, wer die Ansicht geöffnet hat.

signal closed

const SLIDER_STEP := 0.1
const SLIDER_HEIGHT := 28.0
const SLIDER_GRABBER_SIZE := 18

var _settings: Settings
var _panel: MenuPanel
var _fullscreen_button: Button
var _speed_label: Label
var _speed_slider: HSlider


## dimmed legt eine Abdunkelung darunter, die alle Klicks auf Karte und HUD abfängt (in der Partie).
func _init(settings: Settings, dimmed: bool) -> void:
	_settings = settings
	layer = 3
	visible = false
	MenuPanel.add_dim(self, MenuPanel.DIM_COLOR if dimmed else Color.TRANSPARENT)
	_panel = MenuPanel.new("Einstellungen")
	add_child(_panel)
	_fullscreen_button = _panel.add_entry("", func() -> void: _settings.set_fullscreen(not _settings.is_fullscreen()))
	_panel.add_control(_make_speed_row())
	_panel.add_entry("Zurück", close)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.changed.connect(_refresh)
	_refresh()


func open() -> void:
	_refresh()
	visible = true
	_panel.reset_size()


## Schließt die Ansicht und meldet `closed`.
func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _make_speed_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_speed_label = MenuPanel.make_label("", UiStyle.TEXT_COLOR, MenuPanel.ENTRY_FONT_SIZE)
	row.add_child(_speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = Settings.MIN_CAMERA_SPEED
	_speed_slider.max_value = Settings.MAX_CAMERA_SPEED
	_speed_slider.step = SLIDER_STEP
	_speed_slider.focus_mode = Control.FOCUS_NONE
	_speed_slider.custom_minimum_size = Vector2(MenuPanel.ENTRY_SIZE.x, SLIDER_HEIGHT)
	var track := UiStyle.card_style(UiStyle.WOOD_COLOR, UiStyle.PANEL_BORDER_COLOR)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := UiStyle.card_style(UiStyle.GOLD_COLOR.darkened(0.35), UiStyle.GOLD_COLOR.darkened(0.3))
	_speed_slider.add_theme_stylebox_override("slider", track)
	_speed_slider.add_theme_stylebox_override("grabber_area", filled)
	_speed_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var grabber := _grabber_icon(UiStyle.GOLD_COLOR)
	_speed_slider.add_theme_icon_override("grabber", grabber)
	_speed_slider.add_theme_icon_override("grabber_highlight", _grabber_icon(UiStyle.TEXT_COLOR))
	_speed_slider.value_changed.connect(_settings.set_camera_speed)
	row.add_child(_speed_slider)
	return row


## Runder Griff des Schiebereglers in dieser Farbe.
static func _grabber_icon(color: Color) -> Texture2D:
	var image := Image.create_empty(SLIDER_GRABBER_SIZE, SLIDER_GRABBER_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SLIDER_GRABBER_SIZE, SLIDER_GRABBER_SIZE) * 0.5
	for y in SLIDER_GRABBER_SIZE:
		for x in SLIDER_GRABBER_SIZE:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance <= center.x - 1.0:
				image.set_pixel(x, y, color)
			elif distance <= center.x:
				image.set_pixel(x, y, UiStyle.BAR_COLOR)
	return ImageTexture.create_from_image(image)


func _refresh() -> void:
	_fullscreen_button.text = "Anzeige: %s (F)" % ("Vollbild" if _settings.is_fullscreen() else "Fenster")
	_speed_label.text = "Kamerageschwindigkeit: %d %%" % roundi(_settings.get_camera_speed() * 100.0)
	_speed_slider.set_value_no_signal(_settings.get_camera_speed())
