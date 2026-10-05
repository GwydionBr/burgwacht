class_name GameMenu
extends CanvasLayer
## Das Spielmenü (Esc während der Partie): ein MenuPanel über einer Abdunkelung, die alle
## Klicks auf Karte und HUD abfängt. Zeigt Szenario und Seed der Partie; die Einträge setzt die
## Partie-Szene mit add_entry() (Speichern, Laden, Einstellungen kommen so dazu). Eine Ansicht
## wie Speichern oder Laden zeigt show_view() an Stelle des Menüs, close_view() kehrt zurück.
## Ob die Zeit steht und Tasten wirken, regelt main.gd beim Öffnen und Schließen.

var _panel: MenuPanel
## Die Ansicht an Stelle des Menüs (in einem CenterContainer), sonst null.
var _view_holder: CenterContainer


func _init() -> void:
	layer = 2
	visible = false
	MenuPanel.add_dim(self)
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
	close_view()
	visible = false


## Zeigt die Ansicht (z. B. SaveView, LoadView) mittig an Stelle des Menüs; eine vorige fliegt raus.
func show_view(view: Control) -> void:
	close_view()
	_view_holder = CenterContainer.new()
	_view_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view_holder)
	_view_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_holder.add_child(view)
	_panel.visible = false


## Schließt die Ansicht und zeigt wieder das Menü.
func close_view() -> void:
	if _view_holder != null:
		_view_holder.queue_free()
		_view_holder = null
	_panel.visible = true


## Die offene Ansicht, sonst null.
func get_view() -> Control:
	return null if _view_holder == null else _view_holder.get_child(0)


func is_open() -> bool:
	return visible
