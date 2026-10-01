class_name CameraController
extends Camera2D
## Kamerasteuerung: Tastatur, Trackpad (zwei Finger scrollen, Pinch zum Zoomen),
## Mausrad, Ziehen mit rechter/mittlerer Maustaste und Bildschirmrand (nur im Vollbild).

const PAN_SPEED := 900.0
const PAN_GESTURE_SPEED := 14.0
const EDGE_MARGIN := 8.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.5
const ZOOM_STEP := 1.12

var bounds := Rect2()

var _dragging := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	dir += _edge_scroll_direction()
	if dir != Vector2.ZERO:
		_move_by(dir.normalized() * PAN_SPEED * delta / zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / ZOOM_STEP)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_move_by(-event.relative / zoom.x)
	elif event is InputEventPanGesture:
		_move_by(event.delta * PAN_GESTURE_SPEED / zoom.x)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)


func focus_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_to_bounds()


func _move_by(offset: Vector2) -> void:
	position += offset
	_clamp_to_bounds()


## Zoomt so, dass der Punkt unter dem Mauszeiger an derselben Stelle bleibt.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var from_center := screen_pos - get_viewport_rect().size * 0.5
	var world_under_cursor := position + from_center / zoom.x
	var new_zoom := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom, new_zoom)
	position = world_under_cursor - from_center / new_zoom
	_clamp_to_bounds()


func _edge_scroll_direction() -> Vector2:
	if get_window().mode != Window.MODE_FULLSCREEN and get_window().mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
		return Vector2.ZERO
	var size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var dir := Vector2.ZERO
	if mouse.x <= EDGE_MARGIN:
		dir.x -= 1
	elif mouse.x >= size.x - EDGE_MARGIN:
		dir.x += 1
	if mouse.y <= EDGE_MARGIN:
		dir.y -= 1
	elif mouse.y >= size.y - EDGE_MARGIN:
		dir.y += 1
	return dir


func _clamp_to_bounds() -> void:
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)
