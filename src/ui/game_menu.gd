class_name GameMenu
extends CanvasLayer
## Das Spielmenü (Esc während der Partie): ein MenuPanel über einer Abdunkelung, die alle
## Klicks auf Karte und HUD abfängt. Zeigt Szenario und Seed der Partie; die Einträge setzt die
## Partie-Szene mit add_entry() (Speichern, Laden, Einstellungen kommen so dazu).
## Ob die Zeit steht und Tasten wirken, regelt main.gd beim Öffnen und Schließen.

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.45)

var _dim: ColorRect
var _panel: MenuPanel


func _init() -> void:
	layer = 2
	visible = false
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = MenuPanel.new("Spielmenü")
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


## Hängt einen Eintrag an (siehe MenuPanel.add_entry()); der Knopf kommt zurück.
func add_entry(text: String, action: Callable) -> Button:
	return _panel.add_entry(text, action)


## Öffnet das Menü mit Szenario und Seed der Partie.
func open(scenario_title: String, map_seed: int) -> void:
	_panel.set_subtitle("%s · Seed %d" % [scenario_title, map_seed])
	visible = true
	_panel.reset_size()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible
