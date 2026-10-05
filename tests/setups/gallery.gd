extends RefCounted
## Aufbau für Startparameter --setup=gallery (Preset „gallery“): jeder Gebäudetyp und alle
## Vorkommen mit jeder Sprite-Variante auf leerer Wiese, um Sprites und gezeichnete Objekte zu
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
	_add_deposits(world)
	return world


## Erste x-Koordinate einer Reihe: die Reihe liegt waagrecht mittig im Bild (x ≈ y).
static func _row_start(row_sum: int) -> int:
	return (row_sum - ROW_LENGTH) / 2


## Alle Vorkommen und jede Sprite-Variante stehen vor der Burg, ohne Zufallsauswahl.
static func _add_deposits(world: GameWorld) -> void:
	var x := 8
	for type_id: String in GameDefs.get_instance().deposits:
		var def: Dictionary = GameDefs.get_instance().deposits[type_id]
		for variant in int(def.get("sprite_variants", 1)):
			# Die Lager der Gründung stehen in der Mitte dieser Reihe.
			if x >= 18 and x < 24:
				x = 24
			var deposit := Deposit.new()
			deposit.type = type_id
			deposit.amount = int(def["amount"])
			deposit.variant = variant
			world.map.deposits[Vector2i(x, 40 - x)] = deposit
			x += 3
