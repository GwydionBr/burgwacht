class_name Match
extends RefCounted
## Die Partie: startet aus einer Startbeschreibung (MatchStart), hält Spielwelt und Szenario und
## speichert sie als Spielstand (save(), gesperrt in der Gründung und nach der Niederlage).
## Liegt außerhalb des Kerns, weil sie Dateien (Spielstände, Testaufbauten) liest; Darstellung
## und Eingabe verbindet der Einstiegspunkt der Partie-Szene (main.gd) über world_changed.

## Eine neue Spielwelt ist da (Start, neue Karte, geladener Spielstand).
signal world_changed()

var world: GameWorld
## Das Szenario der Spielwelt; aus ihm entsteht auch eine neue Karte (Taste N im Debug-Build).
var scenario: Scenario
## Die Spielstände, in die save() schreibt.
var saves: SaveGames

var _scenario_dir: String


## scenario_dir: woher die Szenarien kommen (Tests nehmen ihre eigenen); save_dir: wohin
## gespeichert wird (Tests und Presets nehmen einen Wegwerf-Ordner).
func _init(scenario_dir := Scenario.DIR, save_dir := SaveGames.DIR) -> void:
	_scenario_dir = scenario_dir
	saves = SaveGames.new(save_dir)


## Startet die Partie neu aus der Beschreibung; liefert den Grund, wenn das nicht geht
## (dann bleibt alles, wie es war).
func start(description: MatchStart) -> String:
	match description.kind:
		MatchStart.Kind.SAVE:
			return _load(description.save_path)
		MatchStart.Kind.SETUP:
			var path := Presets.setup_path(description.setup_name)
			if not ResourceLoader.exists(path):
				return "%s fehlt" % path
			var setup: GDScript = load(path)
			_set_world(setup.call("create"))
			return ""
	var new_scenario := Scenario.load_named(description.scenario_id, _scenario_dir)
	if new_scenario.error != "":
		return new_scenario.error
	scenario = new_scenario
	var world_seed := description.map_seed if description.has_seed else scenario.resolve_seed(randi())
	_set_world(GameWorld.create(scenario, world_seed))
	return ""


## Warum sich die Partie gerade nicht speichern lässt (leer = speicherbar): In der Gründung und
## nach der Niederlage gibt es nichts zu bewahren.
func save_error() -> String:
	if world.is_founding():
		return "Vor der Gründung gibt es nichts zu speichern"
	if world.is_defeated():
		return "Nach der Niederlage gibt es nichts zu speichern"
	return ""


## Speichert die Spielwelt als Spielstand dieser Art (benannte mit Namen); liefert den Fehler
## ("" = gespeichert). Ein gleichnamiger Spielstand wird überschrieben – vorher fragen, siehe
## SaveGames.is_name_taken().
func save(kind: SaveGame.Kind, name := "") -> String:
	var error := save_error()
	if error != "":
		return error
	return saves.save(world, scenario.title, kind, name)


## Vorschlag für den Namen eines Spielstands, z. B. „Freies Spiel – Tag 12“.
func suggested_save_name() -> String:
	return "%s – Tag %d" % [scenario.title, world.get_day()]


## Lädt den Spielstand aus dieser Datei (SaveGames).
func _load(path: String) -> String:
	var save := SaveGames.read(path)
	if save.error != "":
		return save.error
	_set_world(save.world)
	return ""


## Zu jedem Tagesbeginn überschreibt die Partie den Autospielstand; save() lässt das in der
## Gründung und nach der Niederlage aus. Ein Fehler beim Schreiben hält die Partie nicht auf.
func _auto_save(_day: int) -> void:
	if save_error() == "":
		var error := save(SaveGame.Kind.AUTO)
		if error != "":
			printerr("Autospielstand: ", error)


## Übernimmt die Spielwelt samt ihrem Szenario. Kennt der Szenario-Ordner es nicht (Testaufbau
## aus einem Testszenario), entsteht eine neue Karte im Standardszenario.
func _set_world(new_world: GameWorld) -> void:
	world = new_world
	world.day_started.connect(_auto_save)
	if scenario == null or scenario.id != world.get_scenario_id():
		scenario = Scenario.load_named(world.get_scenario_id(), _scenario_dir)
		if scenario.error != "":
			scenario = Scenario.load_named(Scenario.DEFAULT, _scenario_dir)
	world_changed.emit()
