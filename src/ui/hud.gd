class_name Hud
extends CanvasLayer
## Bedienoberfläche: Titelleiste mit Tag, Geschwindigkeit, Belegung je Lagerart, Bewohnern und Gold, Meldungen oben
## rechts darunter, die Ankündigung der nächsten Welle samt Countdown oben links darunter, Steuerungshinweise, Info zur Kachel unter der Maus, ein Hinweis zum Bauen (z. B. Grund für rote Vorschau)
## und unten mittig die Bauleiste: Reiter je Kategorie, darunter je Gebäude der Kategorie eine Karte
## mit Symbol, Name, Taste und Kosten (rot, wenn sie nicht reichen) und daneben das Abriss-Werkzeug.
## Die Verwaltung (Taste V) zeigt Ration und Steuersatz zum Umstellen und die Faktoren der Beliebtheit.
## Die Marktansicht (Taste M) zeigt je Ware Bestand, Kauf- und Verkaufspreis und Knöpfe zum Handeln;
## sie ist zugleich die Bestandsübersicht. Die Kasernenansicht (Linksklick auf eine Kaserne) zeigt
## Untätige und Waffen und je Soldatentyp einen Knopf zum Anwerben. Verwaltung, Marktansicht und
## Kasernenansicht schließen sich gegenseitig. Nach der Niederlage liegt die Niederlage-Ansicht
## über allem: „Der Bergfried ist gefallen“, der erreichte Tag und die Knöpfe „Neue Partie“ und
## „Beenden“.

## Ein Knopf der Bauleiste wurde gedrückt.
signal build_selected(type_id: String)
## Der Abriss-Knopf wurde gedrückt.
signal demolish_selected()
## In der Verwaltung soll die Ration um so viele Stufen steigen (+1) bzw. sinken (−1).
signal ration_step(delta: int)
## In der Verwaltung soll der Steuersatz um so viele Stufen steigen (+1) bzw. sinken (−1).
signal tax_rate_step(delta: int)
## In der Marktansicht soll mit dieser Ware gehandelt werden: kaufen (true) oder verkaufen.
signal trade_requested(good: String, buying: bool)
## In der Kasernenansicht soll ein Soldat dieses Typs angeworben werden.
signal recruit_requested(type_id: String)
## In der Niederlage-Ansicht wurde „Neue Partie“ gedrückt.
signal new_game_requested()
## In der Niederlage-Ansicht wurde „Beenden“ gedrückt.
signal quit_requested()

const TEXT_COLOR := UiStyle.TEXT_COLOR
const HINT_COLOR := UiStyle.HINT_COLOR
const BLOCKED_COLOR := UiStyle.BLOCKED_COLOR
## Größe einer Karte der Bauleiste.
const CARD_SIZE := Vector2(152, 140)
## Höhe des Gebäudesymbols auf einer Karte.
const CARD_ICON_HEIGHT := 54
const CARD_SEPARATION := 10
## Breite einer Spalte (Knopf, Grund, Hinweis) je Soldatentyp in der Kasernenansicht.
const RECRUIT_COLUMN_WIDTH := 250
## So lange bleibt eine Meldung (z. B. „Gespeichert“) stehen, in Sekunden.
const MESSAGE_SECONDS := 3.0
## Abstand des Bauhinweises und der Meldungen vom oberen Rand, unterhalb der Titelleiste.
const BUILD_HINT_TOP := 64
## Steigende Beliebtheit (fallende in BLOCKED_COLOR).
const UP_COLOR := Color("#9fd88a")
## Abstand der Felder vom Bildschirmrand und zwischen Feldern übereinander.
const MARGIN := 12
const DEFEAT_DIM_COLOR := Color(0, 0, 0, 0.45)

