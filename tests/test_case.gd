class_name TestCase
extends RefCounted
## Basisklasse für Tests. Jede Methode, die mit "test_" beginnt, wird ausgeführt.

## Test-Szenarien für Simulationstests liegen hier, getrennt von den Spieldaten.
const TEST_SCENARIO_DIR := "res://tests/scenarios/"
## Steht in Tests für den Zufall, wenn ein Szenario einen zufälligen Seed verlangt.
const TEST_RANDOM_SEED := 12345

var failures: PackedStringArray = []
## Zahl der ausgeführten Prüfungen; ein Test ganz ohne Prüfung gilt als fehlgeschlagen.
var checks := 0


func assert_true(condition: bool, message := "") -> void:
	checks += 1
	if not condition:
		failures.append(message if message != "" else "Bedingung ist falsch")


func assert_false(condition: bool, message := "") -> void:
	checks += 1
	if condition:
		failures.append(message if message != "" else "Bedingung ist wahr")


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s erwartet %s, war %s" % [message, str(expected), str(actual)])


## Simulationstest-Hilfe: Test-Szenario laden, Spielwelt mit dem Seed des Szenarios
## erzeugen (zufällig → TEST_RANDOM_SEED), an der ersten passenden Stelle gründen
## und N Takte laufen lassen.
func run_scenario(scenario_id: String, ticks: int) -> GameWorld:
	return _run_world(found_castle(new_world(scenario_id)), ticks)


## Wie run_scenario(), aber der Seed überschreibt den des Szenarios (wie --seed=).
func run_scenario_with_seed(scenario_id: String, ticks: int, world_seed: int) -> GameWorld:
	return _run_world(found_castle(GameWorld.create(_load_test_scenario(scenario_id), world_seed)), ticks)


## Neue Spielwelt aus einem Test-Szenario, noch in Gründung.
func new_world(scenario_id: String) -> GameWorld:
	var scenario := _load_test_scenario(scenario_id)
	return GameWorld.create(scenario, scenario.resolve_seed(TEST_RANDOM_SEED))


## Welt aus einem Test-Szenario (Standard: tiny) in Gründung, aber leergeräumt: nur Wiese,
## keine Vorkommen.
func empty_world(scenario_id := "tiny") -> GameWorld:
	return clear_map(new_world(scenario_id))


## Räumt die Karte einer Welt in Gründung leer: nur Wiese, keine Vorkommen.
func clear_map(world: GameWorld) -> GameWorld:
	world.map.deposits.clear()
	for y in world.map.height:
		for x in world.map.width:
			world.map.set_terrain(Vector2i(x, y), "grass")
	return world


## Gründet die Burg an der passenden Stelle nächst der Kartenmitte.
func found_castle(world: GameWorld) -> GameWorld:
	var site := world.find_founding_site()
	var reason := world.execute(Command.found(site))
	assert(reason == "", "Gründung bei %s fehlgeschlagen: %s" % [str(site), reason])
	return world


## Ursprung des Gebäudes dieses Typs, das bei einer Gründung mit dem Bergfried bei
## keep_origin entsteht (aus GameWorld.founding_buildings()).
func founding_origin(world: GameWorld, type_id: String, keep_origin: Vector2i) -> Vector2i:
	for part in world.founding_buildings(keep_origin):
		if part[0] == type_id:
			return part[1]
	assert(false, "„%s“ entsteht nicht bei der Gründung" % type_id)
	return GameWorld.NO_SITE


## Der erste Ursprung (zeilenweise), an dem ein Gebäude dieses Typs gebaut werden darf –
## bzw. an dem build_error() genau reason liefert; sonst GameWorld.NO_SITE.
func find_site(world: GameWorld, type_id: String, reason := "") -> Vector2i:
	for y in world.map.height:
		for x in world.map.width:
			if world.build_error(type_id, Vector2i(x, y)) == reason:
				return Vector2i(x, y)
	return GameWorld.NO_SITE


## Baut ein Gebäude per Befehl (muss gelingen) und liefert seine ID.
func build(world: GameWorld, type_id: String, origin: Vector2i) -> int:
	var reason := world.execute(Command.build(type_id, origin))
	assert(reason == "", "Bauen von %s fehlgeschlagen: %s" % [type_id, reason])
	return world.get_building_at(origin).id


