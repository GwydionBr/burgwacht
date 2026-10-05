class_name SoundData
extends RefCounted
## Die Geräuschdatei der Spieldaten (data/sounds.json): je Geräuschanlass die Varianten
## (Tondateien), die Grundlautstärke, ob er ortsabhängig ist und ob er zur Bedienung gehört,
## dazu die Musikstücke nach Musikrolle. Wird beim Laden geprüft; der Grund steht dann auf
## Deutsch in `error`. Liegt außerhalb des Kerns: Die Spielwelt weiß nichts von Ton.

const PATH := "res://data/sounds.json"
## Tondateien stehen in den Daten relativ zu diesem Ordner.
const AUDIO_DIR := "res://assets/audio/"
## Alle Geräuschanlässe; die Tonregie löst sie aus, die Geräuschdatei muss jeden genau einmal
## nennen. Ein neuer Anlass kommt hierher und in die Daten.
const OCCASIONS: Array[String] = [
	# Bedienung
	"button", "building_placed", "demolish", "command_rejected", "recruit", "trade",
	# Wellen und Partie
	"wave_announced", "wave_spawned", "wave_repelled", "defeat",
	# Kampf (ortsabhängig)
	"sword_hit", "arrow_shot", "building_hit", "fighter_died", "building_destroyed",
]
## Gruppe „group“ eines Anlasses: Bediengeräusche klingen auch bei stehender Zeit (Pause,
## Spielmenü), Spielgeräusche nur, wenn die Zeit läuft. Partiesignale (Wellen, Niederlage)
## klingen immer, auch wenn sie bei stehender Zeit kommen (Ankündigung bei der Gründung,
## Debug-Welle in der Pause).
const GROUP_CONTROL := "control"
const GROUP_GAME := "game"
const GROUP_MATCH := "match"
## Die Musikrollen mit Musikstücken in den Daten (Stille braucht keine).
const MUSIC_ROLES: Array[String] = ["menu", "peaceful", "battle"]

## Leer, wenn die Daten gültig sind; sonst der Grund.
var error := ""
## Wie weit die Tonhöhe um 1 schwankt (0.05 = ±5 %).
var pitch_variation := 0.0

## Anlass → Sound
var _sounds: Dictionary = {}
## Musikrolle → Array[String] (volle Pfade)
var _music: Dictionary = {}


## Ein Geräuschanlass aus den Daten.
class Sound:
	extends RefCounted
	## Volle Pfade der Varianten.
	var files: Array[String] = []
	## Grundlautstärke als Faktor (1 = so laut wie die Datei).
	var volume := 1.0
	var positional := false
	var group := GROUP_CONTROL


## Liest und prüft die Geräuschdatei.
static func load_file(path := PATH) -> SoundData:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		var data := SoundData.new()
		data.error = "%s ist kein gültiges JSON" % path
		return data
	return from_dict(json.data)


## Prüft und übernimmt die Daten einer Geräuschdatei.
static func from_dict(raw: Dictionary) -> SoundData:
	var data := SoundData.new()
	data.error = data._read(raw)
	return data


## Zahl der Varianten eines Anlasses.
func variant_count(occasion: String) -> int:
	return sound(occasion).files.size()


## Die Tondatei einer Variante (0 = erste).
func file_of(occasion: String, variant: int) -> String:
	return sound(occasion).files[variant]


## Die Angaben zu einem Anlass aus OCCASIONS.
func sound(occasion: String) -> Sound:
	assert(_sounds.has(occasion), "Unbekannter Geräuschanlass „%s“" % occasion)
	return _sounds[occasion]


## Die Musikstücke einer Rolle aus MUSIC_ROLES (volle Pfade, in der Reihenfolge der Daten).
func music_of(role: String) -> Array[String]:
	assert(_music.has(role), "Unbekannte Musikrolle „%s“" % role)
	return _music[role]


## Liest die Daten ein; liefert den ersten Fehler oder "".
func _read(raw: Dictionary) -> String:
	var pitch: Variant = raw.get("pitch_variation")
	if not _is_number(pitch) or float(pitch) < 0.0 or float(pitch) >= 1.0:
		return "„pitch_variation“ muss eine Zahl von 0 bis unter 1 sein"
	pitch_variation = float(pitch)
	var sounds: Variant = raw.get("sounds")
	if not sounds is Dictionary:
		return "„sounds“ muss ein Objekt mit den Geräuschanlässen sein"
	var sound_entries: Dictionary = sounds
	for occasion: String in sound_entries:
		if not occasion in OCCASIONS:
			return "Unbekannter Geräuschanlass „%s“" % occasion
	for occasion in OCCASIONS:
		if not sound_entries.has(occasion):
			return "Geräuschanlass „%s“ fehlt" % occasion
		var reason := _read_sound(occasion, sound_entries[occasion])
		if reason != "":
			return "Geräuschanlass „%s“: %s" % [occasion, reason]
	var music: Variant = raw.get("music")
	if not music is Dictionary:
		return "„music“ muss ein Objekt mit den Musikrollen sein"
	var music_entries: Dictionary = music
	for role: String in music_entries:
		if not role in MUSIC_ROLES:
			return "Unbekannte Musikrolle „%s“" % role
	for role in MUSIC_ROLES:
		if not music_entries.has(role):
			return "Musikrolle „%s“ fehlt" % role
		var files: Array[String] = []
		var reason := _read_files(music_entries[role], files)
		if reason != "":
			return "Musikrolle „%s“: %s" % [role, reason]
		_music[role] = files
	return ""


## Liest einen Anlass; liefert den Grund, wenn er nicht passt.
func _read_sound(occasion: String, raw: Variant) -> String:
	if not raw is Dictionary:
		return "muss ein Objekt sein"
	var entry: Dictionary = raw
	var result := Sound.new()
	var reason := _read_files(entry.get("files"), result.files)
	if reason != "":
		return reason
	var volume: Variant = entry.get("volume")
	if not _is_number(volume) or float(volume) <= 0.0:
		return "„volume“ muss eine Zahl über 0 sein"
	result.volume = float(volume)
	var positional: Variant = entry.get("positional")
	if not positional is bool:
		return "„positional“ muss true oder false sein"
	result.positional = positional
	var group: Variant = entry.get("group")
	if not group in [GROUP_CONTROL, GROUP_GAME, GROUP_MATCH]:
		return "„group“ muss „%s“, „%s“ oder „%s“ sein" % [GROUP_CONTROL, GROUP_GAME, GROUP_MATCH]
	result.group = group
	_sounds[occasion] = result
	return ""


## Liest eine Liste von Tondateien (relativ zu AUDIO_DIR) als volle Pfade nach files.
static func _read_files(raw: Variant, files: Array[String]) -> String:
	if not raw is Array or (raw as Array).is_empty():
		return "„files“ muss eine nicht leere Liste von Tondateien sein"
	for file: Variant in raw:
		if not file is String:
			return "„files“ muss eine nicht leere Liste von Tondateien sein"
		var path := AUDIO_DIR + str(file)
		# ResourceLoader statt FileAccess: In der exportierten App liegen nur die importierten Dateien.
		if not ResourceLoader.exists(path):
			return "Tondatei %s fehlt" % path
		files.append(path)
	return ""


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
