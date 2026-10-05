extends RefCounted
## Aufbau für Startparameter --setup=gallery (Preset „gallery“): jeder Gebäudetyp aus
## data/buildings.json einmal auf leerer Wiese, um Sprites und gezeichnete Gebäude auf einem Bild zu
## vergleichen (ADR 0006). Oben die Burg der Gründung, darunter die übrigen Typen in der Reihenfolge
## der Daten, in Reihen quer über das Bild. Sie stehen ohne Bauregeln und Kosten; ein neuer Typ kommt
## von selbst dazu.

const KEEP_ORIGIN := Vector2i(15, 15)
## Summe x + y der Kachelkoordinaten, auf der die Mitten der ersten Reihe liegen; gleiche Summe heißt
## gleiche Höhe im Bild.
const FIRST_ROW := 50
## Abstand der Reihen (in x + y) und Länge einer Reihe (in x).
const ROW_STEP := 12
const ROW_LENGTH := 24
## Freie Kacheln zwischen zwei Gebäuden einer Reihe.
const GAP := 1


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("gallery")
	var reason := world.execute(Command.found(KEEP_ORIGIN))
	assert(reason == "", "Gründung: " + reason)
	var placed: Dictionary[String, bool] = {}
	for building in world.get_buildings():
		placed[building.type] = true
	var row_sum := FIRST_ROW
	var x := _row_start(row_sum)
	for type_id: String in GameDefs.get_instance().buildings:
		if placed.has(type_id):
			continue
		var size := Building.size_of(type_id).x
		if x + size > _row_start(row_sum) + ROW_LENGTH:
			row_sum += ROW_STEP
			x = _row_start(row_sum)
		# Mitte der Grundfläche auf der Reihe: x + y + size = row_sum.
		helper.place(world, type_id, Vector2i(x, row_sum - size - x))
		x += size + GAP
	return world


## Erste x-Koordinate einer Reihe: die Reihe liegt waagrecht mittig im Bild (x ≈ y).
static func _row_start(row_sum: int) -> int:
	return (row_sum - ROW_LENGTH) / 2
