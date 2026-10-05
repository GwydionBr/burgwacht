class_name MatchStart
extends RefCounted
## Die Startbeschreibung einer Partie: genau eins von Szenario mit Seed, Spielstand oder
## Testaufbau. Hauptmenü und Startparameter füllen nur sie; gestartet wird mit Match.start().

enum Kind { SCENARIO, SAVE, SETUP }

## Größter eintippbarer Seed: so groß wie die zufälligen (randi()).
const MAX_SEED := 4294967295

var kind := Kind.SCENARIO
## Szenario aus dem Szenario-Ordner (nur bei SCENARIO).
var scenario_id := Scenario.DEFAULT
## Fester Seed; ohne ihn gilt der des Szenarios (bei „random“ ein zufälliger).
var map_seed := 0
var has_seed := false
## Warum die Beschreibung nicht gilt (z. B. ein ungültiger --seed); Match.start() meldet es.
var error := ""
## Datei des Spielstands (nur bei SAVE).
var save_path := ""
## Name des Testaufbaus aus tests/setups/ (nur bei SETUP).
var setup_name := ""


## Neue Partie in diesem Szenario mit dessen Seed (bei „random“ ein zufälliger).
static func from_scenario(id: String) -> MatchStart:
	var start := MatchStart.new()
	start.scenario_id = id
	return start


## Neue Partie in diesem Szenario mit festem Seed.
static func from_scenario_with_seed(id: String, seed_value: int) -> MatchStart:
	var start := MatchStart.new()
	start.scenario_id = id
	start.map_seed = seed_value
	start.has_seed = true
	return start


## Neue Partie mit dem eingetippten Seed (Szenarioauswahl); leer oder nur Leerzeichen heißt:
## der Seed des Szenarios (bei „random“ ein zufälliger). Vorher mit seed_error() prüfen.
static func from_seed_text(id: String, text: String) -> MatchStart:
	var trimmed := text.strip_edges()
	return from_scenario(id) if trimmed == "" else from_scenario_with_seed(id, trimmed.to_int())


## Warum der eingetippte Seed nicht geht; leer = in Ordnung. Gültig sind ganze Zahlen von 0 bis
## MAX_SEED. Ohne Eingabe gilt der Seed des Szenarios, außer required verlangt einen (in der
## Szenarioauswahl ist „Seed“ gewählt, beim Startparameter --seed steht einer).
static func seed_error(text: String, required := false) -> String:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return "Seed eintippen oder „Zufällig“ wählen." if required else ""
	var digits_only := trimmed.length() <= str(MAX_SEED).length()
	for character in trimmed:
		digits_only = digits_only and character >= "0" and character <= "9"
	if not digits_only or trimmed.to_int() > MAX_SEED:
		return "Der Seed muss eine ganze Zahl von 0 bis %d sein." % MAX_SEED
	return ""


## Die Partie aus dieser Spielstand-Datei fortsetzen.
static func from_save(path: String) -> MatchStart:
	var start := MatchStart.new()
	start.kind = Kind.SAVE
	start.save_path = path
	return start


## Die Spielwelt aus dem Testaufbau tests/setups/<setup>.gd (für Testzustände).
static func from_setup(setup: String) -> MatchStart:
	var start := MatchStart.new()
	start.kind = Kind.SETUP
	start.setup_name = setup
	return start


## Aus den Startparametern (Name → Wert, siehe main.gd): --load vor --setup vor
## --scenario/--seed. Ein ungültiger --seed steht in `error` (siehe seed_error()).
static func from_args(args: Dictionary) -> MatchStart:
	if args.has("load"):
		return from_save(str(args["load"]))
	if args.has("setup"):
		return from_setup(str(args["setup"]))
	var id := str(args.get("scenario", Scenario.DEFAULT))
	if not args.has("seed"):
		return from_scenario(id)
	var seed_text := str(args["seed"])
	var start := from_seed_text(id, seed_text)
	start.error = seed_error(seed_text, true)
	return start
