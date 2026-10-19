class_name ScenarioGoal
extends RefCounted
## Eine Bedingung des Szenarioziels. Alle Bedingungen müssen gleichzeitig erfüllt sein.
## Beschreibung und Hilfetext kommen aus den Szenariodaten; Fortschritt aus der Spielwelt.

## Art der Bedingung: Gebäudezahl, Bewohnerzahl oder abgewehrte Wellen.
var kind: String
## Gebäudetyp, nur für Gebäudebedingungen verwendet.
var type: String
## Benötigte Anzahl; muss positiv und ganzzahlig sein.
var amount: int
## Beschreibung der Bedingung in der Zielanzeige.
var text: String
## Optionaler Hinweis, solange die Bedingung nicht erfüllt ist.
var hint: String


## Liest die Bedingungen und hängt Validierungsfehler an problems an.
## Fehlerhafte Objekte bleiben im Ergebnis; der Aufrufer muss bei Fehlern das Szenario ablehnen.
## Nicht-Objekte werden übersprungen. Spielstände liefern bereits geprüfte Daten.
static func parse(value: Variant, problems: PackedStringArray) -> Array[ScenarioGoal]:
	var result: Array[ScenarioGoal] = []
	if not value is Array:
		problems.append("„goals“ muss eine Liste sein")
		return result
	var entries: Array = value
	for entry: Variant in entries:
		if not entry is Dictionary:
			problems.append("Jede Zielbedingung muss ein Objekt sein")
			continue
		var data: Dictionary = entry
		var goal := ScenarioGoal.new()
		goal.kind = str(data.get("kind", ""))
		goal.type = str(data.get("type", ""))
		goal.text = str(data.get("text", ""))
		goal.hint = str(data.get("hint", ""))
		if goal.kind not in ["building", "population", "repelled_waves"]:
			problems.append("Unbekannte Zielbedingung „%s“" % goal.kind)
		if goal.kind == "building" and not GameDefs.get_instance().buildings.has(goal.type):
			problems.append("Unbekannter Gebäudetyp im Ziel „%s“" % goal.type)
		if not Scenario.is_whole_number_from(data.get("amount"), 1):
			problems.append("Zielbedingung braucht „amount“ als ganze Zahl größer als 0")
		else:
			goal.amount = int(data["amount"])
		if not data.get("text") is String or goal.text.strip_edges() == "":
			problems.append("Zielbedingung braucht einen Text")
		if not data.get("hint", "") is String:
			problems.append("Zielhinweis muss ein Text sein")
		result.append(goal)
	return result


## Aktuelle Anzahl in der Spielwelt, auch oberhalb des geforderten amount;
## abgerissene oder zerstörte Gebäude zählen nicht mehr.
func progress(world: GameWorld) -> int:
	match kind:
		"population":
			return world.get_population()
		"repelled_waves":
			return world.get_repelled_waves()
		"building":
			var count := 0
			for building in world.get_buildings():
				if building.type == type:
					count += 1
			return count
	return 0


func to_data() -> Dictionary:
	return {"kind": kind, "type": type, "amount": amount, "text": text, "hint": hint}
