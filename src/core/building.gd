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


func is_market() -> bool:
	return def()["behavior"] == "market"


## Kaserne (Verhalten „barracks“, ohne Arbeiter): Hier werden Soldaten angeworben.
func is_barracks() -> bool:
	return def()["behavior"] == "barracks"


## Treppe (Verhalten „stairs“): verbindet den Boden mit dem Wehrgang der Mauerkacheln daneben.
func is_stairs() -> bool:
	return def()["behavior"] == "stairs"


## Trägt das Gebäude einen Wehrgang ("walkway" in den Daten, z. B. die Mauer)?
func has_walkway() -> bool:
	return bool(def().get("walkway", false))


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


## Hof (Verhalten „farm“): Arbeiter arbeiten in der Arbeitsstätte statt an einem Vorkommen.
func is_farm() -> bool:
	return def()["behavior"] == "farm"


## Herstellungsbetrieb (Verhalten „produce“): Arbeiter holen die Eingangsware aus einem Lager
## und stellen daraus in der Arbeitsstätte das Erzeugnis her.
func is_producer() -> bool:
	return def()["behavior"] == "produce"


## Herstellungsbetrieb: die Eingangsware ("input").
func input_good() -> String:
	return str(def()["input"])


## Herstellungsbetrieb: so viel Eingangsware verbraucht ein Arbeitsgang ("input_amount").
func input_amount() -> int:
	return int(def()["input_amount"])


## Hof und Herstellungsbetrieb: Takte Arbeit in der Arbeitsstätte je Gang ("work_ticks").
func work_ticks() -> int:
	return int(def()["work_ticks"])


## Hof und Herstellungsbetrieb: das Erzeugnis, das ein Arbeiter nach der Arbeit herausträgt
## ("product").
func product() -> String:
	return str(def()["product"])


## Hof und Herstellungsbetrieb: Tätigkeitstext während der Arbeit, z. B. „mahlt Weizen“
## ("work_text").
func work_text() -> String:
	return str(def()["work_text"])


## Sammler, Hof und Herstellungsbetrieb: so viel trägt ein Arbeiter je Gang höchstens
## ("load"); beim Sammler aus dem Vorkommen entnommen, sonst die Menge des Erzeugnisses.
func carry_load() -> int:
	return int(def()["load"])


## Sammler: Suchradius für Vorkommen als Weglänge ab dem Eingang ("range").
func gather_range() -> int:
	return int(def()["range"])


## Wie viel Wohnraum das Gebäude laut Daten stellt ("housing"): Grundwohnraum beim
## Bergfried, sonst bei Wohnhäusern.
func housing() -> int:
	return int(def().get("housing", 0))


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


## Entnimmt bis zu amount einer Ware, so viel vorrätig ist; liefert die entnommene Menge.
func take(good: String, amount: int) -> int:
	var taken := mini(amount, contents.get(good, 0))
	if taken <= 0:
		return 0
	contents[good] -= taken
	if contents[good] == 0:
		contents.erase(good)
	return taken


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
	return str(_storage_def(storage_type).get("name", storage_type))


## Grund, wenn ein Lager dieser Lagerart fehlt, z. B. „Kein Kornspeicher“: `missing_text` des
## ersten Gebäudetyps (Reihenfolge in den Daten), der Waren dieser Lagerart lagert.
static func storage_missing_text(storage_type: String) -> String:
	var def := _storage_def(storage_type)
	if def.has("missing_text"):
		return str(def["missing_text"])
	return "Kein Lager für %s" % storage_name(storage_type)


## Daten des ersten Gebäudetyps (Reihenfolge in den Daten), der Waren dieser Lagerart lagert;
## leer, wenn es keinen gibt.
static func _storage_def(storage_type: String) -> Dictionary:
	var buildings := GameDefs.get_instance().buildings
	for type_id: String in buildings:
		if storage_type_of(type_id) == storage_type:
			return buildings[type_id]
	return {}


## Die Lagerarten der Waren, in der Reihenfolge ihrer ersten Ware in den Daten.
static func storage_types() -> Array[String]:
	var result: Array[String] = []
	var goods := GameDefs.get_instance().goods
	for good: String in goods:
		var storage_type := str(goods[good]["storage"])
		if not result.has(storage_type):
			result.append(storage_type)
	return result


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
