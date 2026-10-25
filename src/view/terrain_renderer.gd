class_name TerrainRenderer
extends Node2D
## Zeichnet den Boden der Karte. Wird nur in show_map() neu aufgebaut (das Gelände ändert sich im
## Spiel nicht) – nicht in jedem Frame. Die Karte ist in Blöcke (Chunk) geteilt, damit Godot
## Blöcke außerhalb des Bildes auslässt; innerhalb eines Blocks liegen gleiche Bilder
## hintereinander, damit Godot sie in einem Aufruf an die Grafikkarte zeichnet statt in einem je
## Kachel.

## Höhe der sichtbaren Erdkante am vorderen Kartenrand.
const EDGE_DEPTH := 18.0
## Doppelte Auflösung der gerenderten Kachel; eine Atlasspalte je Kantenmaske.
const SPRITE_CELL_SIZE := Vector2(128, 64)
const TILE_SIZE := Vector2(Iso.TILE_W, Iso.TILE_H)
const EDGE_COLOR := Color("#4a3a26")
const WAVE_COLOR := Color(1, 1, 1, 0.18)
## Kacheln je Blockseite.
const CHUNK_SIZE := 16
## Zeichenreihenfolge im Block: erst alle Böden, dann die Übergänge, zuletzt die Kartenkante; Böden
## und Übergänge je nach Geländerang, damit der höhere den Überstand des niedrigeren an der Naht deckt.
const BASE_LAYER := -100
const EDGE_LAYER := 1000

var _map: MapData
var _textures: Dictionary[String, Texture2D] = {}


func show_map(map: MapData) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_map = map
	for old: Node in get_children():
		remove_child(old)
		old.queue_free()
	for y in range(0, map.height, CHUNK_SIZE):
		for x in range(0, map.width, CHUNK_SIZE):
			var chunk := Chunk.new()
			chunk.renderer = self
			chunk.tiles = Rect2i(x, y, mini(CHUNK_SIZE, map.width - x), mini(CHUNK_SIZE, map.height - y))
			add_child(chunk)


## Zeichnet die Kacheln in tiles auf canvas, gleiche Bilder je Zeichenschicht gebündelt.
func draw_tiles(canvas: CanvasItem, tiles: Rect2i) -> void:
	var terrain_defs := GameDefs.get_instance().terrain
	# Zeichenschicht -> Bild -> abwechselnd Ziel- und Quellrechteck.
	var layers: Dictionary[int, Dictionary] = {}
	for y in range(tiles.position.y, tiles.end.y):
		for x in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(x, y)
			var terrain_id := _map.get_terrain(tile)
			var poly := Iso.tile_polygon(tile)
			var entry: Dictionary = terrain_defs[terrain_id]
			if not _queue_sprite(layers, tile, entry):
				canvas.draw_colored_polygon(poly, _tile_color(tile, Color(entry["color"])))
				if terrain_id == "water" and _tile_hash(tile) % 4 == 0:
					_draw_wave(canvas, Iso.tile_to_world(tile))
			_queue_map_edge(canvas, layers, tile, poly, entry)
	var order: Array[int] = []
	order.assign(layers.keys())
	order.sort()
	for layer in order:
		var batches: Dictionary = layers[layer]
		for texture: Texture2D in batches:
			var rects: Array[Rect2] = batches[texture]
			for i in range(0, rects.size(), 2):
				canvas.draw_texture_rect_region(texture, rects[i], rects[i + 1])


static func _queue(layers: Dictionary[int, Dictionary], layer: int, texture: Texture2D, destination: Rect2,
		source: Rect2) -> void:
	if not layers.has(layer):
		layers[layer] = {}
	var batches: Dictionary = layers[layer]
	if not batches.has(texture):
		var rects: Array[Rect2] = []
		batches[texture] = rects
	var queued: Array[Rect2] = batches[texture]
	queued.append(destination)
	queued.append(source)


## Kleine Helligkeitsunterschiede, damit der Boden nicht wie eine Fläche wirkt.
func _tile_color(tile: Vector2i, base: Color) -> Color:
	var shade := (_tile_hash(tile) % 1000) / 1000.0 - 0.5
	return base.lightened(shade * 0.08) if shade > 0 else base.darkened(-shade * 0.08)


