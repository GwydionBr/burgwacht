class_name WavePlan
extends RefCounted
## Der Wellenplan eines Szenarios (Feld "waves"): wann welche Wellen mit welchen Feinden von wo
## kommen. Zuerst die feste Liste ("list"): Einträge {"day": Tag ab 1, "enemies": {Feindtyp:
## Anzahl}, "side": optional "north"/"east"/"south"/"west"}, Tage streng aufsteigend (höchstens eine Welle
## je Tag).
## Danach endlos die Steigerungsformel ("formula", siehe WaveFormula), falls angegeben. Ist die
## Liste leer, kommt die erste Formelwelle nach der Schonfrist ("grace_days", Standard 0) an Tag
## grace_days + 1. Dazu die Vorwarnzeit ("warning_days", ganze Tage ab 0, Standard 1): So lange
## vor ihrem Erscheinen wird die nächste Welle angekündigt.
## Fehlt das Feld, kommen keine Wellen. Reine Daten; den Ablauf regelt Waves.

## Vorwarnzeit, wenn das Szenario keine angibt.
const DEFAULT_WARNING_DAYS := 1

## Die feste Liste: Welle Nummer n (ab 1) ist list[n - 1].
var list: Array[PlannedWave] = []
## Die Steigerungsformel nach der Liste; null = nach der Liste kommt nichts mehr.
var formula: WaveFormula = null
## Die Schonfrist in Tagen; gilt nur, wenn die Liste leer ist.
var grace_days := 0
## So viele Tage vor ihrem Erscheinen beginnt die Ankündigung der nächsten Welle.
var warning_days := DEFAULT_WARNING_DAYS


## Die Welle mit dieser Nummer (ab 1); null, wenn keine mehr kommt. Die erste Formelwelle kommt
## every_days nach der letzten Listenwelle, ohne Liste an Tag grace_days + 1.
func wave(number: int) -> PlannedWave:
	if number <= list.size():
		return list[number - 1]
	if formula == null:
		return null
	var first_day := grace_days + 1
	if not list.is_empty():
		var last: PlannedWave = list.back()
		first_day = last.day + formula.every_days
	return formula.wave(number - list.size() - 1, first_day)


## Liest den Wellenplan aus dem Szenariofeld "waves"; jeder Fehler kommt als Grund mit dem
## Feldnamen nach problems.
static func parse(value: Variant, problems: PackedStringArray) -> WavePlan:
	var plan := WavePlan.new()
	if not value is Dictionary:
		problems.append("„waves“ muss ein Objekt sein")
		return plan
	var fields: Dictionary = value
	var list_value: Variant = fields.get("list", [])
	if not list_value is Array:
		problems.append("„waves“: „list“ muss eine Liste sein")
		return plan
	var entries: Array = list_value
	var last_day := 0
	for entry: Variant in entries:
		var listed := _parse_wave(entry, problems)
		if listed == null:
			continue
		# Streng aufsteigend: Angekündigt wird nur die nächste Welle, zwei am selben Tag ließen
		# eine unangekündigt.
		if listed.day <= last_day:
			problems.append("„waves“: Die Tage der Liste müssen streng aufsteigend sein (Tag %d nach Tag %d)" % [listed.day, last_day])
		last_day = maxi(last_day, listed.day)
		plan.list.append(listed)
	var grace_value: Variant = fields.get("grace_days", 0)
	if Scenario.is_whole_number_from(grace_value, 0):
		plan.grace_days = int(grace_value)
	else:
		problems.append("„waves“: „grace_days“ muss eine ganze Zahl ab 0 sein")
	var warning_value: Variant = fields.get("warning_days", DEFAULT_WARNING_DAYS)
	if Scenario.is_whole_number_from(warning_value, 0):
		plan.warning_days = int(warning_value)
	else:
		problems.append("„waves“: „warning_days“ muss eine ganze Zahl ab 0 sein")
	if fields.has("formula"):
		plan.formula = WaveFormula.parse(fields["formula"], problems)
	return plan


## Ein Eintrag der Liste oder null (Gründe in problems).
static func _parse_wave(entry: Variant, problems: PackedStringArray) -> PlannedWave:
	if not entry is Dictionary:
		problems.append("„waves“: Jeder Eintrag der Liste muss ein Objekt sein")
		return null
	var fields: Dictionary = entry
	var valid := true
	var day_value: Variant = fields.get("day")
	if not Scenario.is_whole_number_from(day_value, 1):
		problems.append("„waves“: „day“ muss eine ganze Zahl ab 1 sein")
		valid = false
	var side_value: Variant = fields.get("side", "")
	if fields.has("side") and not (side_value is String and MapSide.is_side(side_value)):
		problems.append("„waves“: „side“ muss eine von %s sein, nicht „%s“" % [", ".join(MapSide.all()), str(side_value)])
		valid = false
	var enemies: Dictionary[String, int] = {}
	var enemies_value: Variant = fields.get("enemies")
	if not enemies_value is Dictionary:
		problems.append("„waves“: „enemies“ muss ein Objekt Feindtyp → Anzahl sein")
		valid = false
	else:
		var counts: Dictionary = enemies_value
		for type_id: Variant in counts:
			var count: Variant = counts[type_id]
			if not (type_id is String and FighterType.is_enemy_type(type_id)):
				problems.append("„waves“: unbekannter Feindtyp „%s“" % str(type_id))
				valid = false
			elif not Scenario.is_whole_number_from(count, 0):
				problems.append("„waves“: Anzahl für „%s“ muss eine ganze Zahl ab 0 sein" % str(type_id))
				valid = false
			else:
				enemies[str(type_id)] = int(count)
	return PlannedWave.create(int(day_value), enemies, str(side_value)) if valid else null


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {
		"list": list.map(func(listed: PlannedWave) -> Dictionary: return listed.to_data()),
		"formula": formula.to_data() if formula != null else {},
		"grace_days": grace_days,
		"warning_days": warning_days,
	}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> WavePlan:
	var plan := WavePlan.new()
	for entry: Dictionary in data["list"]:
		plan.list.append(PlannedWave.from_data(entry))
	plan.grace_days = int(data["grace_days"])
	plan.warning_days = int(data["warning_days"])
	var formula_data: Dictionary = data["formula"]
	if not formula_data.is_empty():
		plan.formula = WaveFormula.from_data(formula_data)
	return plan
