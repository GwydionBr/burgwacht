class_name WaveFormula
extends RefCounted
## Die Steigerungsformel eines Wellenplans (Feld "formula" in "waves"): Nach der festen Liste
## kommen endlos weitere Wellen im Abstand "every_days" Tage, je Feindtyp mit abgerundet
## base + growth × n Feinden (n = Nummer der Formelwelle ab 0), alle von zufälliger Seite.
## Form: {"every_days": ganze Zahl ab 1, "enemies": {Feindtyp: {"base": Zahl ab 0, "growth": Zahl ab 0}}}.
## Reine Daten; den Ablauf regelt Waves.

## Abstand zwischen zwei Formelwellen in Tagen (ab 1).
var every_days := 1
## Feindtyp → Anzahl in der ersten Formelwelle (n = 0), in der Reihenfolge des Szenarios.
var base: Dictionary[String, float] = {}
## Feindtyp → Zuwachs je weiterer Formelwelle.
var growth: Dictionary[String, float] = {}


## Die Formelwelle Nummer n (ab 0), wenn die erste an Tag first_day kommt.
func wave(n: int, first_day: int) -> PlannedWave:
	var enemies: Dictionary[String, int] = {}
	for type_id in base:
		enemies[type_id] = floori(base[type_id] + growth[type_id] * n)
	return PlannedWave.create(first_day + n * every_days, enemies)


## Liest die Formel aus dem Feld "formula"; null bei einem Fehler (Gründe mit Feldnamen in problems).
static func parse(value: Variant, problems: PackedStringArray) -> WaveFormula:
	if not value is Dictionary:
		problems.append("„waves“: „formula“ muss ein Objekt sein")
		return null
	var fields: Dictionary = value
	var formula := WaveFormula.new()
	var valid := true
	var every_value: Variant = fields.get("every_days")
	if Scenario._is_whole_number(every_value) and int(every_value) >= 1:
		formula.every_days = int(every_value)
	else:
		problems.append("„waves“: „every_days“ muss eine ganze Zahl ab 1 sein")
		valid = false
	var enemies_value: Variant = fields.get("enemies")
	if not enemies_value is Dictionary:
		problems.append("„waves“: „enemies“ in „formula“ muss ein Objekt Feindtyp → {„base“, „growth“} sein")
		return null
	var entries: Dictionary = enemies_value
	for type_id: Variant in entries:
		if not (type_id is String and FighterType.is_enemy_type(type_id)):
			problems.append("„waves“: unbekannter Feindtyp „%s“ in der Formel" % str(type_id))
			valid = false
			continue
		var entry: Variant = entries[type_id]
		var numbers: Dictionary = entry if entry is Dictionary else {}
		var type_base: Variant = numbers.get("base")
		var type_growth: Variant = numbers.get("growth", 0)
		if not (_is_number(type_base) and float(type_base) >= 0.0 and _is_number(type_growth) and float(type_growth) >= 0.0):
			problems.append("„waves“: „base“ und „growth“ für „%s“ müssen Zahlen ab 0 sein" % str(type_id))
			valid = false
			continue
		formula.base[str(type_id)] = float(type_base)
		formula.growth[str(type_id)] = float(type_growth)
	return formula if valid else null


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"every_days": every_days, "base": base.duplicate(), "growth": growth.duplicate()}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> WaveFormula:
	var formula := WaveFormula.new()
	formula.every_days = int(data["every_days"])
	var bases: Dictionary = data["base"]
	var growths: Dictionary = data["growth"]
	for type_id: Variant in bases:
		formula.base[str(type_id)] = float(bases[type_id])
		formula.growth[str(type_id)] = float(growths[type_id])
	return formula