var _info_label: Label
var _seed_label: Label
var _day_label: Label
## Ankündigung der nächsten Welle („Welle aus Norden in 0:42“); unsichtbar, wenn keine läuft.
var _announcement_panel: PanelContainer
var _announcement_label: Label
var _speed_label: Label
var _message_label: Label
var _message_panel: PanelContainer
var _message_timer: Timer
var _info_panel: PanelContainer
var _storage_label: Label
var _residents_label: Label
var _soldiers_label: Label
var _popularity_label: Label
var _gold_label: Label
var _admin_panel: PanelContainer
var _ration_label: Label
var _tax_rate_label: Label
var _eaten_label: Label
var _factors_label: Label
var _factor_sum_label: Label
var _market_panel: PanelContainer
## Ware → Feld für ihren Bestand in der Marktansicht.
var _market_stock_labels: Dictionary[String, Label] = {}
## Grund oben in der Marktansicht, solange kein Markt steht.
var _market_missing_label: Label
## Ware → Knopf „Kaufen“ bzw. „Verkaufen“ in der Marktansicht (nur handelbare Waren).
var _buy_buttons: Dictionary[String, Button] = {}
var _sell_buttons: Dictionary[String, Button] = {}
var _barracks_panel: PanelContainer
## Untätige und Waffen in der Kasernenansicht.
var _barracks_stock_label: Label
## Soldatentyp → Knopf „anwerben“ in der Kasernenansicht.
var _recruit_buttons: Dictionary[String, Button] = {}
## Soldatentyp → Grund unter dem Knopf, solange Anwerben nicht geht.
var _recruit_reason_labels: Dictionary[String, Label] = {}
## Soldatentyp → Hinweis unter dem Knopf, woher die fehlende Waffe kommt.
var _recruit_supply_labels: Dictionary[String, Label] = {}
var _build_label: Label
var _build_panel: PanelContainer
var _build_bar: VBoxContainer
## Kategorie → Reiter der Bauleiste bzw. Zeile mit ihren Karten (nur die gewählte ist sichtbar).
var _category_tabs: Dictionary[String, Button] = {}
var _category_rows: Dictionary[String, HBoxContainer] = {}
## Gebäudetyp → Karte der Bauleiste und das Feld mit ihren Kosten.
var _build_buttons: Dictionary[String, Button] = {}
var _cost_labels: Dictionary[String, Label] = {}
var _demolish_button: Button
var _defeat_panel: PanelContainer
## Dunkelt hinter der Niederlage-Ansicht das Spiel ab und fängt Klicks ab.
var _defeat_dim: ColorRect
## Erreichter Tag und abgewehrte Wellen in der Niederlage-Ansicht.
var _defeat_day_label: Label


