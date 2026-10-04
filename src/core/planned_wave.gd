class_name PlannedWave
extends RefCounted
## Eine Welle, wie sie der Wellenplan vorsieht: an welchem Tag, welche Feinde (Typ → Anzahl) und
## von welcher Seite (leer = der Zufall der Spielwelt wählt sie). Reine Daten.

## Absoluter Tag, an dessen Beginn die Welle erscheint (ab 1).
var day: int
## Feindtyp aus units.json → Anzahl, in der Reihenfolge der Datei; in dieser Reihenfolge erscheinen sie.
var enemies: Dictionary[String, int] = {}
## Eine Seite aus Waves.SIDES oder leer.
var side := ""


static func create(wave_day: int, wave_enemies: Dictionary[String, int], wave_side := "") -> PlannedWave:
	var wave := PlannedWave.new()
	wave.day = wave_day
	wave.enemies = wave_enemies.duplicate()
	wave.side = wave_side
	return wave


## Als reine Daten für den Spielstand.
func to_data() -> Dictionary:
	return {"day": day, "enemies": enemies.duplicate(), "side": side}


## Gegenstück zu to_data().
static func from_data(data: Dictionary) -> PlannedWave:
	var wave_enemies: Dictionary[String, int] = {}
	var entries: Dictionary = data["enemies"]
	for type_id: Variant in entries:
		wave_enemies[str(type_id)] = int(entries[type_id])
	return create(int(data["day"]), wave_enemies, str(data["side"]))
