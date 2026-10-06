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
	_add_castle_variants(world)
	_add_terrain(world)

	return world


## Erste x-Koordinate einer Reihe: die Reihe liegt waagrecht mittig im Bild (x ≈ y).
static func _row_start(row_sum: int) -> int:
	return (row_sum - ROW_LENGTH) / 2


## Alle Vorkommen und jede Sprite-Variante stehen vor der Burg, ohne Zufallsauswahl.
static func _add_deposits(world: GameWorld) -> void:
	var row_sum := 27
	for type_id: String in GameDefs.get_instance().deposits:
		var def: Dictionary = GameDefs.get_instance().deposits[type_id]
		var variants := int(def.get("sprite_variants", 1))
		for variant in variants:
			var deposit := Deposit.new()
			deposit.type = type_id
			deposit.amount = int(def["amount"])
			deposit.variant = variant
			var x := (row_sum - 26) / 2 + variant * 2
			world.map.deposits[Vector2i(x, row_sum - x)] = deposit
		row_sum += 5


## Ergänzt die Galerie um reine Ansichtsproben, ohne sie der Spielwelt hinzuzufügen.
static func decorate(scene: Node2D, clock: GameClock) -> void:
	var script: GDScript = load("res://tests/setups/gallery_figures.gd")
	var figures: Node2D = script.new()
	figures.call("setup", clock)
	scene.add_child(figures)
	# Alle Flammenbilder nebeneinander; das Lagerfeuer der Gründung läuft mit der Uhr.
	var fire: Dictionary = GameDefs.get_instance().buildings["campfire"]
	for frame in int(fire["sprite_animation"]["frames"]):
		var flame := Sprite2D.new()
		flame.texture = load(GameDefs.building_animation_path(fire, frame))
		flame.scale = Vector2(0.5, 0.5)
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		flame.position = Iso.tile_to_world(Vector2i(12 + frame, 24 - frame))
		scene.add_child(flame)


## Jede Geländepaarung mit gerader Kante, Ecke und diagonaler Berührung; zuletzt eine Kreuzung.
static func _add_terrain(world: GameWorld) -> void:
	var ids: Array = GameDefs.get_instance().terrain.keys()
	var pair_index: int = 0
	for first: int in ids.size():
		for second: int in range(first + 1, ids.size()):
			var origin_x: int = 4 + (pair_index % 5) * 7
			var origin := Vector2i(origin_x, 34 + (pair_index / 5) * 12 - origin_x)
			for y: int in 6:
				for x: int in 6:
					var type_id: String = str(ids[second] if x >= 3 or y >= 4 else ids[first])
					world.map.set_terrain(origin + Vector2i(x, y), type_id)
			world.map.set_terrain(origin + Vector2i(1, 1), str(ids[second]))
			pair_index += 1
	for y: int in 6:
		for x: int in 8:
			world.map.set_terrain(Vector2i(37 + x, 12 + y), str(ids[(x / 2 + y / 2) % ids.size()]))


## Beide Wohnhausvarianten auf benachbarten Positionen vor der Gründung.
static func _add_castle_variants(world: GameWorld) -> void:
	var helper := TestCase.new()
	helper.place(world, "house", Vector2i(9, 15))
	helper.place(world, "house", Vector2i(12, 15))
