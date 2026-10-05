class_name Match
extends RefCounted
## Die Partie: startet aus einer Startbeschreibung (MatchStart) und hält Spielwelt und Szenario.
## Liegt außerhalb des Kerns, weil sie Dateien (Spielstände, Testaufbauten) liest; Darstellung
## und Eingabe verbindet der Einstiegspunkt der Partie-Szene (main.gd) über world_changed.

## Eine neue Spielwelt ist da (Start, neue Karte, geladener Spielstand).
signal world_changed()

var world: GameWorld
## Das Szenario der Spielwelt; aus ihm entsteht auch eine neue Karte (Taste N im Debug-Build).
var scenario: Scenario

var _scenario_dir: String


## scenario_dir: woher die Szenarien kommen (Tests nehmen ihre eigenen).
func _init(scenario_dir := Scenario.DIR) -> void:
	_scenario_dir = scenario_dir


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


## Lädt den Spielstand aus dieser Datei (SaveGames).
func _load(path: String) -> String:
	var save := SaveGames.read(path)
	if save.error != "":
		return save.error
	_set_world(save.world)
	return ""


## Übernimmt die Spielwelt samt ihrem Szenario. Kennt der Szenario-Ordner es nicht (Testaufbau
## aus einem Testszenario), entsteht eine neue Karte im Standardszenario.
func _set_world(new_world: GameWorld) -> void:
	world = new_world
	if scenario == null or scenario.id != world.get_scenario_id():
		scenario = Scenario.load_named(world.get_scenario_id(), _scenario_dir)
		if scenario.error != "":
			scenario = Scenario.load_named(Scenario.DEFAULT, _scenario_dir)
	world_changed.emit()
