extends Node2D
## Galerie der Figurensprites: jeder Typ mit Animation in acht Richtungen, stehend und gehend.

var clock: GameClock
var _samples: Array[Dictionary] = []
var _textures: Dictionary[String, Texture2D] = {}


func setup(game_clock: GameClock) -> void:
	clock = game_clock
	var row := 0
	for type: String in GameDefs.get_instance().units:
		var entry: Dictionary = GameDefs.get_instance().units[type]
		if not entry.has("animations"):
			continue
		for animation: String in entry["animations"]:
			for direction in 8:
				var point := Iso.point_to_world(Vector2(24 + direction + row * 2, 16 - direction + row * 2))
				_samples.append({"entry": entry, "animation": animation, "direction": direction, "point": point})
			row += 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var seconds := (clock.world.get_tick() + clock.tick_fraction()) / float(GameClock.TICKS_PER_SECOND)
	for sample in _samples:
		var entry: Dictionary = sample["entry"]
		var animation: String = sample["animation"]
		var settings: Dictionary = entry["animations"][animation]
		var frame := FigureAnimation.frame(seconds, int(settings["frames"]), float(settings["fps"]))
		var path := GameDefs.SPRITE_DIR + str(entry["sprite"]) + "_%s_%d_%d.png" % [animation, int(sample["direction"]), frame]
		if not _textures.has(path):
			_textures[path] = load(path) as Texture2D
		var texture: Texture2D = _textures[path]
		var point: Vector2 = sample["point"]
		draw_texture_rect(texture, Rect2(point - texture.get_size() * 0.25, texture.get_size() * 0.5), false)
		draw_string(ThemeDB.fallback_font, point + Vector2(-16, 14), "Stehen" if animation == "idle" else "Gehen", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
