class_name Building
extends RefCounted
## Ein Gebäude in der Spielwelt. Welche Kacheln es belegt, folgt aus Typ und Ursprung.

var id: int
var type: String
## Kachel mit den kleinsten Koordinaten der Grundfläche.
var origin: Vector2i
## Nur bei Lagern: Ware → Menge, in der Reihenfolge der Einlagerung.
var contents: Dictionary[String, int] = {}


static func create(building_id: int, type_id: String, origin_tile: Vector2i) -> Building:
	var building := Building.new()
	building.id = building_id
	building.type = type_id
	building.origin = origin_tile
	return building


func def() -> Dictionary:
	return GameDefs.get_instance().buildings[type]


func is_storage() -> bool:
	return def()["behavior"] == "storage"


## Lagerart bei Lagern, sonst leer.
func storage_type() -> String:
	return str(def().get("storage", ""))


func capacity() -> int:
	return int(def().get("capacity", 0))


## Wie viel gerade im Lager liegt (alle Waren zusammen).
func stored() -> int:
	var total := 0
	for good: String in contents:
		total += contents[good]
	return total


func tiles() -> Array[Vector2i]:
	return footprint(type, origin)


func entrance_front() -> Vector2i:
	return front_of_entrance(type, origin)


## Breite × Tiefe der Grundfläche eines Gebäudetyps.
static func size_of(type_id: String) -> Vector2i:
	return _vec(GameDefs.get_instance().buildings[type_id]["size"])


## Alle Kacheln der Grundfläche, zeilenweise.
static func footprint(type_id: String, origin_tile: Vector2i) -> Array[Vector2i]:
	var size := size_of(type_id)
	var result: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			result.append(origin_tile + Vector2i(x, y))
	return result


## Die Kacheln, die an die Grundfläche grenzen: direkt daneben, mit gemeinsamer Kante.
## Schräg an einer Ecke zählt nicht. Zeilenweise; kann außerhalb der Karte liegen.
static func adjacent_tiles(type_id: String, origin_tile: Vector2i) -> Array[Vector2i]:
	var size := size_of(type_id)
	var result: Array[Vector2i] = []
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var inside_x := x >= 0 and x < size.x
			var inside_y := y >= 0 and y < size.y
			# Genau eine Achse innerhalb: daneben, nicht darin und nicht an der Ecke.
			if inside_x != inside_y:
				result.append(origin_tile + Vector2i(x, y))
	return result


## Die Eingangskachel (innerhalb der Grundfläche).
static func entrance_of(type_id: String, origin_tile: Vector2i) -> Vector2i:
	return origin_tile + _vec(GameDefs.get_instance().buildings[type_id]["entrance"])


## Die Kachel vor dem Eingang, außerhalb der Grundfläche: in Richtung des Randes,
## an dem der Eingang liegt (vorne vor hinten, bei einer Ecke zählt die Tiefe).
static func front_of_entrance(type_id: String, origin_tile: Vector2i) -> Vector2i:
	var size := size_of(type_id)
	var entrance := _vec(GameDefs.get_instance().buildings[type_id]["entrance"])
	var direction := Vector2i.ZERO
	if entrance.y == size.y - 1:
		direction = Vector2i.DOWN
	elif entrance.x == size.x - 1:
		direction = Vector2i.RIGHT
	elif entrance.y == 0:
		direction = Vector2i.UP
	elif entrance.x == 0:
		direction = Vector2i.LEFT
	assert(direction != Vector2i.ZERO, "Eingang von „%s“ liegt nicht am Rand" % type_id)
	return origin_tile + entrance + direction


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"id": id, "type": type, "x": origin.x, "y": origin.y, "contents": contents.duplicate()}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Building:
	var building := create(int(data["id"]), str(data["type"]), Vector2i(int(data["x"]), int(data["y"])))
	var stored_goods: Dictionary = data["contents"]
	for good: Variant in stored_goods:
		building.contents[str(good)] = int(stored_goods[good])
	return building


static func _vec(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