func _ready() -> void:
	var bar := _make_panel()
	# Über die ganze Breite: ohne Rundung, Rand nur unten.
	var bar_style: StyleBoxFlat = bar.get_theme_stylebox("panel")
	bar_style.set_corner_radius_all(0)
	bar_style.set_border_width_all(0)
	bar_style.border_width_bottom = 2
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
	_storage_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_storage_label)
	_residents_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_residents_label)
	_soldiers_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_soldiers_label)
	_popularity_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_popularity_label)
	_gold_label = _make_label("", TEXT_COLOR, 16)
	row.add_child(_gold_label)
	add_child(bar)

	# Meldungen eigen statt in der Titelleiste, damit sie bei langem Bestand nicht abgeschnitten werden.
	_message_panel = _make_panel()
	_message_label = _make_label("", TEXT_COLOR, 16)
	_message_panel.add_child(_message_label)
	add_child(_message_panel)
	_message_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_message_panel.offset_top = BUILD_HINT_TOP
	_message_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_message_panel.visible = false
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_panel.visible = false)
	add_child(_message_timer)

	_announcement_panel = _make_panel()
	_announcement_label = _make_label("", BLOCKED_COLOR, 18)
	_announcement_panel.add_child(_announcement_label)
	add_child(_announcement_panel)
	_announcement_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_announcement_panel.offset_top = BUILD_HINT_TOP
	_announcement_panel.visible = false

	var help_panel := _make_panel()
	help_panel.add_child(_make_label(
		"Linksklick: gründen/bauen/abreißen/Kaserne öffnen  ·  X: Abriss  ·  Rechtsklick/Esc: beenden\n"
		+ "Soldaten: Linksklick/-ziehen wählen, Rechtsklick schickt sie hin bzw. greift an  ·  Esc: Auswahl aufheben\n"
		+ "WASD/Pfeile, zwei Finger, Rechtsziehen: Kamera  ·  Pinch/Mausrad: zoomen\n"
		+ "Leertaste: Pause  ·  1/2/3: Tempo  ·  N: neue Karte\n"
		+ "V: Verwaltung  ·  M: Markt  ·  F5/F9: speichern/laden  ·  F: Vollbild",
		HINT_COLOR, 13))
	add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_info_panel = _make_panel()
	_info_label = _make_label("", TEXT_COLOR, 15)
	_info_panel.add_child(_info_label)
	add_child(_info_panel)
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.visible = false

	_build_panel = _make_panel()
	_build_label = _make_label("", TEXT_COLOR, 17)
	_build_panel.add_child(_build_label)
	add_child(_build_panel)
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, BUILD_HINT_TOP)
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.visible = false

	_build_bar = _make_build_bar()
	add_child(_build_bar)
	_build_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	_build_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_select_category(GameWorld.build_categories()[0])
	# Hinweise und Kachel-Info über der Bauleiste, die bei vielen Gebäuden fast die ganze Breite braucht.
	var above_bar := -(MARGIN + _build_bar.get_combined_minimum_size().y + MARGIN)
	help_panel.offset_bottom = above_bar
	_info_panel.offset_bottom = above_bar

	_admin_panel = _make_admin_panel()
	add_child(_admin_panel)
	_admin_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_admin_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_admin_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_admin_panel.visible = false

	_market_panel = _make_market_panel()
	add_child(_market_panel)
	_market_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_market_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_market_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_market_panel.visible = false

	_barracks_panel = _make_barracks_panel()
	add_child(_barracks_panel)
	_barracks_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_barracks_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_barracks_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_barracks_panel.visible = false

	# Zuletzt, damit sie über allen anderen Ansichten liegt.
	_defeat_dim = ColorRect.new()
	_defeat_dim.color = DEFEAT_DIM_COLOR
	_defeat_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_dim.visible = false
	add_child(_defeat_dim)
	_defeat_panel = _make_defeat_panel()
	add_child(_defeat_panel)
	_defeat_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_defeat_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_defeat_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_defeat_panel.visible = false


## Zeigt die Niederlage-Ansicht mit dem erreichten Tag und den abgewehrten Wellen; das Spiel
## dahinter wird abgedunkelt.
func show_defeat(day: int, repelled_waves: int) -> void:
	_defeat_day_label.text = "Erreicht: Tag %d\nAbgewehrte Wellen: %d" % [day, repelled_waves]
	_defeat_panel.visible = true
	_defeat_dim.visible = true
	_defeat_panel.reset_size()


func hide_defeat() -> void:
	_defeat_panel.visible = false
	_defeat_dim.visible = false


func is_defeat_shown() -> bool:
	return _defeat_panel.visible


func set_seed(map_seed: int) -> void:
	_seed_label.text = "Karte #%d" % map_seed


func show_day(day: int) -> void:
	_day_label.text = "Tag %d" % day


## Ankündigung in der Titelleiste: Seite (MapSide, leer = keine) und Countdown in Spielzeit
## (Minuten:Sekunden bei 1×, GameClock.TICKS_PER_SECOND), aufgerundet auf volle Sekunden.
func show_announcement(side: String, ticks: int) -> void:
	_announcement_panel.visible = side != ""
	if side == "":
		return
	var seconds := ceili(float(ticks) / GameClock.TICKS_PER_SECOND)
	var text := "Welle aus %s in %d:%02d" % [MapSide.name_of(side), seconds / 60, seconds % 60]
	if _announcement_label.text != text:
		_announcement_label.text = text
		_announcement_panel.reset_size()


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


## Belegung je Lagerart in der Titelleiste, z. B. „Warenlager 150/200 · Kornspeicher 40/100“.
func show_storage(text: String) -> void:
	_storage_label.text = text