## Testvorbereitung: legt eine Menge einer Ware direkt in ein Lager (0 = entfernen),
## ohne Befehl – solange es noch keine Arbeiter gibt, die Waren bringen.
func put_goods(world: GameWorld, building_id: int, good: String, amount: int) -> void:
	var contents := world.get_building(building_id).contents
	if amount == 0:
		contents.erase(good)
	else:
		contents[good] = amount


## Testvorbereitung: setzt ein Vorkommen dieses Typs auf die Kachel.
func add_deposit(world: GameWorld, tile: Vector2i, type_id: String) -> void:
	world.map.add_deposit(tile, Deposit.create(type_id, RandomNumberGenerator.new()))


## Testvorbereitung: Ein Feind dieses Typs (aus der Welle mit dieser Nummer, 0 = keiner) erscheint
## auf der Kachel (wie einer aus dem Szenario) und läuft gleich zum Bergfried.
func add_enemy(world: GameWorld, type_id: String, tile: Vector2i, wave := 0) -> Enemy:
	return world._combat().add_enemy(type_id, tile, wave)


## Testvorbereitung: Ein tödlicher Treffer für den Feind, als hätte ihn ein Soldat getroffen.
func kill_enemy(world: GameWorld, enemy: Enemy) -> void:
	enemy.hp = 0
	world._combat().enemy_hit(enemy)


## Testvorbereitung: Felsen rechts neben einem Steinbruch (3×3) mit diesem Ursprung,
## damit seine Bauregel gilt.
func add_rock_for_quarry(world: GameWorld, origin: Vector2i) -> void:
	add_deposit(world, origin + Vector2i(3, 1), "stone")


## Alles, was eine Spielwelt bisher ausmacht, als vergleichbare Daten
## (Vorkommen nach Kachel sortiert, Gebäude nach ID).
func world_snapshot(world: GameWorld) -> Dictionary:
	var map := world.map
	var terrain: Array[String] = []
	for y in map.height:
		for x in map.width:
			terrain.append(map.get_terrain(Vector2i(x, y)))
	var deposits: Array[Array] = []
	var tiles: Array[Vector2i] = map.deposits.keys()
	tiles.sort()
	for tile: Vector2i in tiles:
		var deposit := map.deposits[tile]
		deposits.append([tile, deposit.type, deposit.amount, deposit.variant])
	var buildings: Array[Dictionary] = []
	for building in world.get_buildings():
		buildings.append(building.to_data())
	var residents: Array[Dictionary] = []
	for resident in world.get_residents():
		residents.append(resident.to_data())
	var enemies: Array[Dictionary] = []
	for enemy in world.get_enemies():
		enemies.append(enemy.to_data())
	var stock: Dictionary[String, int] = {}
	for good: String in GameDefs.get_instance().goods:
		stock[good] = world.get_stock(good)
	var factors: Array[Dictionary] = []
	for factor in world.get_factors():
		factors.append(factor.to_data())
	return {
		"tick": world.get_tick(), "size": Vector2i(map.width, map.height), "terrain": terrain, "deposits": deposits,
		"founding": world.is_founding(), "defeated": world.is_defeated(), "buildings": buildings, "stock": stock, "residents": residents,
		"enemies": enemies, "next_wave": world.get_next_wave(), "repelled_waves": world.get_repelled_waves(),
		"announcement": [world.get_announced_side(), world.get_announced_tile(), world.get_announced_ticks()],
		"popularity": world.get_popularity(), "ration": world.get_ration(), "eaten_ration": world.get_eaten_ration(),
		"short_of_food": world.is_short_of_food(), "treasury": world.get_treasury(), "tax_rate": world.get_tax_rate(),
		"factors": factors, "population": world.get_population(), "migration_ticks": world.get_migration_ticks(),
	}


func _load_test_scenario(scenario_id: String) -> Scenario:
	var scenario := Scenario.load_named(scenario_id, TEST_SCENARIO_DIR)
	assert(scenario.error == "", scenario.error)
	return scenario


func _run_world(world: GameWorld, ticks: int) -> GameWorld:
	for i in ticks:
		world.step()
	return world
