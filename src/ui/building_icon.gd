class_name BuildingIcon
extends Control
## Symbol eines Gebäudetyps für die Bauleiste: ein kleiner isometrischer Block wie auf der
## Karte, mit Grundfläche, Höhe und Farbe aus den Daten, eingepasst in die eigene Fläche.
## Ohne Typ (leer) zeigt es das Abriss-Werkzeug: ein Trümmerblock mit rotem Kreuz.

## Größter Maßstab, damit Gebäude mit einer Kachel (Mauer, Treppe) nicht riesig werden.
const MAX_SCALE := 0.75
const OUTLINE_COLOR := Color(0, 0, 0, 0.45)
const RUBBLE_COLOR := Color("#7a7468")
const CROSS_COLOR := Color("#d8553c")
## Höhe des Trümmerblocks beim Abriss-Werkzeug.
const RUBBLE_HEIGHT := 14.0

var _type_id: String


func _init(type_id: String) -> void:
	_type_id = type_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var tiles := Vector2i(2, 2)
	var height := RUBBLE_HEIGHT
	var color := RUBBLE_COLOR
	if _type_id != "":
		var def: Dictionary = GameDefs.get_instance().buildings[_type_id]
		tiles = Building.size_of(_type_id)
		height = float(def["height"])
		color = Color(str(def["color"]))
	# Grundfläche in Weltkoordinaten (oben, rechts, unten, links) wie BuildingView.footprint_corners().
	var half := Vector2(Iso.TILE_W, Iso.TILE_H) * 0.5
	var base := PackedVector2Array([
		Vector2.ZERO,
		Vector2(tiles.x * half.x, tiles.x * half.y),
		Vector2((tiles.x - tiles.y) * half.x, (tiles.x + tiles.y) * half.y),
		Vector2(-tiles.y * half.x, tiles.y * half.y),
	])
	var faces := BuildingView.block_faces(base, height)
	var bounds := Rect2(base[0], Vector2.ZERO)
	for face: PackedVector2Array in faces:
		for point in face:
			bounds = bounds.expand(point)
	var scale_factor := minf(MAX_SCALE, minf(size.x / bounds.size.x, size.y / bounds.size.y))
	var offset := size * 0.5 - bounds.get_center() * scale_factor
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))
	draw_colored_polygon(faces[0], color.darkened(0.15))
	draw_colored_polygon(faces[1], color.darkened(0.32))
	draw_colored_polygon(faces[2], color.lightened(0.08))
	for face: PackedVector2Array in faces:
		var outline := face.duplicate()
		outline.append(face[0])
		draw_polyline(outline, OUTLINE_COLOR, 1.5 / scale_factor, true)
	if _type_id == "":
		var roof := faces[2]
		var width := 5.0 / scale_factor
		# Von Kantenmitte zu Kantenmitte, damit das Kreuz auf dem Bildschirm schräg steht.
		draw_line(roof[0].lerp(roof[1], 0.5), roof[2].lerp(roof[3], 0.5), CROSS_COLOR, width, true)
		draw_line(roof[1].lerp(roof[2], 0.5), roof[3].lerp(roof[0], 0.5), CROSS_COLOR, width, true)
