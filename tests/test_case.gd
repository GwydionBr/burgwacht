class_name TestCase
extends RefCounted
## Basisklasse für Tests. Jede Methode, die mit "test_" beginnt, wird ausgeführt.

var failures: PackedStringArray = []


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		failures.append(message if message != "" else "Bedingung ist falsch")


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s erwartet %s, war %s" % [message, str(expected), str(actual)])
