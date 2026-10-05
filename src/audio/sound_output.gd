class_name SoundOutput
extends Node
## Die Tonausgabe: eine dünne Schicht, die die Abspielwünsche der Tonregie (`director`) mit einem
## Vorrat an Abspielern auf dem Bus Geräusche abspielt. Entscheidungen trifft sie keine.
##
## Es gibt eine gemeinsame Instanz (shared()), die direkt unter der Wurzel des Baums hängt und so
## zwischen Hauptmenü und Partie bestehen bleibt. Sie meldet der Tonregie jeden gedrückten Knopf
## (alle BaseButton im Baum) und, ob die Zeit der verfolgten Spieluhr steht (follow_clock()).
## Ereignisse der Spielwelt verbindet die Partie-Szene (main.gd) mit `director`.
## Im Zeitraffer bleibt die Tonhöhe, wie sie ist: Die Spieluhr ändert nicht Engine.time_scale.
## Headless (Tests, Rauchtest) läuft sie mit dem Dummy-Audiotreiber, ohne hörbaren Ton.

## So viele Geräusche klingen höchstens zugleich; weitere Wünsche entfallen.
const PLAYER_COUNT := 16

static var _shared: SoundOutput

## Die Tonregie, deren Wünsche diese Ausgabe abspielt.
var director: SoundDirector

var _data: SoundData
## Tondatei → geladener AudioStream (beim ersten Abspielen geladen).
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
## Die Spieluhr der laufenden Partie; ohne (Hauptmenü) steht die Zeit.
var _clock: GameClock


## Die Tonausgabe des laufenden Spiels, beim ersten Aufruf angelegt (Hauptmenü und Partie rufen
## es beim Start).
static func shared() -> SoundOutput:
	if _shared == null:
		var tree := Engine.get_main_loop() as SceneTree
		_shared = SoundOutput.new()
		_shared.name = "SoundOutput"
		tree.root.add_child.call_deferred(_shared)
		tree.node_added.connect(_shared._hook_button)
		_shared._hook_buttons_in(tree.root)
	return _shared


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = SoundData.load_file()
	if _data.error != "":
		push_error("Geräuschdatei %s: %s" % [SoundData.PATH, _data.error])
	director = SoundDirector.new(_data, randi())
	director.wished.connect(_play)
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.SOUND_BUS
		add_child(player)
		_players.append(player)


func _process(_delta: float) -> void:
	director.time_stands = not is_instance_valid(_clock) or _clock.is_time_standing()


## Ab jetzt gilt die Zeit dieser Spieluhr (Partie-Szene beim Start); wird sie freigegeben, steht
## die Zeit wieder.
func follow_clock(clock: GameClock) -> void:
	_clock = clock


func _play(wish: SoundWish) -> void:
	if not is_inside_tree():
		return
	var player := _free_player()
	if player == null:
		return
	var file := _data.file_of(wish.occasion, wish.variant)
	if not _streams.has(file):
		_streams[file] = load(file)
	player.stream = _streams[file]
	player.volume_linear = wish.volume
	player.pitch_scale = wish.pitch
	player.play()


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null


func _hook_button(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node
		if not button.pressed.is_connected(director.button_pressed):
			button.pressed.connect(director.button_pressed)


func _hook_buttons_in(node: Node) -> void:
	_hook_button(node)
	for child in node.get_children():
		_hook_buttons_in(child)
