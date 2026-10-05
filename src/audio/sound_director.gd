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

## Steht die Zeit (Pause, Spielmenü, Gründung, keine Partie)? Dann entstehen keine
## Spielgeräusche, Bediengeräusche schon. Wird von außen gesetzt.
var time_stands := false

var _data: SoundData
var _rng := RandomNumberGenerator.new()


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


## Wünscht ein Geräusch dieses Anlasses.
func _wish(occasion: String) -> void:
	if _data.error != "":
		return
	var sound := _data.sound(occasion)
	if time_stands and sound.group == SoundData.GROUP_GAME:
		return
	var wish := SoundWish.new()
	wish.occasion = occasion
	wish.variant = _rng.randi_range(0, sound.files.size() - 1)
	wish.volume = sound.volume
	wish.pitch = 1.0 + _rng.randf_range(-_data.pitch_variation, _data.pitch_variation)
	wished.emit(wish)
