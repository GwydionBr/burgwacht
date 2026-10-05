class_name BuildingView
extends Node2D
## Zeichnet ein Gebäude als isometrischen Block über seiner Grundfläche: Farbe und Höhe
## aus den Daten, Name als Beschriftung, Eingang als dunkle Tür. Liegt im y-sortierten
## Objekt-Container. Der Sortierpunkt liegt zwischen den Kacheln hinter dem Gebäude und
## denen vor seinen beiden sichtbaren Wänden, damit Vorkommen davor und dahinter richtig
## erscheinen (exakt für quadratische Grundflächen). Das Lagerfeuer ist kein Block, sondern
## ein Steinkreis mit Flamme (Platzhalter). Gebäude mit "decor": "trees" (Apfelplantage)
## tragen auf jeder Kachel ein kleines Obstbäumchen, mit "decor": "wheat" (Weizenfarm)
## einige Ähren. Gebäude mit Wehrgang (Mauer) stehen ohne Abstand zum Nachbarn, damit eine
## Mauerlinie geschlossen wirkt; Gebäude mit einer Kachel (Mauer, Tor, Treppe) tragen keinen Namen.
## Ist ein Gebäude mit Wehrgang höher als der Wehrgang (Turm), endet der Block auf Höhe des
## Wehrgangs, und an den Ecken ragen Türmchen bis zur vollen Höhe auf. Ein begehbares Gebäude mit
## Wehrgang (Tor) zeigt auf beiden sichtbaren Wänden einen dunklen Durchgang. Ein beschädigtes
## Gebäude trägt über dem Dach einen Lebensbalken wie die Kämpfer (FigureView); nach einem Treffer
## ruft main update_health() auf.

const INSET := 3.0
const DOOR_COLOR := Color("#2a1d12")
const OUTLINE_COLOR := Color(0, 0, 0, 0.35)
const LABEL_COLOR := Color("#f4ead2")
const LABEL_SIZE := 13
const DOOR_HEIGHT := 18.0
## Anteil der Kachel, den ein Ecktürmchen eines Turms einnimmt.
const TURRET_SIZE := 0.4
const LOG_COLOR := Color("#5b3d24")
const FIRE_STONE_COLOR := Color("#77736b")
const FLAME_OUTER_COLOR := Color("#e0702a")
const FLAME_INNER_COLOR := Color("#ffd166")
const CROWN_COLOR := Color("#3f6b2a")
const FRUIT_COLOR := Color("#c0392b")
const STALK_COLOR := Color("#a8862c")
const EAR_COLOR := Color("#ecd27a")
## Lebensbalken über dem Dach, relativ zu dessen Mitte (über dem Namen).
const HEALTH_RECT := Rect2(-20, -20, 40, 5)

var _building: Building
var _type: String
var _origin: Vector2i
var _campfire := false
var _walkway := false
## Begehbar mit Wehrgang (Tor): Durchgang auf beiden Wänden.
var _passage := false
## Umriss des Blocks (Welt) und sein umschließendes Rechteck, für covers_figure().
var _outline := PackedVector2Array()
var _bounds := Rect2()


func setup(building: Building) -> void:
	_building = building
	_type = building.type
	_origin = building.origin
	_campfire = building.is_campfire()
	_walkway = building.has_walkway()
	_passage = _walkway and building.is_walkable()
	var size := Building.size_of(_type)
	position = Iso.tile_to_world(_origin + Vector2i(mini(size.x, size.y) - 1, 0))
	_outline = PackedVector2Array() if _campfire else _block_outline()
	_bounds = Rect2(position, Vector2.ZERO)
	for corner in _outline:
		_bounds = _bounds.expand(corner)
	queue_redraw()


## Die Lebenspunkte haben sich geändert: Balken neu zeichnen.
func update_health() -> void:
	queue_redraw()


## Verdeckt der Block eine Figur mit der Fläche rect (Welt), deren Fußpunkt auf Höhe foot_y
## liegt? Nur, wenn er nach ihr gezeichnet wird (Sortierpunkt tiefer) und sein Umriss die
## Fläche schneidet. Das Lagerfeuer verdeckt nichts.
func covers_figure(rect: Rect2, foot_y: float) -> bool:
	if _outline.is_empty() or position.y <= foot_y or not _bounds.intersects(rect):
		return false
	var area := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	return not Geometry2D.intersect_polygons(_outline, area).is_empty()


## Umriss des Blocks in Weltkoordinaten: Dach oben, links und rechts, Wände unten.
func _block_outline() -> PackedVector2Array:
	var base := footprint_corners(_type, _origin, Vector2.ZERO, 0.0 if _walkway else INSET)
	var height := float(GameDefs.get_instance().buildings[_type]["height"])
	var roof := block_faces(base, height)[2]
	return PackedVector2Array([roof[0], roof[1], base[1], base[2], base[3], roof[3]])


func _draw() -> void:
	if _campfire:
		_draw_campfire()
		return
	var def: Dictionary = GameDefs.get_instance().buildings[_type]
	var color := Color(str(def["color"]))
	var base := footprint_corners(_type, _origin, position, 0.0 if _walkway else INSET)
	var height := float(def["height"])
	# Der Block eines Turms endet auf dem Wehrgang; darüber ragen nur die Ecktürmchen.
	var block_height := minf(height, FigureView.wall_walk_height()) if _walkway else height
	var faces := _draw_block(base, block_height, color)
	_draw_entrance(base)
	if _passage:
		_draw_passage(base)
	if height > block_height:
		_draw_turrets(height - block_height, block_height, color)
	match str(def.get("decor", "")):
		"trees":
			_draw_small_trees(float(def["height"]))
		"wheat":
			_draw_wheat(float(def["height"]))
	if Building.size_of(_type) != Vector2i.ONE:
		_draw_label(str(def["name"]), (faces[2][0] + faces[2][2]) * 0.5)
	var top := block_faces(base, height)[2]
	_draw_health((top[0] + top[2]) * 0.5)


