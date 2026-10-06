extends Node2D
## Kamerunabhängige, datengetriebene Grafikübersicht; Animationen folgen der Spieluhr.

const INK := Color("#eadfcb")
const BACKGROUND := Color("#252b25")
const WALL_CASES: Array[Array] = [
	[Vector2i(1, 0)], [Vector2i(-1, 0), Vector2i(1, 0)],
	[Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)],
	[Vector2i(-1, -1), Vector2i(1, 1)],
]
const WALL_NAMES: Array[String] = ["Ende", "Gerade", "Ecke", "Abzweigung", "Kreuz", "Diagonal"]
var _clock: GameClock
var _pictures: Array[Dictionary] = []
var _labels: Array[Dictionary] = []
var _textures: Dictionary[String, Texture2D] = {}
var _animated: Array[Dictionary] = []


func setup(clock: GameClock) -> void:
	_clock = clock
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add_buildings()
	_add_walls()
	_add_terrain()
	_add_deposits()
	var figures: Node2D = load("res://tests/setups/gallery_figures.gd").new()
	figures.call("setup", clock)
	figures.position = Vector2(1030, 32)
	var goods: Node2D = load("res://tests/setups/gallery_goods.gd").new()
	goods.call("setup", clock)
	goods.position = Vector2(1030, 746)
	add_child(goods)
	_label("Getragene Waren · jedes Rückenbündel", Vector2(1030, 737), 17)
	add_child(figures)
	_label("Figuren · jede Animation in acht Richtungen", Vector2(1030, 27), 17)
	for direction in 8:
		_label(str(direction + 1), Vector2(1216 + direction * 43, 49), 10)
	queue_redraw()


func _label(text: String, point: Vector2, size: int = 12) -> void:
	_labels.append({"text": text, "point": point, "size": size})


func _picture(path: String, box: Rect2, atlas: bool = false) -> void:
	_pictures.append({"path": path, "box": box, "atlas": atlas, "scale": 0.0})


func _add_buildings() -> void:
	_label("Gebäude · alle Typen und Varianten", Vector2(20, 27), 17)
	var count := 1
	for entry: Dictionary in GameDefs.get_instance().buildings.values():
		count += int(entry.get("sprite_variants", 1))
	var row_height := minf(78.0, 390.0 / ceilf(count / 7.0))
	var index := 0
	for type_id: String in GameDefs.get_instance().buildings:
		var entry: Dictionary = GameDefs.get_instance().buildings[type_id]
		var variants := int(entry.get("sprite_variants", 1))
		for variant in variants:
			var point := Vector2(20 + (index % 7) * 140, 42 + (index / 7) * row_height)
			var box := Rect2(point, Vector2(130, row_height - 20))
			_picture(GameDefs.shadow_path(entry, variant), box)
			_picture(GameDefs.sprite_path(entry, variant), box)
			if not ResourceLoader.exists(GameDefs.sprite_path(entry, variant)):
				_add_fallback_building(type_id, box)
			var title := str(entry["name"])
			if variants > 1:
				title += " %d" % (variant + 1)
			_label(title, point + Vector2(0, row_height - 2), 11)
			if entry.has("sprite_animation"):
				_animated.append({"entry": entry, "box": box})
			index += 1
	var arrow_point := Vector2(20 + (index % 7) * 140, 42 + (index / 7) * row_height)
	_picture(ArrowView.SPRITE_PATH, Rect2(arrow_point, Vector2(130, row_height - 20)))
	_pictures.back()["scale"] = 0.5
	_label("Pfeil", arrow_point + Vector2(0, row_height - 2), 11)
	# Die Lagerfeuerschleife erscheint am Gebäude; daneben stehen ihre Einzelbilder.
	for entry: Dictionary in GameDefs.get_instance().buildings.values():
		if not entry.has("sprite_animation"):
			continue
		for frame in int(entry["sprite_animation"]["frames"]):
			_picture(GameDefs.building_animation_path(entry, frame), Rect2(20 + frame * 44, 452, 40, 40))
		_label("Flammen · Einzelbilder", Vector2(20, 503), 11)


## Neue Gebäudetypen ohne Bild verwenden auch in der Übersicht die Produktionsansicht.
func _add_fallback_building(type_id: String, box: Rect2) -> void:
	var building := Building.new()
	building.type = type_id
	building.origin = Vector2i.ZERO
	var holder := Node2D.new()
	var size := Building.size_of(type_id)
	var ratio := minf(box.size.x / (size.x * Iso.TILE_W), box.size.y / (size.y * Iso.TILE_H + float(GameDefs.get_instance().buildings[type_id]["height"])))
	holder.scale = Vector2(ratio, ratio)
	holder.position = box.get_center() - Iso.point_to_world(Vector2(size - Vector2i.ONE) / 2) * ratio
	add_child(holder)
	var view := BuildingView.new()
	view.setup(building)
	holder.add_child(view)


