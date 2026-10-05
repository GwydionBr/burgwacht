class_name SoundDirector
extends RefCounted
## Die Tonregie: bekommt Ereignisse der Bedienung und der Spielwelt und entscheidet, was erklingen
## soll. Heraus kommen Abspielwünsche (Signal `wished`), keine Töne – die spielt die Tonausgabe
## (SoundOutput). Liegt außerhalb des Kerns.
##
## Variante und Tonhöhe wählt ein eigener Zufall, nicht der der Spielwelt (ADR 0001), damit Ton
## den Verlauf nie beeinflusst; für Tests lässt er sich mit einem Seed festlegen.

## Ein Geräusch soll erklingen.
signal wished(wish: SoundWish)

## Musikrollen (music_role()); die ersten drei sind die Rollen der Geräuschdatei.
const MUSIC_MENU := "menu"
const MUSIC_PEACEFUL := "peaceful"
const MUSIC_BATTLE := "battle"
## Keine Musik (nach der Niederlage); braucht keine Musikstücke.
const MUSIC_SILENCE := "silence"
## Ab so viel Abstand (Weltkoordinaten) zum sichtbaren Ausschnitt entfällt ein ortsabhängiges
## Geräusch; bis dahin wird es mit dem Abstand gleichmäßig leiser.
const AUDIBLE_DISTANCE := 1000.0
## So viele ortsabhängige Geräusche eines Anlasses klingen höchstens zugleich; weitere Wünsche
## entfallen, damit viele Schützen im Zeitraffer kein Lärmbrei werden.
const MAX_SIMULTANEOUS := 4

## Steht die Zeit (Pause, Spielmenü, Gründung, keine Partie)? Dann entstehen keine
## Spielgeräusche, Bediengeräusche schon. Wird von außen gesetzt.
var time_stands := false
## Der sichtbare Ausschnitt in Weltkoordinaten (Iso). Ortsabhängige Geräusche darin sind voll
## hörbar. Wird von außen gesetzt.
var visible_area := Rect2()

## Die Spielwelt der laufenden Partie, aus der sich die Musikrolle ergibt; null = Hauptmenü.
## Wird von außen gesetzt, auch nach dem Laden eines Spielstands.
var world: GameWorld

var _data: SoundData
var _rng := RandomNumberGenerator.new()
## Ortsabhängiger Anlass → Zahl seiner Wünsche, die noch klingen (bis sound_finished()).
var _sounding: Dictionary[String, int] = {}
## Gebäude (Instanz-ID, damit kein Gebäude einer früheren Partie verwechselt wird) → zuletzt
## gemeldete Lebenspunkte. Ein Gebäude, das hier fehlt, hatte bisher volle.
var _building_hp: Dictionary[int, int] = {}


## random_seed legt den Zufall für Variante und Tonhöhe fest (Tests); im Spiel ein beliebiger.
## Sind die Daten ungültig (data.error), wünscht die Tonregie nichts.
func _init(data: SoundData, random_seed: int) -> void:
	_data = data
	_rng.seed = random_seed


## Ein Knopf wurde gedrückt, in einem Menü oder in der Partie.
func button_pressed() -> void:
	_wish("button")


## Ein Befehl wurde ausgeführt (Match.command_executed); error ist sein Ergebnis ("" = Erfolg).
## Abgelehnt klingt jeder Befehl gleich, erfolgreich nur Bauen, Abriss, Anwerben und Handel.
func command_executed(command: Command, error: String) -> void:
	if error != "":
		_wish("command_rejected")
		return
	match command.kind:
		Command.Kind.FOUND, Command.Kind.BUILD, Command.Kind.BUILD_LINE:
			_wish("building_placed")
		Command.Kind.DEMOLISH:
			_wish("demolish")
		Command.Kind.RECRUIT:
			_wish("recruit")
		Command.Kind.TRADE:
			_wish("trade")


## Welche Musik gerade laufen soll (MUSIC_*): Menü ohne Partie, Stille nach der Niederlage, Kampf,
## solange mindestens ein Feind lebt, sonst friedlich. Ergibt sich allein aus dem Zustand der
## Spielwelt, gilt also auch gleich nach dem Laden.
func music_role() -> String:
	if world == null:
		return MUSIC_MENU
	if world.is_defeated():
		return MUSIC_SILENCE
	if not world.get_enemies().is_empty():
		return MUSIC_BATTLE
	return MUSIC_PEACEFUL


## Das nächste Musikstück (Tondatei, wie in SoundData.music_of()) dieser Rolle nach previous
## ("" = keins): zufällig, aber nie dasselbe direkt noch einmal, außer die Rolle hat nur eins.
## Leer bei Stille oder ungültigen Daten.
func next_piece(role: String, previous: String) -> String:
	if _data.error != "" or role == MUSIC_SILENCE:
		return ""
	var pieces := _data.music_of(role).duplicate()
	if pieces.size() > 1:
		pieces.erase(previous)
	return pieces[_rng.randi_range(0, pieces.size() - 1)]


