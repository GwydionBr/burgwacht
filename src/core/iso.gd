class_name Iso
## Umrechnung zwischen Kachel-Koordinaten (Raster) und Weltkoordinaten
## in der isometrischen Ansicht. Kachel (0, 0) liegt mit ihrer Mitte bei (0, 0).

const TILE_W := 64.0
const TILE_H := 32.0


## Mittelpunkt einer Kachel in Weltkoordinaten.
static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2((tile.x - tile.y) * TILE_W * 0.5, (tile.x + tile.y) * TILE_H * 0.5)


## Kachel, auf der ein Weltpunkt liegt.
static func world_to_tile(pos: Vector2) -> Vector2i:
	var a := pos.x / (TILE_W * 0.5)
	var b := pos.y / (TILE_H * 0.5)
	return Vector2i(floori((a + b) * 0.5 + 0.5), floori((b - a) * 0.5 + 0.5))


## Die vier Eckpunkte der Kachel-Raute: oben, rechts, unten, links.
static func tile_polygon(tile: Vector2i) -> PackedVector2Array:
	var c := tile_to_world(tile)
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	return PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0),
	])


## Rechteck in Weltkoordinaten, das die ganze Karte umschließt.
static func map_bounds(width: int, height: int) -> Rect2:
	var left := -height * TILE_W * 0.5
	var right := width * TILE_W * 0.5
	var bottom := (width + height) * TILE_H * 0.5
	return Rect2(left, -TILE_H * 0.5, right - left, bottom)
