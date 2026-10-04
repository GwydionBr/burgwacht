class_name WaveMarker
extends Node2D
## Randmarkierung der Ankündigung: Ein pulsierender Pfeil zeigt von außerhalb der Karte auf die
## Kachel, auf der die angekündigte Welle erscheinen wird; die Kachel selbst ist rot umrandet.
## Nur Optik; Seite und Kachel kommen aus der Spielwelt (GameWorld.get_announced_tile()).

const COLOR := Color("#e0402a")
const FILL_COLOR := Color(0.88, 0.25, 0.16, 0.28)
const OUTLINE_COLOR := Color(0.12, 0.04, 0.02, 0.85)
## Seite → Richtung aus der Karte hinaus (in Kacheln).
const OUTWARD: Dictionary[String, Vector2i] = {
	"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0),
}
## Der Pfeil beginnt so viele Kacheln außerhalb und endet so weit vor der Kachelmitte (Anteil).
const ARROW_TILES := 2.6
const ARROW_GAP := 0.45
const SHAFT_WIDTH := 7.0
const HEAD_LENGTH := 22.0
const HEAD_WIDTH := 30.0
## Pulsieren: Perioden pro Sekunde und Weg des Pfeils hin und her in Pixeln.
const PULSE_SPEED := 1.6
const BOB_PIXELS := 6.0

var _tile := Vector2i.ZERO
var _side := ""
var _time := 0.0


## Zeigt die Markierung an dieser Randkachel der Seite (Waves.SIDES).
func show_at(tile: Vector2i, side: String) -> void:
	_tile = tile
	_side = side
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * TAU * PULSE_SPEED)
	var poly := Iso.tile_polygon(_tile)
	draw_colored_polygon(poly, Color(FILL_COLOR, FILL_COLOR.a * (0.6 + 0.4 * pulse)))
	poly.append(poly[0])
	draw_polyline(poly, COLOR, 2.0, true)
	var center := Iso.tile_to_world(_tile)
	var outside := Iso.tile_to_world(_tile + OUTWARD[_side] * 3)
	var direction := (center - outside).normalized()
	var length := (center - outside).length() / 3.0
	var tip := center - direction * (ARROW_GAP * length + BOB_PIXELS * pulse)
	var tail := tip - direction * ARROW_TILES * length
	_draw_arrow(tail, tip, direction)


## Ein Pfeil von tail nach tip mit dunklem Rand, damit er auf jedem Gelände zu sehen ist.
func _draw_arrow(tail: Vector2, tip: Vector2, direction: Vector2) -> void:
	var normal := Vector2(-direction.y, direction.x)
	var base := tip - direction * HEAD_LENGTH
	var head := PackedVector2Array([tip, base + normal * HEAD_WIDTH * 0.5, base - normal * HEAD_WIDTH * 0.5])
	draw_line(tail, base, OUTLINE_COLOR, SHAFT_WIDTH + 3.0)
	var outline := head.duplicate()
	outline.append(head[0])
	draw_polyline(outline, OUTLINE_COLOR, 3.0, true)
	draw_line(tail, base + direction, COLOR, SHAFT_WIDTH)
	draw_colored_polygon(head, COLOR)