## Bewohnerzahl, Wohnraum und Soldaten in der Titelleiste, z. B. „Bewohner 8/16 (Untätig 4)“
## und „Soldaten 2“.
func show_residents(total: int, housing: int, idle: int, soldiers: int) -> void:
	_residents_label.text = "Bewohner %d/%d (Untätig %d)" % [total, housing, idle]
	_soldiers_label.text = "Soldaten %d" % soldiers


## Beliebtheit und ihre Tendenz pro Tag in der Titelleiste, z. B. „Beliebtheit 54 ▲3“.
func show_popularity(popularity: int, trend: int) -> void:
	_popularity_label.text = "Beliebtheit %d %s" % [popularity, _trend_text(trend)]
	_popularity_label.add_theme_color_override("font_color",
			UP_COLOR if trend > 0 else (BLOCKED_COLOR if trend < 0 else TEXT_COLOR))


## Gold im Schatz in der Titelleiste, z. B. „Gold 120“.
func show_treasury(gold: int) -> void:
	_gold_label.text = "Gold %d" % gold


## Verwaltung öffnen bzw. schließen (Taste V); schließt die anderen Ansichten.
func toggle_administration() -> void:
	_admin_panel.visible = not _admin_panel.visible
	_market_panel.visible = false
	_barracks_panel.visible = false


func close_administration() -> void:
	_admin_panel.visible = false


func is_administration_open() -> bool:
	return _admin_panel.visible


## Marktansicht öffnen bzw. schließen (Taste M); schließt die anderen Ansichten.
func toggle_market() -> void:
	_market_panel.visible = not _market_panel.visible
	_admin_panel.visible = false
	_barracks_panel.visible = false


func close_market() -> void:
	_market_panel.visible = false


func is_market_open() -> bool:
	return _market_panel.visible


## Kasernenansicht öffnen (Linksklick auf eine Kaserne); schließt die anderen Ansichten.
func open_barracks() -> void:
	_barracks_panel.visible = true
	_admin_panel.visible = false
	_market_panel.visible = false


func close_barracks() -> void:
	_barracks_panel.visible = false


func is_barracks_open() -> bool:
	return _barracks_panel.visible


## Inhalt der Kasernenansicht: Untätige, Bestand je Waffe (Ware → Menge), Gold im Schatz und je
## Soldatentyp der Grund, warum Anwerben gerade nicht geht (leer = möglich). Gesperrte Knöpfe
## zeigen ihn rot darunter; fehlt dem Typ eine Waffe, steht darunter, woher sie kommt.
func show_barracks(idle: int, weapons: Dictionary[String, int], gold: int,
		errors: Dictionary[String, String]) -> void:
	var defs := GameDefs.get_instance()
	var parts: PackedStringArray = ["Untätige %d" % idle]
	for good: String in weapons:
		parts.append("%s %d" % [defs.goods[good]["name"], weapons[good]])
	parts.append("Gold %d" % gold)
	_barracks_stock_label.text = "  ·  ".join(parts)
	for type_id: String in _recruit_buttons:
		var reason := errors[type_id]
		_set_button_reason(_recruit_buttons[type_id], reason)
		_recruit_reason_labels[type_id].text = reason
		_recruit_reason_labels[type_id].visible = reason != ""
		var hints: PackedStringArray = []
		var cost := SoldierType.goods_cost_of(type_id)
		for good: String in cost:
			if weapons.get(good, 0) < cost[good]:
				hints.append("%s: %s" % [defs.goods[good]["name"], GameWorld.supply_hint(good)])
		_recruit_supply_labels[type_id].text = "\n".join(hints)
		_recruit_supply_labels[type_id].visible = not hints.is_empty()
	_barracks_panel.reset_size()


## Bestand je Ware in der Marktansicht.
func show_market_stock(stock: Dictionary[String, int]) -> void:
	for good: String in stock:
		_market_stock_labels[good].text = str(stock[good])


