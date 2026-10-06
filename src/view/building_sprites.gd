class_name BuildingSprites
extends RefCounted
## Gemeinsame Bildauswahl für Gebäude auf Karte, Bauvorschau und Bauleiste.


## Dieselbe Kachel zeigt immer dieselbe Variante, unabhängig von Spielstand und Zufall.
static func variant(origin: Vector2i, count: int) -> int:
	return posmod(origin.x * 37 + origin.y * 17, maxi(count, 1))


## Einzelbild der Gebäudeschleife aus Spielsekunden; Pause und Zeitraffer bestimmen die Spielzeit.
static func animation_path(entry: Dictionary, seconds: float) -> String:
	var settings: Dictionary = entry.get("sprite_animation", {})
	if settings.is_empty():
		return ""
	return GameDefs.building_animation_path(entry, FigureAnimation.frame(seconds, int(settings["frames"]), float(settings["fps"])))


## Gerenderte Wehrgangfläche unter den Zinnen; ohne verfügbares Sprite gilt die Blockhöhe.
static func walk_height(entry: Dictionary) -> float:
	if entry.has("sprite_walk_height") and ResourceLoader.exists(GameDefs.sprite_path(entry)):
		return float(entry["sprite_walk_height"])
	return float(entry["height"])
