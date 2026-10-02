class_name BuildingView
extends Node2D
## Zeichnet ein Gebäude als isometrischen Block über seiner Grundfläche: Farbe und Höhe
## aus den Daten, Name als Beschriftung, Eingang als dunkles Tor. Liegt im y-sortierten
## Objekt-Container. Der Sortierpunkt liegt zwischen den Kacheln hinter dem Gebäude und
## denen vor seinen beiden sichtbaren Wänden, damit Vorkommen davor und dahinter richtig
## erscheinen (exakt für quadratische Grundflächen). Das Lagerfeuer ist kein Block, sondern
## ein Steinkreis mit Flamme (Platzhalter).

const INSET := 3.0
const GATE_COLOR := Color("#2a1d12")
const OUTLINE_COLOR := Color(0, 0, 0, 0.35)
const LABEL_COLOR := Color("#f4ead2")
const LABEL_SIZE := 13
const GATE_HEIGHT := 18.0
const LOG_COLOR := Color("#5b3d24")
const FIRE_STONE_COLOR := Color("#77736b")
const FLAME_OUTER_COLOR := Color("#e0702a")
const FLAME_INNER_COLOR := Color("#ffd166")

var _type: String
var _origin: Vector2i


func setup(building: Building) -> void:
	_type = building.type
	_origin = building.origin
	var size := Building.size_of(_type)
	position = Iso.tile_to_world(_origin + Vector2i(mini(size.x, size.y) - 1, 0))
	queue_redraw()


func _draw() -> void:
	var def: Dictionary = GameDefs.get_instance().buildings[_type]
	if def["behavior"] == "campfire":
		_draw_campfire()
		return
	var color := Color(str(def["color"]))
	var base := footprint_corners(_type, _origin, position, INSET)
	var faces := block_faces(base, float(def["height"]))
	draw_colored_polygon(faces[0], color.darkened(0.15))
	draw_colored_polygon(faces[1], color.darkened(0.32))
	draw_colored_polygon(faces[2], color.lightened(0.08))
	_draw_gate(base)
	for face: PackedVector2Array in faces:
		var outline := face.duplicate()
		outline.append(face[0])
		draw_polyline(outline, OUTLINE_COLOR, 1.0, true)
	_draw_label(str(def["name"]), (faces[2][0] + faces[2][2]) * 0.5)


## Die sichtbaren Flächen eines Blocks über den Ecken base (aus footprint_corners()):
## linke Wand (Rand mit größtem y), rechte Wand (Rand mit größtem x), Dach.
static func block_faces(base: PackedVector2Array, height: float) -> Array[PackedVector2Array]:
	var roof := PackedVector2Array()
	for corner in base:
		roof.append(corner + Vector2(0, -height))
	return [
		PackedVector2Array([base[3], base[2], roof[2], roof[3]]),
		PackedVector2Array([base[2], base[1], roof[1], roof[2]]),
		roof,
	]


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


## Steinkreis mit Holzscheiten und Flamme, mittig auf der Kachel.
func _draw_campfire() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.25))
	for i in 9:
		var angle := TAU * i / 9.0
		draw_circle(Vector2(cos(angle), sin(angle)) * 12.0, 3.2, FIRE_STONE_COLOR)
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-8, 2), Vector2(8, -3), LOG_COLOR, 3.0)
	draw_line(Vector2(-8, -3), Vector2(8, 2), LOG_COLOR, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 0), Vector2(-4, -9), Vector2(-1, -6), Vector2(1, -16), Vector2(4, -7), Vector2(6, 0),
	]), FLAME_OUTER_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, 0), Vector2(-1, -6), Vector2(1, -10), Vector2(3, -4), Vector2(3, 0),
	]), FLAME_INNER_COLOR)


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