## Handelsknöpfe der Marktansicht: Grund je Ware für Kauf bzw. Verkauf (leer = möglich);
## gesperrte Knöpfe zeigen ihn als Hinweis. Ohne Markt steht oben market_error.
func show_trade_errors(market_error: String, buy_errors: Dictionary[String, String],
		sell_errors: Dictionary[String, String]) -> void:
	_market_missing_label.text = market_error
	_market_missing_label.visible = market_error != ""
	for good: String in _buy_buttons:
		_set_button_reason(_buy_buttons[good], buy_errors[good])
		_set_button_reason(_sell_buttons[good], sell_errors[good])
	_market_panel.reset_size()


func _set_button_reason(button: Button, reason: String) -> void:
	button.disabled = reason != ""
	button.tooltip_text = reason


## Inhalt der Verwaltung: eingestellte Ration, die tatsächlich gegessene (leer = dieselbe),
## der Steuersatz und die Faktoren samt Summe.
func show_administration(ration: String, eaten_ration: String, tax_rate: String, factors: Array[Factor],
		total: int) -> void:
	_ration_label.text = ration
	_tax_rate_label.text = tax_rate
	_eaten_label.text = "Zu wenig Nahrung – gegessen wird: %s" % eaten_ration
	_eaten_label.visible = eaten_ration != ""
	var lines: PackedStringArray = []
	for factor in factors:
		lines.append("%s\t%s" % [factor.name(), _signed(factor.value)])
	_factors_label.text = "\n".join(lines)
	_factor_sum_label.text = "→ %s pro Tag" % _signed(total)
	_admin_panel.reset_size()


## Hinweis oben in der Mitte (leer = ausblenden); rot, wenn hier nicht gebaut werden darf.
func show_build_hint(text: String, allowed: bool) -> void:
	_build_label.text = text
	_build_label.add_theme_color_override("font_color", TEXT_COLOR if allowed else BLOCKED_COLOR)
	_build_panel.visible = text != ""
	_build_panel.reset_size()


## Bauleiste sperren (während der Gründung) oder freigeben; die Reiter bleiben bedienbar.
func set_build_bar_enabled(enabled: bool) -> void:
	for button: Button in _build_buttons.values():
		button.disabled = not enabled
		button.modulate.a = 1.0 if enabled else 0.55
	_demolish_button.disabled = not enabled
	_demolish_button.modulate.a = 1.0 if enabled else 0.55


## Je Gebäudetyp der Grund, warum seine Kosten gerade nicht reichen (leer = sie reichen); die
## Kosten der Karte stehen dann rot da und der Grund als Hinweis. Die Karte bleibt wählbar.
func show_build_costs(errors: Dictionary[String, String]) -> void:
	for type_id: String in _cost_labels:
		var reason: String = errors.get(type_id, "")
		_cost_labels[type_id].add_theme_color_override("font_color", BLOCKED_COLOR if reason != "" else HINT_COLOR)
		var def: Dictionary = GameDefs.get_instance().buildings[type_id]
		_build_buttons[type_id].tooltip_text = "%s [%s]%s" % [def["name"], def["hotkey"],
				"\n" + reason if reason != "" else ""]


## Hebt den Knopf des gewählten Werkzeugs hervor: Gebäudetyp im Baumodus (leer = keiner)
## oder das Abriss-Werkzeug.
## Wird ein Gebäude per Taste gewählt, wechselt die Bauleiste zu seiner Kategorie.
func show_tool(build_type: String, demolishing: bool) -> void:
	if build_type != "":
		_select_category(GameWorld.build_category_of(build_type))
	for button_type: String in _build_buttons:
		_build_buttons[button_type].set_pressed_no_signal(button_type == build_type)
	_demolish_button.set_pressed_no_signal(demolishing)