func _draw_wave(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_line(center + Vector2(-9, 1), center + Vector2(-2, -1), WAVE_COLOR, 1.5, true)
	canvas.draw_line(center + Vector2(-2, -1), center + Vector2(5, 1), WAVE_COLOR, 1.5, true)


## Am vorderen Rand eine Erdkante zeichnen, damit die Karte wie eine Scholle wirkt.
func _queue_map_edge(canvas: CanvasItem, layers: Dictionary[int, Dictionary], tile: Vector2i,
		poly: PackedVector2Array, entry: Dictionary) -> void:
	if entry.has("sprite_edge"):
		var texture: Texture2D = _texture("res://assets/sprites/" + str(entry["sprite_edge"]) + ".png")
		if texture != null:
			var center: Vector2 = Iso.tile_to_world(tile)
			for side: int in 2:
				if (side == 0 and tile.x == _map.width - 1) or (side == 1 and tile.y == _map.height - 1):
					_queue(layers, EDGE_LAYER, texture, Rect2(center - Vector2(32, 16), Vector2(64, 52)),
							Rect2(Vector2(side * 128, 0), Vector2(128, 104)))
			return
	var depth := Vector2(0, EDGE_DEPTH)
	if tile.x == _map.width - 1:
		canvas.draw_colored_polygon(PackedVector2Array([poly[1], poly[2], poly[2] + depth, poly[1] + depth]), EDGE_COLOR)
	if tile.y == _map.height - 1:
		canvas.draw_colored_polygon(PackedVector2Array([poly[2], poly[3], poly[3] + depth, poly[2] + depth]),
				EDGE_COLOR.darkened(0.25))


func _tile_hash(tile: Vector2i) -> int:
	return absi(hash(tile))


## Kantenmaske im Uhrzeigersinn: Norden, Osten, Süden, Westen; diagonale Nachbarn zählen nicht.
static func transition_mask(map: MapData, tile: Vector2i, neighbor_id: String) -> int:
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var mask: int = 0
	for index: int in offsets.size():
		var neighbor: Vector2i = tile + offsets[index]
		if map.in_bounds(neighbor) and map.get_terrain(neighbor) == neighbor_id:
			mask |= 1 << index
	return mask


## Rein aus der Kachelposition, ohne Zufall der Spielwelt oder Eintrag im Spielstand.
static func variant_index(tile: Vector2i, count: int) -> int:
	return posmod(tile.x * 17 + tile.y * 31 + tile.x * tile.y * 7, maxi(count, 1))


## Übergänge zu allen höherrangigen Nachbargeländen; Ecken schließen auch diagonale Berührungen.
## Bits 0–3: Nord, Ost, Süd, West; Bits 4–7: Nordost, Südost, Südwest, Nordwest.
static func transition_layers(map: MapData, tile: Vector2i) -> Dictionary[String, int]:
	var definitions: Dictionary = GameDefs.get_instance().terrain
	var source: Dictionary = definitions[map.get_terrain(tile)]
	var result: Dictionary[String, int] = {}
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for index: int in offsets.size():
		var neighbor: Vector2i = tile + offsets[index]
		if not map.in_bounds(neighbor):
			continue
		var target_id: String = map.get_terrain(neighbor)
		var target: Dictionary = definitions[target_id]
		if not target.has("sprite_overlay") or int(target.get("sprite_priority", 0)) <= int(source.get("sprite_priority", 0)):
			continue
		if index >= 4:
			var adjacent_mask: int = (1 << (index - 4)) | (1 << ((index - 3) % 4))
			if transition_mask(map, tile, target_id) & adjacent_mask:
				continue
		result[target_id] = result.get(target_id, 0) | (1 << index)
	return result


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			return null
		_textures[path] = load(path) as Texture2D
	return _textures[path]


func _queue_sprite(layers: Dictionary[int, Dictionary], tile: Vector2i, entry: Dictionary) -> bool:
	if not entry.has("sprite"):
		return false
	var variant: int = variant_index(tile, int(entry.get("sprite_variants", 1)))
	var texture: Texture2D = _texture(GameDefs.sprite_path(entry, variant))
	if texture == null:
		return false
	var center: Vector2 = Iso.tile_to_world(tile)
	# Ein Viertelpixel Überstand schließt die Filternaht, ohne eine gezeichnete Raute unterzulegen.
	var destination := Rect2(center - TILE_SIZE / 2 - Vector2(0.25, 0.125), TILE_SIZE + Vector2(0.5, 0.25))
	_queue(layers, BASE_LAYER + int(entry.get("sprite_priority", 0)), texture, destination, Rect2(Vector2.ZERO, SPRITE_CELL_SIZE))
	var transitions: Dictionary[String, int] = transition_layers(_map, tile)
	# Ebene nach Rang: die höchste Priorität liegt zuletzt und schließt Kreuzungen.
	for target_id: String in transitions:
		var target: Dictionary = GameDefs.get_instance().terrain[target_id]
		var overlay_entry: Dictionary = {"sprite": target["sprite_overlay"], "sprite_variants": target.get("sprite_variants", 1)}
		var overlay: Texture2D = _texture(GameDefs.sprite_path(overlay_entry, variant_index(tile, int(target.get("sprite_variants", 1)))))
		if overlay == null:
			continue
		for direction: int in 8:
			if transitions[target_id] & (1 << direction):
				_queue(layers, int(target["sprite_priority"]), overlay, destination,
						Rect2(Vector2(direction * SPRITE_CELL_SIZE.x, 0), SPRITE_CELL_SIZE))
	return true


## Ein Block Kacheln als eigenes Zeichenobjekt.
class Chunk:
	extends Node2D

	var renderer: TerrainRenderer
	var tiles: Rect2i


	func _draw() -> void:
		renderer.draw_tiles(self, tiles)
