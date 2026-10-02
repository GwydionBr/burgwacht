class_name BuildingView
extends Node2D
## Zeichnet ein Gebäude als isometrischen Block über seiner Grundfläche: Farbe und Höhe
## aus den Daten, Name als Beschriftung, Eingang als dunkles Tor. Liegt im y-sortierten
## Objekt-Container; der Ankerpunkt ist die vorderste Kachel, damit Vorkommen davor
## und dahinter richtig erscheinen.

const INSET := 3.0
const GATE_COLOR := Color("#2a1d12")
const OUTLINE_COLOR := Color(0, 0, 0, 0.35)
const LABEL_COLOR := Color("#f4ead2")
const LABEL_SIZE := 13
const GATE_HEIGHT := 18.0

var _type: String
var _origin: Vector2i


func setup(building: Building) -> void:
	_type = building.type
	_origin = building.origin
	position = Iso.tile_to_world(_origin + Building.size_of(_type) - Vector2i.ONE)
	queue_redraw()


func _draw() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings[_type]
	var color := Color(str(def["color"]))
	var lift := Vector2(0, -float(def["height"]))
	var base := footprint_corners(_type, _origin, position, INSET)
	var roof := PackedVector2Array()
	for corner in base:
		roof.append(corner + lift)
	# Sichtbar sind die beiden vorderen Seiten (links: Rand mit größtem y, rechts: mit größtem x).
	var left_face := PackedVector2Array([base[3], base[2], roof[2], roof[3]])
	var right_face := PackedVector2Array([base[2], base[1], roof[1], roof[2]])
	draw_colored_polygon(left_face, color.darkened(0.15))
	draw_colored_polygon(right_face, color.darkened(0.32))
	draw_colored_polygon(roof, color.lightened(0.08))
	_draw_gate(base)
	for face in [left_face, right_face, roof]:
		var outline: PackedVector2Array = face.duplicate()
		outline.append(face[0])
		draw_polyline(outline, OUTLINE_COLOR, 1.0, true)
	_draw_label(str(def["name"]), (roof[0] + roof[2]) * 0.5)


## Ecken der Grundfläche (oben, rechts, unten, links) relativ zu anchor, um inset eingerückt.
static func footprint_corners(type_id: String, origin: Vector2i, anchor: Vector2, inset: float) -> PackedVector2Array:
	var last := origin + Building.size_of(type_id) - Vector2i.ONE
	var corners := PackedVector2Array([
		Iso.tile_polygon(origin)[0],
		Iso.tile_polygon(Vector2i(last.x, origin.y))[1],
		Iso.tile_polygon(last)[2],
		Iso.tile_polygon(Vector2i(origin.x, last.y))[3],
	])
	var center := (corners[0] + corners[2]) * 0.5
	for i in corners.size():
		corners[i] = corners[i] - anchor + (center - corners[i]).normalized() * inset
	return corners


## Tor auf der vorderen Seite, an der der Eingang liegt.
func _draw_gate(base: PackedVector2Array) -> void:
	var size := Building.size_of(_type)
	var entrance := Building.entrance_of(_type, _origin) - _origin
	var from: Vector2
	var to: Vector2
	var steps: int
	var index: int
	if entrance.y == size.y - 1:
		from = base[3]
		to = base[2]
		steps = size.x
		index = entrance.x
	elif entrance.x == size.x - 1:
		from = base[2]
		to = base[1]
		steps = size.y
		index = size.y - 1 - entrance.y
	else:
		return
	var a := from.lerp(to, (index + 0.25) / steps)
	var b := from.lerp(to, (index + 0.75) / steps)
	var up := Vector2(0, -GATE_HEIGHT)
	draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), GATE_COLOR)


func _draw_label(text: String, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var pos := center + Vector2(-width * 0.5, LABEL_SIZE * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 3, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)