## Die Bauleiste: oben die Reiter der Kategorien, darunter im Feld die Karten der gewählten
## Kategorie (alle Zeilen gleich breit, damit die Leiste beim Wechseln nicht springt) und rechts,
## durch einen Strich getrennt, das Abriss-Werkzeug.
func _make_build_bar() -> VBoxContainer:
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	# Reiter etwas eingerückt, damit sie auf dem Feld zu sitzen scheinen.
	var tabs_margin := MarginContainer.new()
	tabs_margin.add_theme_constant_override("margin_left", 14)
	tabs_margin.add_child(tabs)
	# Über dem Feld gezeichnet, damit der gewählte Reiter dessen oberen Rand überdeckt.
	tabs_margin.z_index = 1
	bar.add_child(tabs_margin)
	var panel := PanelContainer.new()
	var panel_style := UiStyle.bar_style()
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	bar.add_child(panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	# Alle Zeilen übereinander; sichtbar ist nur die der gewählten Kategorie.
	var cards := MarginContainer.new()
	body.add_child(cards)
	var widest := 0
	for category in GameWorld.build_categories():
		var tab := Button.new()
		tab.text = GameWorld.build_category_name(category)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 18)
		UiStyle.apply_tab_style(tab)
		tab.tooltip_text = "Gebäude: %s" % tab.text
		tab.pressed.connect(func() -> void: _select_category(category))
		tabs.add_child(tab)
		_category_tabs[category] = tab
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CARD_SEPARATION)
		for type_id in GameWorld.buildable_types_in(category):
			var button := _make_build_button(type_id)
			row.add_child(button)
			_build_buttons[type_id] = button
		cards.add_child(row)
		_category_rows[category] = row
		widest = maxi(widest, GameWorld.buildable_types_in(category).size())
	cards.custom_minimum_size = Vector2(widest * CARD_SIZE.x + (widest - 1) * CARD_SEPARATION, CARD_SIZE.y)
	body.add_child(VSeparator.new())
	_demolish_button = _make_card("", "Abriss", "X", "Hälfte zurück")
	_demolish_button.tooltip_text = "Abriss [X]\nGibt die Hälfte der Kosten zurück"
	_demolish_button.pressed.connect(demolish_selected.emit)
	body.add_child(_demolish_button)
	return bar


## Zeigt die Karten dieser Kategorie und hebt ihren Reiter hervor.
func _select_category(category: String) -> void:
	for other: String in _category_rows:
		_category_rows[other].visible = other == category
		_category_tabs[other].set_pressed_no_signal(other == category)


## Karte eines Gebäudetyps; Gold aus dem Schatz steht in den Kosten zuletzt („20 Holz, 30 Gold“).
func _make_build_button(type_id: String) -> Button:
	var def: Dictionary = GameDefs.get_instance().buildings[type_id]
	var button := _make_card(type_id, str(def["name"]), str(def["hotkey"]),
			_cost_text(GameWorld.goods_cost_of(type_id), GameWorld.gold_cost_of(type_id)))
	button.tooltip_text = "%s [%s]" % [def["name"], def["hotkey"]]
	button.pressed.connect(func() -> void: build_selected.emit(type_id))
	return button


