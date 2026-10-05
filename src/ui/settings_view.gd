class_name SettingsView
extends CanvasLayer
## Die Einstellungen-Ansicht (aus Hauptmenü und Spielmenü): ein MenuPanel mit Vollbild/Fenster,
## Kamerageschwindigkeit, den Lautstärken Gesamt, Musik und Geräusche und „Zurück“. Jede Änderung
## geht sofort an Settings, das sie speichert und meldet; angewendet wird sie dort, wo man auf
## Settings.changed hört. „Zurück“ meldet `closed`, wohin es zurückgeht, entscheidet, wer die
## Ansicht geöffnet hat.

signal closed

const SLIDER_STEP := 0.1
const VOLUME_STEP := 5.0
const SLIDER_HEIGHT := 28.0
const SLIDER_GRABBER_SIZE := 18


## Ein Schieberegler mit Beschriftung darüber.
class SliderRow:
	var label: Label
	var slider: HSlider


var _settings: Settings
var _panel: MenuPanel
var _fullscreen_button: Button
var _speed_row: SliderRow
var _master_row: SliderRow
var _music_row: SliderRow
var _sound_row: SliderRow


## dimmed legt eine Abdunkelung darunter, die alle Klicks auf Karte und HUD abfängt (in der Partie).
func _init(settings: Settings, dimmed: bool) -> void:
	_settings = settings
	layer = 3
	visible = false
	MenuPanel.add_dim(self, MenuPanel.DIM_COLOR if dimmed else Color.TRANSPARENT)
	_panel = MenuPanel.new("Einstellungen")
	add_child(_panel)
	_fullscreen_button = _panel.add_entry("", func() -> void: _settings.set_fullscreen(not _settings.is_fullscreen()))
	_speed_row = _add_slider_row(Settings.MIN_CAMERA_SPEED, Settings.MAX_CAMERA_SPEED, SLIDER_STEP, _settings.set_camera_speed)
	_master_row = _add_volume_row(_settings.set_master_volume)
	_music_row = _add_volume_row(_settings.set_music_volume)
	_sound_row = _add_volume_row(_settings.set_sound_volume)
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


## Regler für eine Lautstärke von 0 bis Settings.MAX_VOLUME; setter bekommt den ganzzahligen Wert.
func _add_volume_row(setter: Callable) -> SliderRow:
	return _add_slider_row(0.0, Settings.MAX_VOLUME, VOLUME_STEP, func(value: float) -> void: setter.call(roundi(value)))


## Fügt dem Panel einen Regler mit Beschriftung hinzu; on_change bekommt jeden neuen Wert.
func _add_slider_row(min_value: float, max_value: float, step: float, on_change: Callable) -> SliderRow:
	var row := SliderRow.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	row.label = MenuPanel.make_label("", UiStyle.TEXT_COLOR, MenuPanel.ENTRY_FONT_SIZE)
	box.add_child(row.label)
	row.slider = HSlider.new()
	row.slider.min_value = min_value
	row.slider.max_value = max_value
	row.slider.step = step
	row.slider.focus_mode = Control.FOCUS_NONE
	row.slider.custom_minimum_size = Vector2(MenuPanel.ENTRY_SIZE.x, SLIDER_HEIGHT)
	var track := UiStyle.card_style(UiStyle.WOOD_COLOR, UiStyle.PANEL_BORDER_COLOR)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := UiStyle.card_style(UiStyle.GOLD_COLOR.darkened(0.35), UiStyle.GOLD_COLOR.darkened(0.3))
	row.slider.add_theme_stylebox_override("slider", track)
	row.slider.add_theme_stylebox_override("grabber_area", filled)
	row.slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	row.slider.add_theme_icon_override("grabber", _grabber_icon(UiStyle.GOLD_COLOR))
	row.slider.add_theme_icon_override("grabber_highlight", _grabber_icon(UiStyle.TEXT_COLOR))
	row.slider.value_changed.connect(on_change)
	box.add_child(row.slider)
	_panel.add_control(box)
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
	_show(_speed_row, "Kamerageschwindigkeit", _settings.get_camera_speed() * 100.0, _settings.get_camera_speed())
	_show(_master_row, "Lautstärke gesamt", _settings.get_master_volume(), _settings.get_master_volume())
	_show(_music_row, "Musik", _settings.get_music_volume(), _settings.get_music_volume())
	_show(_sound_row, "Geräusche", _settings.get_sound_volume(), _settings.get_sound_volume())


## Beschriftet den Regler mit title und Prozentwert und stellt ihn auf value, ohne zu melden.
static func _show(row: SliderRow, title: String, percent: float, value: float) -> void:
	row.label.text = "%s: %d %%" % [title, roundi(percent)]
	row.slider.set_value_no_signal(value)
