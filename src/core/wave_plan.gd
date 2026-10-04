class_name WavePlan
extends RefCounted
## Der Wellenplan eines Szenarios (Feld "waves"): wann welche Wellen mit welchen Feinden von wo
## kommen. Bisher nur die feste Liste ("list"): Einträge {"day": Tag ab 1, "enemies": {Feindtyp:
## Anzahl}, "side": optional "north"/"east"/"south"/"west"}, Tage aufsteigend (gleiche erlaubt).
## Fehlt das Feld, kommen keine Wellen. Dazu die Vorwarnzeit ("warning_days", optional, ganze
## Tage ab 0, Standard 1): So lange vor ihrem Erscheinen wird die nächste Welle angekündigt.
## Reine Daten; den Ablauf regelt Waves.

## Vorwarnzeit, wenn das Szenario keine angibt.
const DEFAULT_WARNING_DAYS := 1

## Die feste Liste: Welle Nummer n (ab 1) ist list[n - 1].
var list: Array[PlannedWave] = []
## So viele Tage vor ihrem Erscheinen beginnt die Ankündigung der nächsten Welle.
var warning_days := DEFAULT_WARNING_DAYS


## Liest den Wellenplan aus dem Szenariofeld "waves"; jeder Fehler kommt als Grund mit dem
## Feldnamen nach problems.
static func parse(value: Variant, problems: PackedStringArray) -> WavePlan:
	var plan := WavePlan.new()
	if not value is Dictionary:
		problems.append("„waves“ muss ein Objekt sein")
		return plan
	var fields: Dictionary = value
	var warning_value: Variant = fields.get("warning_days", DEFAULT_WARNING_DAYS)
	if not Scenario._is_whole_number(warning_value) or int(warning_value) < 0:
		problems.append("„waves“: „warning_days“ muss eine ganze Zahl ab 0 sein")
	else:
		plan.warning_days = int(warning_value)
	var list_value: Variant = fields.get("list", [])
	if not list_value is Array:
		problems.append("„waves“: „list“ muss eine Liste sein")
		return plan
	var entries: Array = list_value
	var last_day := 1
	for entry: Variant in entries:
		var wave := _parse_wave(entry, problems)
		if wave == null:
			continue
		if wave.day < last_day:
			problems.append("„waves“: Die Tage der Liste müssen aufsteigend sein (Tag %d nach Tag %d)" % [wave.day, last_day])
		last_day = maxi(last_day, wave.day)
		plan.list.append(wave)
	return plan


## Ein Eintrag der Liste oder null (Gründe in problems).
static func _parse_wave(entry: Variant, problems: PackedStringArray) -> PlannedWave:
	if not entry is Dictionary:
		problems.append("„waves“: Jeder Eintrag der Liste muss ein Objekt sein")
		return null
	var fields: Dictionary = entry
	var valid := true
	var day_value: Variant = fields.get("day")
	if not Scenario._is_whole_number(day_value) or int(day_value) < 1:
		problems.append("„waves“: „day“ muss eine ganze Zahl ab 1 sein")
		valid = false
	var side_value: Variant = fields.get("side", "")
	if fields.has("side") and not (side_value is String and Waves.SIDES.has(side_value)):
		problems.append("„waves“: „side“ muss eine von %s sein, nicht „%s“" % [", ".join(Waves.SIDES), str(side_value)])
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
			elif not Scenario._is_whole_number(count) or int(count) < 0:
				problems.append("„waves“: Anzahl für „%s“ muss eine ganze Zahl ab 0 sein" % str(type_id))
				valid = false
			else:
				enemies[str(type_id)] = int(count)
	return PlannedWave.create(int(day_value), enemies, str(side_value)) if valid else null


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {
		"list": list.map(func(wave: PlannedWave) -> Dictionary: return wave.to_data()),
		"warning_days": warning_days,
	}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> WavePlan:
	var plan := WavePlan.new()
	for entry: Dictionary in data["list"]:
		plan.list.append(PlannedWave.from_data(entry))
	plan.warning_days = int(data["warning_days"])
	return plan
