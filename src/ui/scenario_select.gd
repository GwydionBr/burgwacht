class_name ScenarioSelect
extends MenuView
## Die Szenarioauswahl für eine neue Partie, im Holz-Gold-Stil der Menüs: links die Szenarien
## der Spieldaten, rechts Beschreibung und Kartenwahl (zufällig oder eingetippter Seed; ein
## Szenario mit festem Seed zeigt ihn nur). „Starten“ meldet die fertige Startbeschreibung,
## „Zurück“ (auch Esc) die Rückkehr ins Hauptmenü. Ob ein Seed gilt, entscheidet MatchStart.

## „Starten“ mit gültiger Wahl: die Partie soll aus dieser Beschreibung beginnen.
signal start_requested(start: MatchStart)

const LIST_WIDTH := 280.0
const DETAILS_SIZE := Vector2(480, 330)
const SEED_FIELD_WIDTH := 190.0
const CHOICE_FONT_SIZE := 17

var _scenarios: Array[Scenario] = []
var _selected: Scenario
var _scenario_buttons: Array[Button] = []
var _title_label: Label
var _description_label: Label
var _random_button: Button
var _seed_button: Button
var _seed_field: LineEdit
var _fixed_seed_label: Label
var _choice_row: HBoxContainer
var _start_button: Button


## selected_id: das vorgewählte Szenario (nach der Niederlage das bisherige).
func _init(selected_id := Scenario.DEFAULT, dir := Scenario.DIR) -> void:
	super()
	for id in Scenario.list_ids(dir):
		_scenarios.append(Scenario.load_named(id, dir))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	column.add_child(MenuPanel.make_label("Neue Partie", UiStyle.GOLD_COLOR, 36))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)
	body.add_child(_make_list())
	body.add_child(_make_details())
	_start_button = MenuPanel.make_button("Starten", _start)
	column.add_child(_make_footer([_start_button]))
	var preselected := 0
	for i in _scenarios.size():
		if _scenarios[i].id == selected_id:
			preselected = i
	if not _scenarios.is_empty():
		_select(preselected)


## Das gewählte Szenario (für Tests und Screenshots).
func selected_id() -> String:
	return _selected.id if _selected != null else ""


func _make_list() -> Control:
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	list.add_theme_constant_override("separation", 8)
	list.add_child(_make_heading("Szenario"))
	var group := ButtonGroup.new()
	for i in _scenarios.size():
		var scenario := _scenarios[i]
		var button := MenuPanel.make_button(scenario.title if scenario.title != "" else scenario.id, _select.bind(i))
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(LIST_WIDTH, 44)
		button.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
		list.add_child(button)
		_scenario_buttons.append(button)
	if _scenarios.is_empty():
		list.add_child(MenuPanel.make_text("Keine Szenarien gefunden.", UiStyle.BLOCKED_COLOR, 16, true))
	return list


func _make_details() -> Control:
	var details := VBoxContainer.new()
	details.custom_minimum_size = DETAILS_SIZE
	details.add_theme_constant_override("separation", 10)
	_title_label = MenuPanel.make_text("", UiStyle.GOLD_COLOR, 24, true)
	details.add_child(_title_label)
	_description_label = MenuPanel.make_text("", UiStyle.TEXT_COLOR, 16, true)
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(_description_label)
	details.add_child(_make_heading("Karte"))
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 10)
	details.add_child(_choice_row)
	var group := ButtonGroup.new()
	_random_button = _make_choice("Zufällig", group, _choose_random)
	_seed_button = _make_choice("Seed", group, _choose_seed)
	_seed_field = _make_seed_field()
	_choice_row.add_child(_seed_field)
	_fixed_seed_label = MenuPanel.make_text("", UiStyle.TEXT_COLOR, CHOICE_FONT_SIZE, true)
	details.add_child(_fixed_seed_label)
	# Die Zeile für den Grund bleibt auch leer stehen, damit die Kartenwahl nicht springt.
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = true
	details.add_child(_error_label)
	return details


func _make_choice(text: String, group: ButtonGroup, action: Callable) -> Button:
	var button := MenuPanel.make_button(text, action)
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(120, 40)
	button.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	_choice_row.add_child(button)
	return button


func _make_seed_field() -> LineEdit:
	var field := MenuPanel.make_field(CHOICE_FONT_SIZE)
	field.custom_minimum_size = Vector2(SEED_FIELD_WIDTH, 40)
	field.placeholder_text = "z. B. 42"
	field.max_length = str(MatchStart.MAX_SEED).length() + 2
	field.text_changed.connect(func(_text: String) -> void: _choose_seed())
	field.text_submitted.connect(func(_text: String) -> void: _start())
	field.focus_entered.connect(func() -> void: _seed_button.button_pressed = true)
	return field


func _make_heading(text: String) -> Label:
	var label := MenuPanel.make_text(text, UiStyle.HINT_COLOR, 15, true)
	label.uppercase = true
	return label


func _select(index: int) -> void:
	_selected = _scenarios[index]
	_scenario_buttons[index].button_pressed = true
	_title_label.text = _scenario_buttons[index].text
	_description_label.text = _selected.description
	var valid := _selected.error == ""
	var chooses_map := valid and _selected.random_seed
	_choice_row.visible = chooses_map
	_fixed_seed_label.visible = valid and not _selected.random_seed
	_fixed_seed_label.text = "Feste Karte: Seed %d" % _selected.fixed_seed
	if chooses_map:
		_choose_random()
	_update_validity()


## Zufällige Karte: Das Seed-Feld wird geleert; Tippen darin wählt wieder „Seed“.
func _choose_random() -> void:
	_random_button.button_pressed = true
	_seed_field.text = ""
	_update_validity()


func _choose_seed() -> void:
	_seed_button.button_pressed = true
	if not _seed_field.has_focus() and is_inside_tree():
		_seed_field.grab_focus()
	_update_validity()


## Sperrt „Starten“ mit Grund, solange Szenario oder Seed nicht gehen.
func _update_validity() -> void:
	var reason := _selected.error if _selected != null else "Kein Szenario gewählt."
	if reason == "" and _seed_button.button_pressed and _choice_row.visible:
		reason = MatchStart.seed_error(_seed_field.text, true)
	_error_label.text = reason
	_start_button.disabled = reason != ""


func _start() -> void:
	_update_validity()
	if _start_button.disabled:
		return
	var seed_text := _seed_field.text if _seed_button.button_pressed and _choice_row.visible else ""
	start_requested.emit(MatchStart.from_seed_text(_selected.id, seed_text))
