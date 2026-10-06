extends Node2D
## Alle Figurentypen und Animationen in acht Richtungen auf der Kontaktübersicht.

const ANIMATION_NAMES: Dictionary[String, String] = {
	"idle": "Stehen", "walk": "Gehen", "attack": "Angriff",
	"axe": "Hacken", "pick": "Schlagen",
}
var clock: GameClock
var _samples: Array[Dictionary] = []
var _textures: Dictionary[String, Texture2D] = {}


func setup(game_clock: GameClock) -> void:
	clock = game_clock
	var count := 0
	for entry: Dictionary in GameDefs.get_instance().units.values():
		count += entry.get("animations", {}).size()
	var row_height := minf(40.0, 640.0 / maxi(count, 1))
	var row := 0
	for type_id: String in GameDefs.get_instance().units:
		var entry: Dictionary = GameDefs.get_instance().units[type_id]
		for animation: String in entry.get("animations", {}):
			for direction in 8:
				_samples.append({"entry": entry, "animation": animation, "direction": direction,
					"point": Vector2(190 + direction * 43, 54 + row * row_height), "row": row})
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
		var path := GameDefs.animation_path(entry, animation, int(sample["direction"]), frame)
		if not _textures.has(path):
			_textures[path] = load(path) as Texture2D
		var texture: Texture2D = _textures[path]
		var point: Vector2 = sample["point"]
		draw_texture_rect(texture, Rect2(point - texture.get_size() * 0.25, texture.get_size() * 0.5), false)
		if int(sample["direction"]) == 0:
			draw_string(ThemeDB.fallback_font, Vector2(0, point.y + 4), "%s · %s" % [entry["name"], ANIMATION_NAMES.get(animation, animation)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#eadfcb"))
