class_name SoundOutput
extends Node
## Die Tonausgabe: eine dünne Schicht, die die Abspielwünsche der Tonregie (`director`) mit einem
## Vorrat an Abspielern auf dem Bus Geräusche abspielt und die Musik der Musikrolle der Tonregie
## auf dem Bus Musik. Entscheidungen trifft sie keine.
## Jeder Abspieler hat einen eigenen Bus mit Panner (in den Bus Geräusche), so bekommt jedes
## Geräusch sein Panorama. Der Tonregie meldet sie den sichtbaren Ausschnitt und jedes
## ausgeklungene Geräusch.
##
## Wechselt die Musikrolle, blendet sie über (MUSIC_FADE_SECONDS). Die Musikstücke sind im Import
## auf Schleife gestellt; nur die friedlichen spielt sie ohne Schleife, damit nach jedem das
## nächste der Wiedergabeliste kommt (SoundDirector.next_piece()). Die Musik läuft auch bei Pause
## und im Spielmenü weiter.
##
## Es gibt eine gemeinsame Instanz (shared()), die direkt unter der Wurzel des Baums hängt und so
## zwischen Hauptmenü und Partie bestehen bleibt. Sie meldet der Tonregie jeden gedrückten Knopf
## (alle BaseButton im Baum) und, ob die Zeit der verfolgten Spieluhr steht (follow_clock()).
## Ereignisse der Spielwelt verbindet die Partie-Szene (main.gd) mit `director`.
## Im Zeitraffer bleibt die Tonhöhe, wie sie ist: Die Spieluhr ändert nicht Engine.time_scale.
## Headless (Tests, Rauchtest) läuft sie mit dem Dummy-Audiotreiber, ohne hörbaren Ton.

## So viele Geräusche klingen höchstens zugleich; weitere Wünsche entfallen.
const PLAYER_COUNT := 16
## Sekunden, die eine Überblendung beim Wechsel der Musikrolle dauert.
const MUSIC_FADE_SECONDS := 2.0
## Sekunden zwischen dem Anhalten aller Abspieler und dem Beenden (quit()): So lange braucht der
## Audio-Server, um angehaltene Tondateien freizugeben (ein Mischdurchgang und ein Frame).
const QUIT_DELAY_SECONDS := 0.1
const DUMMY_DRIVER := "Dummy"

static var _shared: SoundOutput

## Die Tonregie, deren Wünsche diese Ausgabe abspielt.
var director: SoundDirector

var _data: SoundData
## Tondatei → geladener AudioStream (beim ersten Abspielen geladen).
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
## Je Abspieler der Panner auf seinem Bus und der Wunsch, den er gerade spielt.
var _panners: Array[AudioEffectPanner] = []
var _playing: Array[SoundWish] = []
## Die Spieluhr der laufenden Partie; ohne (Hauptmenü) steht die Zeit.
var _clock: GameClock
## Die Musikrolle, die gerade läuft ("" = noch keine).
var _music_role := ""
## Der Abspieler der laufenden Musik (null bei Stille); ausblendende hängen nur noch bis zum Ende
## ihrer Überblendung im Baum.
var _music: AudioStreamPlayer
## Das laufende Musikstück (Tondatei), damit das nächste nicht dasselbe ist.
var _music_piece := ""
## Verstummt (_silence()): Ab jetzt spielt sie nichts mehr, das Programm endet gleich.
var _silent := false


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
		player.bus = _add_pan_bus("%sPan%d" % [Settings.SOUND_BUS, i])
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)
		_playing.append(null)


func _process(_delta: float) -> void:
	director.time_stands = not is_instance_valid(_clock) or _clock.is_time_standing()
	var viewport := get_viewport()
	director.visible_area = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	var role := director.music_role()
	if role != _music_role:
		_switch_music(role)


## Beendet das Spiel („Beenden“, ⌘Q, Fenster schließen): Erst verstummt aller Ton, dann endet
## das Programm nach QUIT_DELAY_SECONDS. Der Audio-Server gibt angehaltene Geräusche und
## Musikstücke erst im nächsten Mischdurchgang frei; ein sofortiges SceneTree.quit() mitten in
## einem Geräusch meldete sie mit echtem Treiber als „resources still in use“.
func quit() -> void:
	_silence()
	await get_tree().create_timer(QUIT_DELAY_SECONDS, true, false, true).timeout
	get_tree().quit()


