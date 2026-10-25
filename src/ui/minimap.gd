class_name Minimap
extends Control
## Minikarte: die ganze Karte verkleinert von oben, gerade statt schräg wie die Ansicht (Kachel-x
## nach rechts, Kachel-y nach unten) – je Kachel das Gelände (Farbe aus terrain.json), darüber
## Vorkommen mit „minimap_color“ (deposits.json) und Gebäude in ihrer Farbe –, dazu Feinde als rote
## Punkte und der Bildausschnitt der Kamera als Rahmen (in dieser Draufsicht eine Raute).
## Linksklick oder Ziehen mit der linken Taste meldet die Weltstelle darunter mit focus_requested.
## Das Bild hat ein Pixel je Kachel und wird nur an geänderten Kacheln neu gefärbt.

## Linksklick oder Ziehen auf der Minikarte: Die Kamera soll auf diesen Weltpunkt.
signal focus_requested(world_point: Vector2)

const SIZE := Vector2(180, 180)
const VIEW_COLOR := Color(1, 1, 1, 0.9)
const ENEMY_COLOR := Color("#ff3b30")
const ENEMY_RADIUS := 2.0

var _world: GameWorld
## Ein Pixel je Kachel.
var _image: Image
var _texture: ImageTexture
## Gebäude-ID → belegte Kacheln, damit sie nach dem Abriss wieder Gelände zeigen.
var _building_tiles: Dictionary[int, Array] = {}
## Das Bild hat sich seit dem letzten Hochladen geändert.
var _dirty := false
var _dragging := false


func _init() -> void:
	custom_minimum_size = SIZE
	clip_contents = true
	# Scharfe Kacheln statt verwaschener Übergänge.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_STOP


## Zeigt diese Spielwelt und folgt ihren Änderungen; eine vorige Spielwelt wird losgelassen.
func show_world(world: GameWorld) -> void:
	if _world != null:
		_world.deposit_added.disconnect(_paint)
		_world.deposit_removed.disconnect(_paint)
		_world.building_added.disconnect(_on_building_added)
		_world.building_removed.disconnect(_on_building_removed)
		_world.map.terrain_changed.disconnect(_paint)
	_world = world
	world.deposit_added.connect(_paint)
	world.deposit_removed.connect(_paint)
	world.building_added.connect(_on_building_added)
	world.building_removed.connect(_on_building_removed)
	world.map.terrain_changed.connect(_paint)
	var map := world.map
	_image = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	_building_tiles.clear()
	for y in map.height:
		for x in map.width:
			_paint(Vector2i(x, y))
	for building in world.get_buildings():
		_on_building_added(building.id)
	_texture = ImageTexture.create_from_image(_image)
	_dirty = false
	queue_redraw()


## Weltpunkt unter einem Punkt der Minikarte (lokale Koordinaten).
func to_world(point: Vector2) -> Vector2:
	return Iso.point_to_world(_layout().affine_inverse() * point)


## Punkt der Minikarte (lokale Koordinaten) zu einem Weltpunkt.
func to_minimap(world_point: Vector2) -> Vector2:
	return _layout() * Iso.world_to_point(world_point)


func _process(_delta: float) -> void:
	if _dirty:
		_texture.update(_image)
		_dirty = false
	# Kamera und Feinde bewegen sich ständig.
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	var layout := _layout()
	# Pixel (u, v) bedeckt die Kachel (u, v), also die Kachelpunkte u − 0,5 bis u + 0,5.
	draw_texture_rect(_texture, Rect2(layout * Vector2(-0.5, -0.5), layout.get_scale() * Vector2(_image.get_size())), false)
	for enemy in _world.get_enemies():
		draw_circle(layout * Vector2(enemy.tile), ENEMY_RADIUS, ENEMY_COLOR)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var half := get_viewport_rect().size / camera.zoom * 0.5
		var center := camera.get_screen_center_position()
		var view := PackedVector2Array()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			view.append(to_minimap(center + half * corner))
		# Auf die Minikarte begrenzt, damit der Rahmen auch bei sehr kleinen Karten sichtbar bleibt.
		var inside := Rect2(Vector2.ZERO, size).grow(-0.5)
		var frame := PackedVector2Array([inside.position, Vector2(inside.end.x, inside.position.y), inside.end,
				Vector2(inside.position.x, inside.end.y)])
		for outline: PackedVector2Array in Geometry2D.intersect_polygons(view, frame):
			outline.append(outline[0])
			draw_polyline(outline, VIEW_COLOR, 1.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if button.pressed:
			focus_requested.emit(to_world(button.position))
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		focus_requested.emit(to_world(motion.position))
		accept_event()


## Kachelpunkte (Kachelmitte = ganze Zahl) → Minikarte: die ganze Karte so groß wie möglich, mittig.
func _layout() -> Transform2D:
	if _world == null:
		return Transform2D.IDENTITY
	var map_size := Vector2(_world.map.width, _world.map.height)
	var factor := minf(size.x / map_size.x, size.y / map_size.y)
	var center := map_size * 0.5 - Vector2(0.5, 0.5)
	return Transform2D(0.0, Vector2(factor, factor), 0.0, size * 0.5 - center * factor)


## Färbt eine Kachel neu: Gebäude vor Vorkommen vor Gelände.
func _paint(tile: Vector2i) -> void:
	var defs := GameDefs.get_instance()
	var building := _world.get_building_at(tile)
	var deposit := _world.map.get_deposit(tile)
	var color: Color
	if building != null and building.def().has("color"):
		color = Color(str(building.def()["color"]))
	elif deposit != null and defs.deposits[deposit.type].has("minimap_color"):
		color = Color(str(defs.deposits[deposit.type]["minimap_color"]))
	else:
		color = Color(str(defs.terrain[_world.map.get_terrain(tile)]["color"]))
	_image.set_pixelv(tile, color)
	_dirty = true


func _on_building_added(id: int) -> void:
	var tiles := _world.get_building(id).tiles()
	_building_tiles[id] = tiles
	for tile: Vector2i in tiles:
		_paint(tile)


func _on_building_removed(id: int) -> void:
	var tiles: Array = _building_tiles.get(id, [])
	_building_tiles.erase(id)
	for tile: Vector2i in tiles:
		_paint(tile)
