class_name EnemyView
extends UnitView
## Zeichnet einen Feind (Figur und Lebensbalken: UnitView) in der Farbe seines Typs aus
## units.json, mit Kapuze und Knüppel.

const CLUB_COLOR := Color("#5a3a1e")
const HOOD_COLOR := Color(0.12, 0.08, 0.14, 0.85)

var _enemy: Enemy


func setup(unit: Unit, clock: GameClock) -> void:
	_enemy = unit as Enemy
	super.setup(unit, clock)


func _body_color() -> Color:
	return FighterType.color_of(_enemy.type)


func _draw_extras() -> void:
	# Kapuze über dem Kopf, Knüppel in der Hand.
	draw_arc(Vector2(0, -22), 4.5, PI, TAU, 10, HOOD_COLOR, 3.0, true)
	draw_line(Vector2(6, -8), Vector2(8, -21), CLUB_COLOR, 3.0)
	draw_circle(Vector2(8, -21), 2.2, CLUB_COLOR)