func _add_walls() -> void:
	_label("Maueranschlüsse", Vector2(230, 453), 14)
	for entry: Dictionary in GameDefs.get_instance().buildings.values():
		if not bool(entry.get("sprite_connections", false)):
			continue
		for index in WALL_CASES.size():
			var neighbors: Array[Vector2i] = []
			neighbors.assign(WALL_CASES[index])
			var box := Rect2(230 + index * 125, 462, 112, 57)
			for path in WallSprites.paths(entry, Vector2i.ZERO, neighbors):
				_picture(path.trim_suffix(".png") + "_shadow.png", box)
				_pictures.back()["scale"] = 0.36
				_picture(path, box)
				_pictures.back()["scale"] = 0.36
			_label(WALL_NAMES[index], box.position + Vector2(0, 70), 11)


func _add_terrain() -> void:
	_label("Gelände · vier Varianten", Vector2(20, 559), 14)
	var ids: Array = GameDefs.get_instance().terrain.keys()
	var group_width := 960.0 / ids.size()
	for index in ids.size():
		var entry: Dictionary = GameDefs.get_instance().terrain[ids[index]]
		var variants := int(entry.get("sprite_variants", 1))
		var width := (group_width - 10) / variants
		for variant in variants:
			_picture(GameDefs.sprite_path(entry, variant), Rect2(20 + index * group_width + variant * width, 569, width, 23), true)
		_label(str(entry["name"]), Vector2(20 + index * group_width, 607), 11)
	_label("Übergänge · jede Geländepaarung mit Kante, Ecke und diagonaler Berührung", Vector2(20, 634), 14)
	var pair_width := 960.0 / maxi(ids.size() * (ids.size() - 1) / 2, 1)
	var pair := 0
	for first in ids.size():
		for second in range(first + 1, ids.size()):
			var map := MapData.new(4, 4, str(ids[first]))
			for y in 4:
				for x in 4:
					if x >= 2 or y >= 3:
						map.set_terrain(Vector2i(x, y), str(ids[second]))
			map.set_terrain(Vector2i(0, 0), str(ids[second]))
			var terrain := TerrainRenderer.new()
			terrain.show_map(map)
			terrain.scale = Vector2.ONE * minf(0.32, (pair_width - 8) / 256.0)
			terrain.position = Vector2(20 + pair_width / 2 + pair * pair_width, 650)
			add_child(terrain)
			var first_name: String = GameDefs.get_instance().terrain[ids[first]]["name"]
			var second_name: String = GameDefs.get_instance().terrain[ids[second]]["name"]
			_label(first_name, Vector2(20 + pair * pair_width, 710), 10)
			_label(second_name, Vector2(20 + pair * pair_width, 724), 10)
			pair += 1


func _add_deposits() -> void:
	_label("Vorkommen · jede gespeicherte Variante", Vector2(20, 758), 14)
	var entries: Array = GameDefs.get_instance().deposits.values()
	var group_width := 960.0 / entries.size()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var variants := int(entry.get("sprite_variants", 1))
		var width := group_width / variants
		for variant in variants:
			var box := Rect2(20 + index * group_width + variant * width, 768, width - 4, 66)
			_picture(GameDefs.shadow_path(entry, variant), box)
			_picture(GameDefs.sprite_path(entry, variant), box)
			_label(str(variant + 1), box.position + Vector2(width / 2 - 4, 76), 10)
		_label(str(entry["name"]), Vector2(20 + index * group_width, 870), 12)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), BACKGROUND)
	for label: Dictionary in _labels:
		draw_string(ThemeDB.fallback_font, label["point"], label["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(label["size"]), INK)
	for picture: Dictionary in _pictures:
		_draw_picture(str(picture["path"]), picture["box"], bool(picture["atlas"]), float(picture["scale"]))
	var seconds := (_clock.world.get_tick() + _clock.tick_fraction()) / float(GameClock.TICKS_PER_SECOND)
	for sample: Dictionary in _animated:
		_draw_picture(BuildingSprites.animation_path(sample["entry"], seconds), sample["box"], false)


func _draw_picture(path: String, box: Rect2, atlas: bool, fixed_scale: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	var texture: Texture2D = _textures[path]
	var source := Rect2(Vector2.ZERO, Vector2(128, 64) if atlas else texture.get_size())
	var ratio := minf(box.size.x / source.size.x, box.size.y / source.size.y)
	var size := source.size * (fixed_scale if fixed_scale > 0 else ratio)
	draw_texture_rect_region(texture, Rect2(box.get_center() - size / 2, size), source)
