class_name TestCase
extends RefCounted
## Basisklasse für Tests. Jede Methode, die mit "test_" beginnt, wird ausgeführt.

## Test-Szenarien für Simulationstests liegen hier, getrennt von den Spieldaten.
const TEST_SCENARIO_DIR := "res://tests/scenarios/"
## Steht in Tests für den Zufall, wenn ein Szenario einen zufälligen Seed verlangt.
const TEST_RANDOM_SEED := 12345

var failures: PackedStringArray = []


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		failures.append(message if message != "" else "Bedingung ist falsch")


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s erwartet %s, war %s" % [message, str(expected), str(actual)])


## Simulationstest-Hilfe: Test-Szenario laden, Spielwelt mit dem Seed des Szenarios
## erzeugen (zufällig → TEST_RANDOM_SEED) und N Takte laufen lassen.
func run_scenario(scenario_id: String, ticks: int) -> GameWorld:
	var scenario := _load_test_scenario(scenario_id)
	return _run_world(GameWorld.create(scenario, scenario.resolve_seed(TEST_RANDOM_SEED)), ticks)


## Wie run_scenario(), aber der Seed überschreibt den des Szenarios (wie --seed=).
func run_scenario_with_seed(scenario_id: String, ticks: int, world_seed: int) -> GameWorld:
	return _run_world(GameWorld.create(_load_test_scenario(scenario_id), world_seed), ticks)


func _load_test_scenario(scenario_id: String) -> Scenario:
	var scenario := Scenario.load_named(scenario_id, TEST_SCENARIO_DIR)
	assert(scenario.error == "", scenario.error)
	return scenario


func _run_world(world: GameWorld, ticks: int) -> GameWorld:
	for i in ticks:
		world.step()
	return world
