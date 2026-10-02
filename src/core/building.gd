class_name Building
extends RefCounted
## Ein Gebäude in der Spielwelt. Welche Kacheln es belegt, folgt aus Typ und Ursprung.

var id: int
var type: String
## Kachel mit den kleinsten Koordinaten der Grundfläche.
var origin: Vector2i
## Nur bei Lagern: Ware → Menge, in der Reihenfolge der Einlagerung.
var contents: Dictionary[String, int] = {}
## Nur bei Arbeitsstätten: Fand die letzte Zuteilung keinen Untätigen mit Weg zum Eingang?
var unreachable := false
## Nur bei Arbeitsstätten: Vor diesem Takt wird nach einer gescheiterten Zuteilung nicht
## erneut geprüft.
var retry_tick := 0


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


func is_campfire() -> bool:
	return def()["behavior"] == "campfire"


## Beschäftigt das Gebäude Arbeiter ("workers" in den Daten)?
func is_workplace() -> bool:
	return worker_slots() > 0


## Wie viele Arbeiter das Gebäude laut Daten beschäftigt.
func worker_slots() -> int:
	return int(def().get("workers", 0))


## Wie ein Arbeiter dieses Gebäudes heißt, z. B. „Holzfäller“.
func worker_name() -> String:
	return str(def().get("worker_name", "Arbeiter"))


## Sammler: Typ des Vorkommens, das seine Arbeiter abbauen ("deposit"), sonst leer.
func deposit_type() -> String:
	return str(def().get("deposit", ""))


## Sammler: Takte für einen Abbau ("mine_ticks").
func mine_ticks() -> int:
	return int(def()["mine_ticks"])


## Sammler: Takte für die Verarbeitung in der Arbeitsstätte ("process_ticks").
func process_ticks() -> int:
	return int(def()["process_ticks"])


## Sammler: so viel nimmt ein Arbeiter je Gang höchstens aus dem Vorkommen ("load").
func carry_load() -> int:
	return int(def()["load"])


## Sammler: Suchradius für Vorkommen als Weglänge ab dem Eingang ("range").
func gather_range() -> int:
	return int(def()["range"])


## Dürfen Bewohner die ganze Grundfläche betreten (z. B. das Lagerfeuer)?
func is_walkable() -> bool:
	return bool(def().get("walkable", false))


## Lagert bis zu amount einer Ware ein, so viel noch Platz ist; liefert die eingelagerte Menge.
func store(good: String, amount: int) -> int:
	var added := mini(amount, capacity() - stored())
	if added <= 0:
		return 0
	contents[good] = contents.get(good, 0) + added
	return added


## Lagerart bei Lagern, sonst leer.
func storage_type() -> String:
	return storage_type_of(type)


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


## Gebäude ohne Eingang (z. B. das Lagerfeuer) haben keine Kachel davor.
func has_entrance() -> bool:
	return has_entrance_type(type)


func entrance() -> Vector2i:
	return entrance_of(type, origin)


func entrance_front() -> Vector2i:
	return front_of_entrance(type, origin)


## Lagerart eines Gebäudetyps, wenn er ein Lager ist, sonst leer.
static func storage_type_of(type_id: String) -> String:
	return str(GameDefs.get_instance().buildings[type_id].get("storage", ""))


## Name der Lagerart, z. B. „Kornspeicher“: der Name des ersten Gebäudetyps (Reihenfolge in
## den Daten), der Waren dieser Lagerart lagert.
static func storage_name(storage_type: String) -> String:
	var buildings := GameDefs.get_instance().buildings
	for type_id: String in buildings:
		if storage_type_of(type_id) == storage_type:
			return str(buildings[type_id]["name"])
	return storage_type


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


static func has_entrance_type(type_id: String) -> bool:
	return GameDefs.get_instance().buildings[type_id].has("entrance")


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
	return {
		"id": id, "type": type, "x": origin.x, "y": origin.y, "contents": contents.duplicate(),
		"unreachable": unreachable, "retry_tick": retry_tick,
	}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> Building:
	var building := create(int(data["id"]), str(data["type"]), Vector2i(int(data["x"]), int(data["y"])))
	var stored_goods: Dictionary = data["contents"]
	for good: Variant in stored_goods:
		building.contents[str(good)] = int(stored_goods[good])
	building.unreachable = bool(data["unreachable"])
	building.retry_tick = int(data["retry_tick"])
	return building


static func _vec(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