## Lebensbalken über center (Mitte des Dachs), nur wenn das Gebäude beschädigt ist: grün bei
## viel, rot bei wenig Rest, wie bei den Kämpfern.
func _draw_health(center: Vector2) -> void:
	if not _building.is_destructible() or not _building.is_damaged():
		return
	var share := clampf(float(_building.hp) / _building.max_hp(), 0.0, 1.0)
	var rect := Rect2(center + HEALTH_RECT.position, HEALTH_RECT.size)
	draw_rect(rect.grow(1.0), FigureView.HEALTH_BACK_COLOR)
	var filled := Rect2(rect.position, Vector2(rect.size.x * share, rect.size.y))
	draw_rect(filled, FigureView.HEALTH_LOW_COLOR.lerp(FigureView.HEALTH_HIGH_COLOR, share))


## Zeichnet einen Block über den Ecken base mit Wänden, Dach und Umriss; liefert seine Flächen.
func _draw_block(base: PackedVector2Array, height: float, color: Color) -> Array[PackedVector2Array]:
	var faces := block_faces(base, height)
	draw_colored_polygon(faces[0], color.darkened(0.15))
	draw_colored_polygon(faces[1], color.darkened(0.32))
	draw_colored_polygon(faces[2], color.lightened(0.08))
	_draw_outline(faces)
	return faces


func _draw_outline(faces: Array[PackedVector2Array]) -> void:
	for face: PackedVector2Array in faces:
		var outline := face.duplicate()
		outline.append(face[0])
		draw_polyline(outline, OUTLINE_COLOR, 1.0, true)


## Ein Türmchen auf jeder Ecke des Dachs (Höhe floor), height hoch; hinten zuerst.
func _draw_turrets(height: float, floor_height: float, color: Color) -> void:
	var size := Vector2(Building.size_of(_type))
	var start := Vector2(_origin) - Vector2(0.5, 0.5)
	var far := size - Vector2(TURRET_SIZE, TURRET_SIZE)
	# Ecken in Kachelkoordinaten: oben, rechts, links, unten (von hinten nach vorn).
	for corner: Vector2 in [Vector2.ZERO, Vector2(far.x, 0), Vector2(0, far.y), far]:
		var low := start + corner
		var high := low + Vector2(TURRET_SIZE, TURRET_SIZE)
		var base := PackedVector2Array()
		for point: Vector2 in [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]:
			base.append(Iso.point_to_world(point) - position + Vector2(0, -floor_height))
		_draw_block(base, height, color.lightened(0.04))


## Dunkler Durchgang unten in beiden sichtbaren Wänden (Tor).
func _draw_passage(base: PackedVector2Array) -> void:
	var up := Vector2(0, -DOOR_HEIGHT)
	# Linke Wand (base[3] → base[2]) und rechte Wand (base[2] → base[1]).
	for i: int in [3, 2]:
		var a := base[i].lerp(base[i - 1], 0.25)
		var b := base[i].lerp(base[i - 1], 0.75)
		draw_colored_polygon(PackedVector2Array([a, b, b + up * 0.8, (a + b) * 0.5 + up, a + up * 0.8]), DOOR_COLOR)


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
	var last := Building.last_tile_of(type_id, origin)
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


## Ein kleines Obstbäumchen mitten auf jeder Kachel der Grundfläche, hinten zuerst.
func _draw_small_trees(height: float) -> void:
	for foot in _decor_spots(height):
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2(3, 0), 7.0, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(foot + Vector2(-1.5, -7), Vector2(3, 7)), LOG_COLOR)
		draw_circle(foot + Vector2(0, -12), 7.0, CROWN_COLOR)
		draw_circle(foot + Vector2(-2, -14), 3.5, CROWN_COLOR.lightened(0.15))
		for spot: Vector2 in [Vector2(-3, -10), Vector2(3, -13), Vector2(1, -8)]:
			draw_circle(foot + spot, 1.6, FRUIT_COLOR)


## Eingang als dunkle Tür auf der vorderen Seite, an der er liegt.
func _draw_entrance(base: PackedVector2Array) -> void:
	if not Building.has_entrance_type(_type):
		return
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
	var up := Vector2(0, -DOOR_HEIGHT)
	draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), DOOR_COLOR)


func _draw_label(text: String, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var pos := center + Vector2(-width * 0.5, LABEL_SIZE * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 3, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)


## Drei Ähren mitten auf jeder Kachel der Grundfläche, hinten zuerst.
func _draw_wheat(height: float) -> void:
	for foot in _decor_spots(height):
		for x: float in [-6.0, 0.0, 6.0]:
			var base := foot + Vector2(x, absf(x) * 0.3)
			var tip := base + Vector2(x * 0.2, -10)
			draw_line(base, tip, STALK_COLOR, 1.2)
			draw_set_transform(tip + Vector2(0, -2), 0.0, Vector2(0.45, 1.0))
			draw_circle(Vector2.ZERO, 3.2, EAR_COLOR)
			draw_set_transform(Vector2.ZERO)


## Die Mitte jeder Kachel der Grundfläche auf dem Dach (Höhe height), hinten zuerst.
func _decor_spots(height: float) -> Array[Vector2]:
	var tiles := Building.footprint(_type, _origin)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	var spots: Array[Vector2] = []
	for tile in tiles:
		spots.append(Iso.tile_to_world(tile) - position + Vector2(0, -height))
	return spots