## Endet das Programm ohne quit() (etwa mit --quit-after), hält sie wenigstens alle Abspieler an;
## ob der Audio-Server sie dann noch freigibt, ist nicht sicher.
func _exit_tree() -> void:
	_silence()


## Hält jeden Abspieler an (auch ausblendende Musik) und lässt seine Tondatei los.
func _silence() -> void:
	_silent = true
	set_process(false)
	for player: AudioStreamPlayer in find_children("", "AudioStreamPlayer", false, false):
		player.stop()
		player.stream = null


## Ab jetzt gilt die Zeit dieser Spieluhr (Partie-Szene beim Start); wird sie freigegeben, steht
## die Zeit wieder.
func follow_clock(clock: GameClock) -> void:
	_clock = clock


## Legt einen Bus mit Panner an, der in den Bus Geräusche geht, und gibt seinen Namen zurück.
func _add_pan_bus(bus_name: String) -> StringName:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		bus = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, bus_name)
		AudioServer.set_bus_send(bus, Settings.SOUND_BUS)
		AudioServer.add_bus_effect(bus, AudioEffectPanner.new())
	_panners.append(AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner)
	return StringName(bus_name)


func _play(wish: SoundWish) -> void:
	# Der Dummy-Treiber (headless, Screenshots) mischt nicht: Dort bliebe jedes Geräusch ewig
	# „laufend“ und über das Programmende hängen, also spielt sie dort nichts.
	var audible := is_inside_tree() and not _silent and AudioServer.get_driver_name() != DUMMY_DRIVER
	var index := _free_player() if audible else -1
	if index == -1:
		director.sound_finished(wish)
		return
	var player := _players[index]
	# Falls das Ende des vorigen Geräuschs nicht gemeldet wurde, zählt es jetzt als ausgeklungen.
	_on_finished(index)
	_playing[index] = wish
	_panners[index].pan = wish.pan
	player.stream = _stream_of(_data.file_of(wish.occasion, wish.variant))
	player.volume_linear = wish.volume
	player.pitch_scale = wish.pitch
	player.play()


## Blendet die laufende Musik aus und die der neuen Rolle ein (bei Stille keine).
func _switch_music(role: String) -> void:
	_music_role = role
	if _music != null:
		var old := _music
		var fade_out := create_tween()
		fade_out.tween_property(old, "volume_linear", 0.0, MUSIC_FADE_SECONDS)
		fade_out.tween_callback(old.queue_free)
		_music = null
	var piece := director.next_piece(role, _music_piece)
	if piece == "":
		return
	_music = AudioStreamPlayer.new()
	_music.bus = Settings.MUSIC_BUS
	_music.volume_linear = 0.0
	_music.finished.connect(_next_piece.bind(_music))
	add_child(_music)
	_play_piece(piece)
	create_tween().tween_property(_music, "volume_linear", 1.0, MUSIC_FADE_SECONDS)


## Ein Musikstück ist zu Ende (nur friedliche enden): Das nächste der Rolle folgt ohne Überblendung.
func _next_piece(player: AudioStreamPlayer) -> void:
	if player == _music:
		_play_piece(director.next_piece(_music_role, _music_piece))


func _play_piece(piece: String) -> void:
	_music_piece = piece
	var stream: AudioStreamOggVorbis = _stream_of(piece)
	stream.loop = _music_role != SoundData.MUSIC_PEACEFUL
	_music.stream = stream
	# Mit dem Dummy-Audiotreiber (headless, Screenshots) ist nichts zu hören, und ein gestartetes
	# Musikstück gäbe der Audio-Server beim Beenden oft nicht mehr frei (Fehler im Rauchtest).
	# Überblendung und Wiedergabeliste laufen trotzdem durch.
	if not _silent and AudioServer.get_driver_name() != DUMMY_DRIVER:
		_music.play()


func _stream_of(file: String) -> AudioStream:
	if not _streams.has(file):
		_streams[file] = load(file)
	return _streams[file]


## Index eines Abspielers, der gerade nichts spielt; -1, wenn alle belegt sind.
func _free_player() -> int:
	for i in _players.size():
		if not _players[i].playing:
			return i
	return -1


func _on_finished(index: int) -> void:
	if _playing[index] != null:
		director.sound_finished(_playing[index])
		_playing[index] = null


func _hook_button(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node
		if not button.pressed.is_connected(director.button_pressed):
			button.pressed.connect(director.button_pressed)


func _hook_buttons_in(node: Node) -> void:
	_hook_button(node)
	for child in node.get_children():
		_hook_buttons_in(child)
