class_name StatIcon
extends Control
## Kleines gezeichnetes Symbol für einen Wert der Titelleiste: Sonne (Tag), Figur (Bewohner),
## Schild (Soldaten), Herz (Beliebtheit) oder Münze (Gold).

const DAY := "day"
const RESIDENTS := "residents"
const SOLDIERS := "soldiers"
const POPULARITY := "popularity"
const GOLD := "gold"
const SIZE := Vector2(28, 28)
const OUTLINE_COLOR := Color(0, 0, 0, 0.5)
const SUN_COLOR := Color("#f2c14e")
const PERSON_COLOR := Color("#d9c8a0")
const SHIELD_COLOR := Color("#7d8a99")
const HEART_COLOR := Color("#d8553c")

var _kind: String


func _init(kind: String) -> void:
	_kind = kind
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	match _kind:
		DAY:
			for i in 8:
				var direction := Vector2.from_angle(i * TAU / 8.0)
				draw_line(center + direction * r * 0.62, center + direction * r * 0.95, SUN_COLOR, 2.0, true)
			draw_circle(center, r * 0.45, SUN_COLOR)
			draw_arc(center, r * 0.45, 0.0, TAU, 24, SUN_COLOR.darkened(0.35), 1.5, true)
		RESIDENTS:
			draw_circle(center + Vector2(0, -r * 0.42), r * 0.28, PERSON_COLOR)
			_draw_outlined(PackedVector2Array([
				center + Vector2(-r * 0.62, r * 0.9), center + Vector2(-r * 0.45, -r * 0.02),
				center + Vector2(r * 0.45, -r * 0.02), center + Vector2(r * 0.62, r * 0.9),
			]), PERSON_COLOR.darkened(0.15))
		SOLDIERS:
			var shield := PackedVector2Array([
				center + Vector2(-r * 0.75, -r * 0.8), center + Vector2(r * 0.75, -r * 0.8),
				center + Vector2(r * 0.7, r * 0.05), center + Vector2(0, r * 0.95),
				center + Vector2(-r * 0.7, r * 0.05),
			])
			_draw_outlined(shield, SHIELD_COLOR)
			draw_line(center + Vector2(0, -r * 0.6), center + Vector2(0, r * 0.65), UiStyle.GOLD_COLOR, 2.5, true)
			draw_line(center + Vector2(-r * 0.5, -r * 0.2), center + Vector2(r * 0.5, -r * 0.2),
					UiStyle.GOLD_COLOR, 2.5, true)
		POPULARITY:
			var heart := PackedVector2Array()
			# Herzkurve, auf die Fläche eingepasst.
			for i in 32:
				var t := i * TAU / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				heart.append(center + Vector2(x, y + 1.5) * r / 17.0)
			_draw_outlined(heart, HEART_COLOR)
		GOLD:
			draw_circle(center, r * 0.85, UiStyle.GOLD_COLOR.darkened(0.25))
			draw_circle(center, r * 0.68, UiStyle.GOLD_COLOR)
			draw_arc(center, r * 0.85, 0.0, TAU, 32, OUTLINE_COLOR, 1.5, true)
			draw_arc(center, r * 0.45, PI * 0.9, PI * 1.6, 12, UiStyle.GOLD_COLOR.lightened(0.45), 2.0, true)


func _draw_outlined(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUTLINE_COLOR, 1.5, true)
