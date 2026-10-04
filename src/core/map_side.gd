class_name MapSide
extends RefCounted
## Die vier Seiten der Karte, aus denen Wellen kommen, an einer Stelle: Name im Plan ("north" …),
## Name im Spieltext („Welle aus Norden!“) und Richtung aus der Karte hinaus. Daraus folgt, welche
## Randkacheln zur Seite gehören: die, von denen ein Schritt in diese Richtung die Karte verlässt
## (Norden y = 0, Osten x = Breite − 1, Süden y = Höhe − 1, Westen x = 0; eine Ecke gehört zu
## beiden Seiten). Reine Daten.

## Seite → [Name im Spieltext, Richtung aus der Karte hinaus (in Kacheln)], in der Reihenfolge, in
## der der Zufall unter ihnen wählt.
const _TABLE: Dictionary[String, Array] = {
	"north": ["Norden", Vector2i(0, -1)],
	"east": ["Osten", Vector2i(1, 0)],
	"south": ["Süden", Vector2i(0, 1)],
	"west": ["Westen", Vector2i(-1, 0)],
}


## Alle Seiten in fester Reihenfolge (Norden, Osten, Süden, Westen).
static func all() -> Array[String]:
	var result: Array[String] = []
	result.assign(_TABLE.keys())
	return result


static func is_side(side: String) -> bool:
	return _TABLE.has(side)


## Name im Spieltext, z. B. „Norden“.
static func name_of(side: String) -> String:
	return _TABLE[side][0]


## Richtung aus der Karte hinaus, z. B. (0, −1) für Norden.
static func outward(side: String) -> Vector2i:
	return _TABLE[side][1]


## Liegt die Kachel auf der Karte am Rand dieser Seite?
static func is_on(map: MapData, side: String, tile: Vector2i) -> bool:
	return map.in_bounds(tile) and not map.in_bounds(tile + outward(side))


## Die Randkacheln der Seite, zeilenweise.
static func tiles(map: MapData, side: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if is_on(map, side, Vector2i(x, y)):
				result.append(Vector2i(x, y))
	return result
