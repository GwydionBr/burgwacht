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


## Ein Angriff läuft einmal über die Angriffsdauer in Takten; die Abklingzeit kommt aus der Spielwelt.
static func attack_frame(cooldown: int, fraction: float, duration: int, frames: int) -> int:
	var share := (duration - cooldown + fraction) / float(duration)
	return clampi(floori(share * frames), 0, frames - 1)
