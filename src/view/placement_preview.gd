class_name PlacementPreview
extends Node2D
## Halbdurchsichtige Bauvorschau unter der Maus: Grundflächen grün (erlaubt) oder rot,
## dazu die Kachel vor dem Eingang. Kennt nur Typ und Ursprung, keinen Zustand.

const OK_COLOR := Color(0.35, 0.9, 0.4)
const BLOCKED_COLOR := Color(0.95, 0.3, 0.25)
const FILL_ALPHA := 0.35
const BLOCK_ALPHA := 0.45
const FRONT_COLOR := Color(1, 0.95, 0.7, 0.8)

## Paare [Gebäudetyp, Ursprung].
var _parts: Array[Array] = []
var _allowed := true


func show_parts(parts: Array[Array], allowed: bool) -> void:
	_parts = parts
	_allowed = allowed
	visible = true
	queue_redraw()


func _draw() -> void:
	var color := OK_COLOR if _allowed else BLOCKED_COLOR
	for part in _parts:
		var type_id: String = part[0]
		var origin: Vector2i = part[1]
		for tile in Building.footprint(type_id, origin):
			draw_colored_polygon(Iso.tile_polygon(tile), Color(color, FILL_ALPHA))
		_draw_ghost_block(type_id, origin, color)
		var front := Iso.tile_polygon(Building.front_of_entrance(type_id, origin))
		front.append(front[0])
		draw_polyline(front, FRONT_COLOR, 2.0, true)


## Umriss des späteren Blocks, damit Größe und Höhe erkennbar sind.
func _draw_ghost_block(type_id: String, origin: Vector2i, color: Color) -> void:
	var base := BuildingView.footprint_corners(type_id, origin, Vector2.ZERO, BuildingView.INSET)
	var faces := BuildingView.block_faces(base, float(GameDefs.get_instance().buildings[type_id]["height"]))
	var faded := Color(color, BLOCK_ALPHA)
	draw_colored_polygon(faces[0], faded.darkened(0.2))
	draw_colored_polygon(faces[1], faded.darkened(0.35))
	draw_colored_polygon(faces[2], faded)