## Umschaltknopf als Karte: Symbol (type_id, leer = Abriss), Titel, unten die Kosten bzw. ein
## Hinweis und oben links die Taste. Das Kostenfeld merkt sich _cost_labels.
func _make_card(type_id: String, title: String, hotkey: String, cost: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	# Kein Tastaturfokus, sonst löst die Leertaste (Pause) den Knopf aus.
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = CARD_SIZE
	UiStyle.apply_card_style(button)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var icon := BuildingIcon.new(type_id)
	icon.custom_minimum_size = Vector2(0, CARD_ICON_HEIGHT)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(icon)
	var title_label := _make_label(title, TEXT_COLOR, 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	var cost_label := _make_label(cost, HINT_COLOR, 15)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cost_label)
	if type_id != "":
		_cost_labels[type_id] = cost_label
	var badge := PanelContainer.new()
	var badge_style := UiStyle.card_style(Color(0, 0, 0, 0.45), UiStyle.GOLD_COLOR.darkened(0.3))
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge_style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.position = Vector2(5, 5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_label := _make_label(hotkey, UiStyle.GOLD_COLOR, 14)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(key_label)
	button.add_child(badge)
	return button


## Kosten als Text, z. B. „20 Holz, 30 Gold“ (Gold zuletzt) oder „kostenlos“.
static func _cost_text(goods_cost: Dictionary[String, int], gold: int) -> String:
	var parts: PackedStringArray = []
	for good: String in goods_cost:
		parts.append("%d %s" % [goods_cost[good], GameDefs.get_instance().goods[good]["name"]])
	if gold > 0:
		parts.append("%d Gold" % gold)
	return ", ".join(parts) if not parts.is_empty() else "kostenlos"


## Die Verwaltung: Ration mit ◀ ▶ (Tasten −/+), Steuersatz mit ◀ ▶ (Tasten ,/.), darunter
## die Faktoren und ihre Summe.
func _make_admin_panel() -> PanelContainer:
	var panel := _make_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_make_label("Verwaltung", TEXT_COLOR, 20))
	_ration_label = _make_setting_row(column, "Ration", "(−/+)", ration_step)
	_eaten_label = _make_label("", BLOCKED_COLOR, 15)
	column.add_child(_eaten_label)
	_tax_rate_label = _make_setting_row(column, "Steuersatz", "(,/.)", tax_rate_step)
	column.add_child(_make_label("Beliebtheit pro Tag", HINT_COLOR, 15))
	_factors_label = _make_label("", TEXT_COLOR, 16)
	_factors_label.tab_stops = PackedFloat32Array([140])
	column.add_child(_factors_label)
	_factor_sum_label = _make_label("", TEXT_COLOR, 16)
	column.add_child(_factor_sum_label)
	column.add_child(_make_label("V/Esc: schließen", HINT_COLOR, 13))
	return panel


## Die Marktansicht: je Ware eine Zeile mit Name, Bestand, Kauf- und Verkaufspreis und den
## Handelsknöpfen, die den Befehl „Handel“ auslösen.
func _make_market_panel() -> PanelContainer:
	var defs := GameDefs.get_instance()
	var panel := _make_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_make_label("Markt", TEXT_COLOR, 20))
	_market_missing_label = _make_label("", BLOCKED_COLOR, 15)
	column.add_child(_market_missing_label)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for title: String in ["Ware", "Bestand", "Kauf", "Verkauf", "", ""]:
		var header := _make_label(title, HINT_COLOR, 14)
		if title in ["Bestand", "Kauf", "Verkauf"]:
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(header)
	for good: String in defs.goods:
		grid.add_child(_make_label(str(defs.goods[good]["name"]), TEXT_COLOR, 16))
		var stock_label := _make_number_label("0")
		grid.add_child(stock_label)
		_market_stock_labels[good] = stock_label
		var tradable := Market.is_tradable(good)
		grid.add_child(_make_number_label(str(Market.buy_price(good)) if tradable else "–"))
		grid.add_child(_make_number_label(str(Market.sell_price(good)) if tradable else "–"))
		var buy_button := _make_trade_button("Kaufen %d" % Market.trade_amount(), good, true, tradable)
		var sell_button := _make_trade_button("Verkaufen %d" % Market.trade_amount(), good, false, tradable)
		grid.add_child(buy_button)
		grid.add_child(sell_button)
		if tradable:
			_buy_buttons[good] = buy_button
			_sell_buttons[good] = sell_button
	column.add_child(_make_label("Preise in Gold pro Einheit  ·  M/Esc: schließen", HINT_COLOR, 13))
	return panel


