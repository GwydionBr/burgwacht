class_name SaveGames
extends RefCounted
## Die Spielstände in einem Ordner (im Spiel user://saves/, in Tests ein Wegwerf-Ordner):
## speichern, auflisten, laden, löschen. Liegt außerhalb des Kerns, weil es Dateien liest und schreibt.
##
## Eine Datei je Spielstand: Kennung, dann der Kopf (Name, Art, Szenario, Seed, Tag, Speicherdatum,
## Formatversionen), dann die Spielwelt (GameWorld.to_data()). Kopf und Spielwelt stehen je als
## Block aus Länge, SHA-256-Prüfsumme und var_to_bytes()-Daten; so erkennt das Lesen eine beschädigte
## Datei, bevor Godot sie entschlüsselt, und meldet sie, statt abzustürzen. Das Auflisten liest nur
## die Köpfe. Schnell- und Autospielstand haben feste Dateinamen, benannte Spielstände einen aus
## dem Namen abgeleiteten.

const DIR := "user://saves/"
## Erhöhen, wenn sich der Aufbau der Datei ändert; ältere Spielstände gelten dann als veraltet.
## Ändert sich nur die Spielwelt, reicht GameWorld.SAVE_VERSION.
const FORMAT_VERSION := 1
const EXTENSION := ".sav"
## Fester Dateiname und Anzeigename je Art; benannte Spielstände stehen nicht darin, sie leiten
## beides aus dem Namen ab.
const FIXED_KINDS: Dictionary[SaveGame.Kind, Dictionary] = {
	SaveGame.Kind.QUICK: {"file": "quick" + EXTENSION, "name": "Schnellspielstand"},
	SaveGame.Kind.AUTO: {"file": "auto" + EXTENSION, "name": "Autospielstand"},
}
## Vorsilbe benannter Spielstände, damit sie nie mit den festen Dateinamen zusammenfallen.
const NAMED_PREFIX := "named-"
## Längster aus dem Namen abgeleiteter Teil des Dateinamens (Dateisysteme erlauben 255 Bytes).
const MAX_FILE_NAME := 200
const MAGIC := "BURGWACHT"
const HASH_SIZE := 32
const CORRUPT := "Spielstand ist beschädigt"

## Liefert das Speicherdatum in Unix-Sekunden; Tests setzen eine feste Zeit.
var now: Callable = Time.get_unix_time_from_system

var _dir: String


func _init(dir := DIR) -> void:
	_dir = dir if dir.ends_with("/") else dir + "/"


## Speichert die Spielwelt; liefert den Fehler ("" = gespeichert). Ein gleichnamiger Spielstand
## wird überschrieben – vorher fragen, siehe is_name_taken().
func save(world: GameWorld, scenario_title: String, kind := SaveGame.Kind.NAMED, name := "") -> String:
	if kind == SaveGame.Kind.NAMED and name.strip_edges() == "":
		return "Der Spielstand braucht einen Namen"
	var header := {
		"format": FORMAT_VERSION,
		"world_version": GameWorld.SAVE_VERSION,
		"name": _display_name(kind, name.strip_edges()),
		"kind": kind,
		"scenario_id": world.get_scenario_id(),
		"scenario_title": scenario_title,
		"seed": world.get_seed(),
		"day": world.get_day(),
		"saved_at": float(now.call()),
	}
	var made := DirAccess.make_dir_recursive_absolute(_dir)
	if made != OK:
		return "Speichern fehlgeschlagen: %s" % error_string(made)
	var path := path_for(kind, name.strip_edges())
	# Erst vollständig in eine Zwischendatei, damit ein Abbruch den alten Spielstand nicht zerstört.
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error())
	file.store_buffer(MAGIC.to_utf8_buffer())
	_store_block(file, var_to_bytes(header))
	_store_block(file, var_to_bytes(world.to_data()))
	file.close()
	var moved := DirAccess.rename_absolute(temp_path, path)
	if moved != OK:
		return "Speichern fehlgeschlagen: %s" % error_string(moved)
	return ""


## Alle Spielstände des Ordners, der neueste zuerst; liest nur die Köpfe. Beschädigte und
## veraltete stehen mit ihrem Grund in `error` darin, damit man sie sehen und löschen kann.
func list() -> Array[SaveGame]:
	var saves: Array[SaveGame] = []
	if not DirAccess.dir_exists_absolute(_dir):
		return saves
	for file_name in DirAccess.get_files_at(_dir):
		if file_name.ends_with(EXTENSION):
			saves.append(read(_dir + file_name, false))
	saves.sort_custom(func(a: SaveGame, b: SaveGame) -> bool:
		return a.saved_at > b.saved_at if a.saved_at != b.saved_at else a.path < b.path)
	return saves


