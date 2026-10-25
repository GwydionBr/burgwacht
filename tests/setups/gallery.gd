extends RefCounted
## Beschriftete Kontaktübersicht aller Grafiktypen im Preset „gallery“.
## Die Proben liegen auf einer eigenen Bildschirmebene, damit Kamera, Karte und HUD sie nicht verdecken.


static func create() -> GameWorld:
	var world := TestCase.new().empty_world("gallery")
	var reason := world.execute(Command.found(Vector2i(15, 15)))
	assert(reason == "", "Gründung: " + reason)
	return world


static func decorate(scene: Node2D, clock: GameClock) -> void:
	scene.get_node("HUD").hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	scene.add_child(layer)
	var board: Node2D = load("res://tests/setups/gallery_board.gd").new()
	layer.add_child(board)
	board.call("setup", clock)
	# Die Übersicht wächst bzw. schrumpft mit der sichtbaren Fläche.
	var board_size: Vector2 = (board.get_script() as Script).get_script_constant_map()["SIZE"]
	var ratio := scene.get_viewport().get_visible_rect().size / board_size
	board.scale = Vector2.ONE * minf(ratio.x, ratio.y)