## Die Kasernenansicht: Untätige, Waffen und Gold, darunter je Soldatentyp eine Spalte mit
## einem Knopf samt Anwerbekosten, der den Befehl „Anwerben“ auslöst, und darunter dem Grund,
## warum er gesperrt ist, und woher eine fehlende Waffe kommt.
func _make_barracks_panel() -> PanelContainer:
	var panel := _make_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_make_label("Kaserne", TEXT_COLOR, 20))
	_barracks_stock_label = _make_label("", TEXT_COLOR, 16)
	column.add_child(_barracks_stock_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for type_id in SoldierType.ids():
		var type_column := VBoxContainer.new()
		type_column.add_theme_constant_override("separation", 4)
		type_column.custom_minimum_size = Vector2(RECRUIT_COLUMN_WIDTH, 0)
		row.add_child(type_column)
		var button := Button.new()
		button.text = "%s anwerben\nKosten: %s" % [FighterType.name_of(type_id),
				_cost_text(SoldierType.goods_cost_of(type_id), SoldierType.gold_cost_of(type_id))]
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func() -> void: recruit_requested.emit(type_id))
		type_column.add_child(button)
		_recruit_buttons[type_id] = button
		_recruit_reason_labels[type_id] = _make_wrapped_label(type_column, BLOCKED_COLOR, 14)
		_recruit_supply_labels[type_id] = _make_wrapped_label(type_column, HINT_COLOR, 13)
	column.add_child(_make_label("Esc: schließen", HINT_COLOR, 13))
	return panel


## Die Niederlage-Ansicht: Überschrift, erreichter Tag und die Knöpfe „Neue Partie“ und „Beenden“.
func _make_defeat_panel() -> PanelContainer:
	var panel := _make_panel()
	panel.custom_minimum_size = Vector2(460, 200)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var title := _make_label("Der Bergfried ist gefallen", BLOCKED_COLOR, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_defeat_day_label = _make_label("", TEXT_COLOR, 18)
	_defeat_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_defeat_day_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for entry: Array in [["Neue Partie", new_game_requested], ["Beenden", quit_requested]]:
		var button := Button.new()
		button.text = str(entry[0])
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(140, 0)
		var pressed: Signal = entry[1]
		button.pressed.connect(func() -> void: pressed.emit())
		row.add_child(button)
	return panel


## Rechtsbündige Zahl in der Marktansicht.
func _make_number_label(text: String) -> Label:
	var label := _make_label(text, TEXT_COLOR, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


## Handelsknopf, gesperrt bis show_trade_errors(); bei nicht handelbaren Waren unsichtbar (hält
## aber die Spalte).
func _make_trade_button(text: String, good: String, buying: bool, tradable: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	button.pressed.connect(func() -> void: trade_requested.emit(good, buying))
	button.add_theme_font_size_override("font_size", 14)
	if not tradable:
		button.modulate = Color.TRANSPARENT
	return button


## Eine Zeile der Verwaltung: Name, ◀ Wert ▶ und Tastenhinweis; die Pfeile senden step
## mit −1 bzw. +1. Liefert das Feld für den Wert.
func _make_setting_row(column: VBoxContainer, title: String, keys: String, step: Signal) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title_label := _make_label(title, TEXT_COLOR, 16)
	title_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(title_label)
	row.add_child(_make_step_button("◀", step, -1))
	var value_label := _make_label("", TEXT_COLOR, 16)
	value_label.custom_minimum_size = Vector2(90, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	row.add_child(_make_step_button("▶", step, 1))
	row.add_child(_make_label(keys, HINT_COLOR, 13))
	column.add_child(row)
	return value_label


func _make_step_button(text: String, step: Signal, delta: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: step.emit(delta))
	return button


## Tendenz als Pfeil, z. B. „▲3“, „▼2“ oder „±0“.
static func _trend_text(trend: int) -> String:
	if trend > 0:
		return "▲%d" % trend
	if trend < 0:
		return "▼%d" % -trend
	return "±0"


## Zahl mit Vorzeichen, z. B. „+4“, „−8“, „0“.
static func _signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	if value < 0:
		return "−%d" % -value
	return "0"


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	return panel


## Leeres, umbrechendes Textfeld so breit wie eine Spalte der Kasernenansicht, zunächst
## ausgeblendet. Die feste Breite braucht es, damit die Höhe beim Umbruch stimmt.
func _make_wrapped_label(parent: Container, color: Color, font_size: int) -> Label:
	var label := _make_label("", color, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(RECRUIT_COLUMN_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	parent.add_child(label)
	return label


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