## Der neueste Spielstand, der sich laden lässt, sonst null (z. B. für „Fortsetzen“).
func newest_loadable() -> SaveGame:
	for save in list():
		if save.is_loadable():
			return save
	return null


## Ob es schon einen benannten Spielstand gibt, den save() mit diesem Namen überschreiben würde.
func is_name_taken(name: String) -> bool:
	return has(SaveGame.Kind.NAMED, name)


## Ob es den Spielstand dieser Art gibt (für benannte: unter diesem Namen), z. B. den
## Schnellspielstand vor F9.
func has(kind: SaveGame.Kind, name := "") -> bool:
	return FileAccess.file_exists(path_for(kind, name.strip_edges()))


## Löscht die Datei des Spielstands (auch beschädigte und veraltete); liefert den Fehler ("" = gelöscht).
func delete(save: SaveGame) -> String:
	var removed := DirAccess.remove_absolute(save.path)
	return "" if removed == OK else "Löschen fehlgeschlagen: %s" % error_string(removed)


## Pfad der Datei für diese Art; benannte Spielstände bekommen einen gültigen Dateinamen aus dem
## Namen (ohne Unterschied von Groß- und Kleinschreibung, wie auf dem Mac).
func path_for(kind: SaveGame.Kind, name := "") -> String:
	if FIXED_KINDS.has(kind):
		return _dir + str(FIXED_KINDS[kind]["file"])
	return _dir + NAMED_PREFIX + name.to_lower().uri_encode().left(MAX_FILE_NAME) + EXTENSION


## Liest den Spielstand aus dieser Datei, mit Spielwelt oder nur den Kopf. Was nicht passt, steht in
## `error` (fehlende, beschädigte oder veraltete Datei); die Spielwelt bleibt dann leer.
static func read(path: String, with_world := true) -> SaveGame:
	var save := SaveGame.new()
	save.path = path
	save.name = path.get_file()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		save.error = "Spielstand nicht gefunden" if not FileAccess.file_exists(path) else CORRUPT
		return save
	if file.get_length() < MAGIC.length() or file.get_buffer(MAGIC.length()).get_string_from_utf8() != MAGIC:
		save.error = CORRUPT
		return save
	var header: Variant = _read_block(file)
	if not header is Dictionary or not _fill_header(save, header):
		save.error = CORRUPT
		return save
	if save.is_outdated():
		save.error = "Spielstand stammt aus einer früheren Spielversion"
		return save
	if not with_world:
		return save
	var data: Variant = _read_block(file)
	if not data is Dictionary:
		save.error = CORRUPT
		return save
	save.error = GameWorld.data_error(data)
	if save.error == "":
		save.world = GameWorld.from_data(data)
	return save


static func _display_name(kind: SaveGame.Kind, name: String) -> String:
	return str(FIXED_KINDS[kind]["name"]) if FIXED_KINDS.has(kind) else name


static func _store_block(file: FileAccess, bytes: PackedByteArray) -> void:
	file.store_32(bytes.size())
	file.store_buffer(_hash(bytes))
	file.store_buffer(bytes)


## Die Daten des nächsten Blocks oder null, wenn er nicht vollständig ist oder die Prüfsumme
## nicht stimmt.
static func _read_block(file: FileAccess) -> Variant:
	if file.get_length() - file.get_position() < 4 + HASH_SIZE:
		return null
	var size := file.get_32()
	var expected_hash := file.get_buffer(HASH_SIZE)
	if file.get_length() - file.get_position() < size:
		return null
	var bytes := file.get_buffer(size)
	if _hash(bytes) != expected_hash:
		return null
	return bytes_to_var(bytes)


static func _hash(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()


## Übernimmt den Kopf; false, wenn er nicht zu lesen ist. Bei anderer Formatversion zählt nur die
## Version (der Spielstand ist veraltet), die übrigen Felder werden übernommen, soweit sie passen.
static func _fill_header(save: SaveGame, header: Dictionary) -> bool:
	if not header.get("format") is int:
		return false
	save.format_version = header["format"]
	var complete := true
	for field: Array in [["world_version", TYPE_INT], ["name", TYPE_STRING], ["kind", TYPE_INT],
			["scenario_id", TYPE_STRING], ["scenario_title", TYPE_STRING], ["seed", TYPE_INT],
			["day", TYPE_INT], ["saved_at", TYPE_FLOAT]]:
		var value: Variant = header.get(field[0])
		if typeof(value) != field[1]:
			complete = false
			continue
		match field[0]:
			"world_version": save.world_version = value
			"name": save.name = value
			"kind": save.kind = clampi(value, 0, SaveGame.Kind.size() - 1) as SaveGame.Kind
			"scenario_id": save.scenario_id = value
			"scenario_title": save.scenario_title = value
			"seed": save.world_seed = value
			"day": save.day = value
			"saved_at": save.saved_at = value
	return complete or save.format_version != FORMAT_VERSION
