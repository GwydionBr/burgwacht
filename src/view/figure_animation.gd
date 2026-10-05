class_name FigureAnimation
extends RefCounted
## Wählt Richtung und Animationsbild aus Bewegung und Spielzeit, ohne Grafik.


## Acht Richtungen in Kachelkoordinaten, beginnend mit +x; stehend bleibt die letzte Richtung.
static func direction(movement: Vector2i, previous: int) -> int:
	if movement == Vector2i.ZERO:
		return previous
	return posmod(roundi(Vector2(movement).angle() / (PI / 4.0)), 8)


## Bild einer Schleife aus Spielsekunden; dieselbe Zeit ergibt auch bei Pause dasselbe Bild.
static func frame(seconds: float, frames: int, fps: float) -> int:
	return posmod(floori(seconds * fps), frames)