## Die Ankündigung einer Welle hat begonnen (GameWorld.wave_announced): Horn.
func wave_announced() -> void:
	_wish("wave_announced")


## Eine Welle ist erschienen (GameWorld.wave_spawned): Trommeln.
func wave_spawned() -> void:
	_wish("wave_spawned")


## Eine Welle ist abgewehrt (GameWorld.wave_repelled): Fanfare, je Welle eine.
func wave_repelled() -> void:
	_wish("wave_repelled")


## Die Partie ist verloren (GameWorld.defeated). Kommt noch im laufenden Takt, klingt also.
func defeated() -> void:
	_wish("defeat")


## Ein gewünschtes Geräusch ist ausgeklungen (oder wurde gar nicht abgespielt). Die Tonausgabe
## meldet das für jeden Wunsch; so zählt die Begrenzung auf MAX_SIMULTANEOUS.
func sound_finished(wish: SoundWish) -> void:
	if _sounding.get(wish.occasion, 0) > 0:
		_sounding[wish.occasion] -= 1


## Ein Fernkämpfer hat von from auf to geschossen (GameWorld.shot_fired): Es sirrt beim Schützen.
func arrow_shot(from: Vector3i, _to: Vector3i) -> void:
	_wish_at("arrow_shot", Vector2(from.x, from.y))


## Die Lebenspunkte eines Gebäudes wurden gemeldet (GameWorld.building_changed): Sind sie
## gesunken, wurde es getroffen, und es kracht in der Mitte seiner Grundfläche.
func building_changed(building: Building) -> void:
	var key := building.get_instance_id()
	var before: int = _building_hp.get(key, building.max_hp())
	_building_hp[key] = building.hp
	if building.hp < before:
		_wish_at("building_hit", _center_of(building))


## Ein Nahkämpfer auf from hat den Kämpfer auf to getroffen (GameWorld.melee_hit): Schwerthieb
## zwischen beiden.
func sword_hit(from: Vector3i, to: Vector3i) -> void:
	_wish_at("sword_hit", (Vector2(from.x, from.y) + Vector2(to.x, to.y)) / 2.0)


## Ein Soldat oder Feind ist auf position gestorben (GameWorld.fighter_died).
func fighter_died(position: Vector3i) -> void:
	_wish_at("fighter_died", Vector2(position.x, position.y))


## Ein Gebäude ist zerstört (GameWorld.building_destroyed, vor dem Entfernen): Es kracht in der
## Mitte seiner Grundfläche, anders als beim Abriss.
func building_destroyed(building: Building) -> void:
	_wish_at("building_destroyed", _center_of(building))


## Die Mitte der Grundfläche (Kachelkoordinaten).
static func _center_of(building: Building) -> Vector2:
	return Vector2(building.origin) + Vector2(Building.size_of(building.type) - Vector2i.ONE) / 2.0


## Wünscht ein ortsabhängiges Geräusch an diesem Punkt (Kachelkoordinaten, auch zwischen
## Kacheln): voll im sichtbaren Ausschnitt, außerhalb mit dem Abstand leiser, ab
## AUDIBLE_DISTANCE gar nicht. Das Panorama folgt der waagerechten Lage im Ausschnitt (Rand =
## ganz links bzw. rechts, außerhalb ebenso). Jeder weitere ortsabhängige Anlass braucht nur
## eine Methode, die dies mit seinem Ort ruft.
func _wish_at(occasion: String, point: Vector2) -> void:
	var position := Iso.point_to_world(point)
	var nearest := position.clamp(visible_area.position, visible_area.end)
	var distance := position.distance_to(nearest)
	if distance >= AUDIBLE_DISTANCE:
		return
	var half_width := maxf(visible_area.size.x / 2.0, 1.0)
	var pan := clampf((position.x - visible_area.get_center().x) / half_width, -1.0, 1.0)
	_wish(occasion, 1.0 - distance / AUDIBLE_DISTANCE, pan)


## Wünscht ein Geräusch dieses Anlasses; volume_factor schwächt es ab (Entfernung), pan legt
## es ins Panorama (-1 links bis 1 rechts).
func _wish(occasion: String, volume_factor := 1.0, pan := 0.0) -> void:
	if _data.error != "":
		return
	var sound := _data.sound(occasion)
	if time_stands and sound.group == SoundData.GROUP_GAME:
		return
	if sound.positional:
		if _sounding.get(occasion, 0) >= MAX_SIMULTANEOUS:
			return
		_sounding[occasion] = _sounding.get(occasion, 0) + 1
	var wish := SoundWish.new()
	wish.occasion = occasion
	wish.variant = _rng.randi_range(0, sound.files.size() - 1)
	wish.volume = sound.volume * volume_factor
	wish.pan = pan
	wish.pitch = 1.0 + _rng.randf_range(-_data.pitch_variation, _data.pitch_variation)
	wished.emit(wish)
