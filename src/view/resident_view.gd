class_name ResidentView
extends FigureView
## Zeichnet einen Bewohner (Figur, Ring und Lebensbalken: FigureView). Getragene Ware als Bündel
## auf dem Rücken, beim Abbau wippt er, in der Arbeitsstätte ist er unsichtbar.
## Soldaten tragen die Farbe ihres Soldatentyps (units.json) und ihre Waffe (Schwert bzw. Bogen).

## Wippen beim Abbau: Höhe in Pixeln und Schläge pro Sekunde (Spielzeit, nur Optik).
const BOB_HEIGHT := 2.5
const BOB_RATE := 2.0
## Klinge des Schwerts.
const BLADE_COLOR := Color("#d8dee6")
## Bogen und Schwertgriff.
const WOOD_COLOR := Color("#6b4423")

var _resident: Resident


func setup(figure: Figure, clock: GameClock) -> void:
	_resident = figure as Resident
	super.setup(figure, clock)


func _update_position() -> void:
	super._update_position()
	visible = not _resident.is_inside_building()


func _bob() -> float:
	if _resident.task != Resident.Task.MINING:
		return 0.0
	return BOB_HEIGHT * absf(sin((_clock.world.get_tick() + _clock.tick_fraction()) / float(GameClock.TICKS_PER_SECOND) * BOB_RATE * PI))


## Kittel in der Farbe des Soldatentyps, sonst in der des Bewohners. Jedes Mal neu gelesen:
## Ein Untätiger kann jederzeit Soldat werden.
func _body_color() -> Color:
	if _resident.is_soldier():
		return FighterType.color_of(_resident.soldier_type)
	return Color(str(GameDefs.get_instance().units["resident"]["color"]))


func _draw_extras() -> void:
	if _resident.carried_amount > 0:
		_draw_bundle(Color(str(GameDefs.get_instance().goods[_resident.carried_good]["color"])))
	if _resident.is_soldier() and not _sprite_entry().has("sprite"):
		_draw_weapon()


## Waffe neben dem Körper: Nahkämpfer mit erhobener Klinge, Fernkämpfer mit Bogen.
func _draw_weapon() -> void:
	if FighterType.is_melee(_resident.soldier_type):
		draw_line(Vector2(6, -8), Vector2(6, -24), BLADE_COLOR, 2.0)
		draw_line(Vector2(3, -11), Vector2(9, -11), WOOD_COLOR, 2.0)
	else:
		draw_arc(Vector2(3, -14), 9.0, -PI / 2.0 + 0.3, PI / 2.0 - 0.3, 10, WOOD_COLOR, 1.5, true)
		draw_line(Vector2(5.8, -22), Vector2(5.8, -6), OUTLINE_COLOR, 1.0)


## Bündel der getragenen Ware auf dem Rücken, über die Schulter ragend.
func _draw_bundle(color: Color) -> void:
	var bundle := Rect2(-8, -25, 9, 9)
	draw_rect(bundle, color)
	draw_rect(bundle, OUTLINE_COLOR, false, 1.0)
	draw_line(Vector2(-8, -20.5), Vector2(1, -20.5), OUTLINE_COLOR, 1.0)


func _sprite_entry() -> Dictionary:
	var type := _resident.soldier_type if _resident.is_soldier() else "resident"
	return GameDefs.get_instance().units[type]
