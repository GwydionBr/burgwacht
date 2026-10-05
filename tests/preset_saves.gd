extends RefCounted
## Spielstände für Testzustände (--saves=demo, siehe Presets.save_games_for()): je ein benannter,
## Schnell- und Autospielstand im Freien Spiel und ein veralteter, mit Speicherdaten kurz vor
## jetzt. Dazu das Umschreiben des Kopfs, mit dem auch die Tests veraltete Spielstände bauen.

const SEED := 1


## Füllt den (leeren Wegwerf-)Ordner mit den Spielständen der Testzustände.
static func fill(saves: SaveGames) -> void:
	var scenario := Scenario.load_named(Scenario.DEFAULT)
	var world := GameWorld.create(scenario, SEED)
	world.execute(Command.found(world.find_founding_site()))
	var now := Time.get_unix_time_from_system()
	_save_at(saves, now - 3 * 86400.0, world, scenario, SaveGame.Kind.NAMED, "Erste Burg")
	rewrite_header(saves.path_for(SaveGame.Kind.NAMED, "Erste Burg"), {"world_version": GameWorld.SAVE_VERSION - 1})
	_save_at(saves, now - 26 * 3600.0, world, scenario, SaveGame.Kind.NAMED, "Burg am Waldrand")
	for i in GameWorld.TICKS_PER_DAY:
		world.step()
	_save_at(saves, now - 3600.0, world, scenario, SaveGame.Kind.AUTO)
	_save_at(saves, now - 20 * 60.0, world, scenario, SaveGame.Kind.NAMED, "%s – Tag %d" % [scenario.title, world.get_day()])
	for i in GameWorld.TICKS_PER_DAY / 2:
		world.step()
	_save_at(saves, now - 5 * 60.0, world, scenario, SaveGame.Kind.QUICK)


static func _save_at(saves: SaveGames, time: float, world: GameWorld, scenario: Scenario,
		kind: SaveGame.Kind, name := "") -> void:
	saves.now = func() -> float: return time
	var error := saves.save(world, scenario.title, kind, name)
	assert(error == "", error)
	saves.now = Time.get_unix_time_from_system


## Schreibt den Kopf des Spielstands neu, als stammte er aus einer anderen Spielversion.
static func rewrite_header(path: String, changes: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	file.get_buffer(SaveGames.MAGIC.length())
	var size := file.get_32()
	file.get_buffer(SaveGames.HASH_SIZE)
	var header: Dictionary = bytes_to_var(file.get_buffer(size))
	var rest := file.get_buffer(file.get_length() - file.get_position())
	file.close()
	header.merge(changes, true)
	var bytes := var_to_bytes(header)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(SaveGames.MAGIC.to_utf8_buffer())
	file.store_32(bytes.size())
	file.store_buffer(context.finish())
	file.store_buffer(bytes)
	file.store_buffer(rest)
	file.close()
