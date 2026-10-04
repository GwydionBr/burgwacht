class_name EnemyView
extends FigureView
## Zeichnet einen Feind (Figur und Lebensbalken: FigureView) in der Farbe seines Typs aus
## units.json, mit Kapuze; Nahkämpfer (Räuber) mit Knüppel, Fernkämpfer (Wilderer) mit Bogen und
## Köcher.

const CLUB_COLOR := Color("#5a3a1e")
const HOOD_COLOR := Color(0.12, 0.08, 0.14, 0.85)
const QUIVER_COLOR := Color("#4a2f18")
const FLETCHING_COLOR := Color("#e8e0c8")

var _enemy: Enemy


func setup(figure: Figure, clock: GameClock) -> void:
	_enemy = figure as Enemy
	super.setup(figure, clock)


func _body_color() -> Color:
	return FighterType.color_of(_enemy.type)


func _draw_extras() -> void:
	# Kapuze über dem Kopf.
	draw_arc(Vector2(0, -22), 4.5, PI, TAU, 10, HOOD_COLOR, 3.0, true)
	if FighterType.is_melee(_enemy.type):
		# Knüppel in der Hand.
		draw_line(Vector2(6, -8), Vector2(8, -21), CLUB_COLOR, 3.0)
		draw_circle(Vector2(8, -21), 2.2, CLUB_COLOR)
		return
	# Köcher auf dem Rücken mit hellen Federn, Bogen in der Hand.
	draw_line(Vector2(-5, -10), Vector2(-8, -22), QUIVER_COLOR, 3.0)
	draw_line(Vector2(-8, -22), Vector2(-9, -25), FLETCHING_COLOR, 1.5)
	draw_line(Vector2(-7, -22), Vector2(-6, -25), FLETCHING_COLOR, 1.5)
	draw_arc(Vector2(3, -14), 9.0, -PI / 2.0 + 0.3, PI / 2.0 - 0.3, 10, CLUB_COLOR, 1.5, true)
	draw_line(Vector2(5.8, -22), Vector2(5.8, -6), OUTLINE_COLOR, 1.0)
