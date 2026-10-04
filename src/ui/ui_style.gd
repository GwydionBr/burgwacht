class_name UiStyle
extends RefCounted
## Farben und Stile der Oberfläche an einer Stelle: dunkles Holz mit Messingrand, Schrift wie
## Pergament, Gold für das Gewählte.

const TEXT_COLOR := Color("#f0e4c4")
const HINT_COLOR := Color("#b3a483")
const BLOCKED_COLOR := Color("#ff8a70")
const GOLD_COLOR := Color("#e0b85a")
## Hintergrund der Felder (Titelleiste, Ansichten, Bauleiste).
const PANEL_COLOR := Color(0.09, 0.07, 0.045, 0.9)
const PANEL_BORDER_COLOR := Color("#6b5434")
## Karten und Reiter der Bauleiste: Holz in drei Helligkeiten.
const WOOD_COLOR := Color("#3a2b1b")
const WOOD_HOVER_COLOR := Color("#4d3a24")
const WOOD_PRESSED_COLOR := Color("#5e4526")
const TAB_COLOR := Color(0.13, 0.1, 0.065, 0.92)
## Grund der Bauleiste, deckend, damit der gewählte Reiter nahtlos in sie übergeht.
const BAR_COLOR := Color("#1d160e")
const CORNER_RADIUS := 6


## Feld mit Holzgrund und Messingrand.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	return style


## Karte der Bauleiste: Holz mit Rand in border; gewählt mit dickem Goldrand.
static func card_style(bg: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(6)
	return style


## Feld der Bauleiste: wie panel_style(), aber deckend.
static func bar_style() -> StyleBoxFlat:
	var style := panel_style()
	style.bg_color = BAR_COLOR
	return style


## Reiter der Bauleiste: oben abgerundet, unten bündig mit dem Feld darunter. Der gewählte
## Reiter hat den Grund des Felds, oben einen Goldstreifen und reicht über dessen Rand hinweg.
static func tab_style(selected: bool, hovered := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BAR_COLOR if selected else (WOOD_COLOR if hovered else TAB_COLOR)
	if selected:
		style.expand_margin_bottom = 2
	style.border_color = GOLD_COLOR if selected else PANEL_BORDER_COLOR
	style.border_width_top = 3 if selected else 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Titelleiste über die ganze Breite: deckendes Holz, unten ein Goldrand und ein Schatten.
static func title_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BAR_COLOR
	style.border_color = GOLD_COLOR.darkened(0.3)
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Füllbalken der Titelleiste (Lager, Beliebtheit): dunkle Rinne, Füllung in fill.
static func meter_styles(fill: Color) -> Array[StyleBoxFlat]:
	var background := card_style(Color(0, 0, 0, 0.5), PANEL_BORDER_COLOR.darkened(0.2))
	background.set_corner_radius_all(2)
	background.set_content_margin_all(0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(2)
	return [background, fill_style]


## Gibt einem Knopf für alle Zustände die Stile einer Karte der Bauleiste.
static func apply_card_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", card_style(WOOD_COLOR, PANEL_BORDER_COLOR))
	button.add_theme_stylebox_override("hover", card_style(WOOD_HOVER_COLOR, GOLD_COLOR.darkened(0.35)))
	button.add_theme_stylebox_override("pressed", card_style(WOOD_PRESSED_COLOR, GOLD_COLOR, 3))
	button.add_theme_stylebox_override("hover_pressed", card_style(WOOD_PRESSED_COLOR, GOLD_COLOR, 3))
	button.add_theme_stylebox_override("disabled", card_style(WOOD_COLOR.darkened(0.3), PANEL_BORDER_COLOR.darkened(0.4)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Gibt einem Knopf die Stile eines Reiters der Bauleiste.
static func apply_tab_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", tab_style(false))
	button.add_theme_stylebox_override("hover", tab_style(false, true))
	button.add_theme_stylebox_override("pressed", tab_style(true))
	button.add_theme_stylebox_override("hover_pressed", tab_style(true))
	button.add_theme_stylebox_override("disabled", tab_style(false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", HINT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", GOLD_COLOR)
	button.add_theme_color_override("font_hover_pressed_color", GOLD_COLOR)
