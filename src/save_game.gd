class_name SaveGame
extends RefCounted
## Ein Spielstand, wie ihn SaveGames liefert: der Kopf der Datei und, nach dem Laden, die Spielwelt.
## Beim Auflisten bleibt `world` leer. Ist die Datei beschädigt oder veraltet, steht der Grund in
## `error` (leer = ladbar).

## Benannt (vom Spieler), Schnellspielstand (F5/F9) oder Autospielstand (zu jedem Tagesbeginn).
enum Kind { NAMED, QUICK, AUTO }

## Pfad der Datei.
var path := ""
## Anzeigename; bei Schnell- und Autospielstand fest.
var name := ""
var kind := Kind.NAMED
var scenario_id := ""
## Anzeigename des Szenarios zur Zeit des Speicherns.
var scenario_title := ""
var world_seed := 0
## Tag der Spielwelt beim Speichern.
var day := 0
## Speicherdatum in Unix-Sekunden.
var saved_at := 0.0
## Formatversion der Datei (SaveGames.FORMAT_VERSION) und der Spielwelt (GameWorld.SAVE_VERSION).
var format_version := 0
var world_version := 0
## Die geladene Spielwelt; nur nach SaveGames.read() mit Spielwelt.
var world: GameWorld
## Warum sich der Spielstand nicht laden lässt (leer = ladbar).
var error := ""


## Aus einer früheren Spielversion: wird gelistet, lässt sich aber nicht laden.
func is_outdated() -> bool:
	return format_version != SaveGames.FORMAT_VERSION or world_version != GameWorld.SAVE_VERSION


## Lässt sich laden (weder beschädigt noch veraltet).
func is_loadable() -> bool:
	return error == ""
