class_name FigureView
extends Node2D
## Zeichnet eine Figur (Bewohner oder Feind) als einfache Platzhalter-Figur.
## Liegt im y-sortierten Objekt-Container; die Position liest sie jeden Frame aus dem Zustand
## und interpoliert mit dem Bruchteil der Uhr zwischen zwei Takten. Ausgewählte stehen in einem
## Ring; Kämpfer zeigen einen Lebensbalken, wenn sie verletzt oder ausgewählt sind. Auf dem
## Wehrgang steht die Figur um die Mauerhöhe angehoben.
## Verdeckt sie ein Gebäude (BuildingView.covers_figure()), zeigt sie über allen Objekten zusätzlich
## ihre Silhouette samt Ring und Lebensbalken.
## Unterklassen bestimmen Farbe und Beiwerk (Ware, Waffe).

const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const OUTLINE_COLOR := Color(0, 0, 0, 0.45)
const SKIN_COLOR := Color("#e2b48c")
const LEG_COLOR := Color("#4a3b2a")
## Ring um ausgewählte Soldaten.
const RING_COLOR := Color(1, 0.95, 0.7, 0.95)
## Fläche der Figur um den Fußpunkt, in der ein Klick sie trifft.
const HIT_RECT := Rect2(-8, -27, 16, 30)
## Lebensbalken über dem Kopf: Fläche, Hintergrund und Farben je nach Rest.
const HEALTH_RECT := Rect2(-9, -33, 18, 3)
const HEALTH_BACK_COLOR := Color(0.1, 0.1, 0.1, 0.8)
const HEALTH_HIGH_COLOR := Color("#5cc85a")
const HEALTH_LOW_COLOR := Color("#d8463c")
## Auf dem Wehrgang wird die Figur sortiert, als stünde sie knapp eine halbe Kachel weiter vorn:
## nach der Mauer, auf der sie steht, aber vor den Mauern und Figuren auf den Kacheln davor.
const WALL_WALK_SORT := Iso.TILE_H * 0.5 - 1.0
## Silhouette einer verdeckten Figur: Füllung in der Kittelfarbe, heller Umriss.
const SILHOUETTE_ALPHA := 0.55
const SILHOUETTE_OUTLINE_COLOR := Color(1, 1, 1, 0.9)

## Ist er ausgewählt? Dann steht er in einem Ring.
var selected := false:
	set(value):
		selected = value
		queue_redraw()
		_silhouette.queue_redraw()

## Die Gebäude, die sie verdecken können (von außen gesetzt, geteilt mit den Gebäudefiguren).
var occluders: Dictionary[int, BuildingView] = {}
## Verdeckt sie gerade ein Gebäude? Dann zeigt sie ihre Silhouette.
var covered := false

var _figure: Figure
var _clock: GameClock
## Um so viel ist die Figur über ihrem Sortierpunkt gezeichnet (auf dem Wehrgang).
var _lift := 0.0
## Zeichenfläche der Silhouette über allen Objekten.
var _silhouette := Node2D.new()


func _init() -> void:
	_silhouette.z_index = 1
	_silhouette.visible = false
	_silhouette.draw.connect(_draw_silhouette)
	add_child(_silhouette)


func setup(figure: Figure, clock: GameClock) -> void:
	_figure = figure
	_clock = clock
	_update_position()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_position()


## Die Fläche der Figur in Weltkoordinaten (für Klick und Rahmen).
func hit_rect() -> Rect2:
	return Rect2(position + HIT_RECT.position + Vector2(0, -_lift), HIT_RECT.size)


## So hoch über dem Boden liegt der Wehrgang: die Höhe ("height") des ersten Gebäudetyps mit
## Wehrgang in buildings.json (der Mauer).
static func wall_walk_height() -> float:
	var buildings := GameDefs.get_instance().buildings
	for type_id: String in buildings:
		if bool(buildings[type_id].get("walkway", false)):
			return float(buildings[type_id]["height"])
	return 0.0


func _update_position() -> void:
	var fraction := _clock.tick_fraction()
	var level := _figure.level_point(fraction)
	position = Iso.point_to_world(_figure.tile_point(fraction)) + Vector2(0, WALL_WALK_SORT * level)
	_lift = (WALL_WALK_SORT + wall_walk_height()) * level
	covered = _is_covered()
	_silhouette.visible = covered
	queue_redraw()
	if covered:
		_silhouette.queue_redraw()


func _is_covered() -> bool:
	var rect := hit_rect()
	for building: BuildingView in occluders.values():
		if building.covers_figure(rect, position.y):
			return true
	return false


## Versatz der Figur nach oben (z. B. Wippen beim Abbau).
func _bob() -> float:
	return 0.0


## Farbe des Kittels.
func _body_color() -> Color:
	return Color.WHITE


## Beiwerk über der Figur (getragene Ware, Waffe); im verschobenen Zeichenraum der Figur.
func _draw_extras() -> void:
	pass


func _draw() -> void:
	draw_set_transform(Vector2(0, 1 - _lift), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, SHADOW_COLOR)
	_draw_ring(self)
	draw_set_transform(Vector2(0, -_bob() - _lift))
	_draw_body(self, _body_color(), SKIN_COLOR, LEG_COLOR, OUTLINE_COLOR)
	_draw_extras()
	_draw_health(self)


## Silhouette: Ring, Figur in der Kittelfarbe ohne Beiwerk, Lebensbalken.
func _draw_silhouette() -> void:
	_silhouette.draw_set_transform(Vector2(0, 1 - _lift), 0.0, Vector2(1.0, 0.5))
	_draw_ring(_silhouette)
	_silhouette.draw_set_transform(Vector2(0, -_bob() - _lift))
	var fill := _body_color()
	fill.a = SILHOUETTE_ALPHA
	_draw_body(_silhouette, fill, fill, fill, SILHOUETTE_OUTLINE_COLOR)
	_draw_health(_silhouette)


## Ring am Boden, wenn ausgewählt (im gestauchten Zeichenraum des Bodens).
func _draw_ring(canvas: CanvasItem) -> void:
	if selected:
		canvas.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, RING_COLOR, 2.0, true)


## Beine, Körper (Kittel) und Kopf.
func _draw_body(canvas: CanvasItem, body_color: Color, skin_color: Color, leg_color: Color, outline_color: Color) -> void:
	canvas.draw_rect(Rect2(-3.5, -7, 2.5, 7), leg_color)
	canvas.draw_rect(Rect2(1, -7, 2.5, 7), leg_color)
	var body := PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(3.5, -18), Vector2(-3.5, -18)])
	canvas.draw_colored_polygon(body, body_color)
	body.append(body[0])
	canvas.draw_polyline(body, outline_color, 1.0, true)
	canvas.draw_circle(Vector2(0, -22), 4.0, skin_color)
	canvas.draw_arc(Vector2(0, -22), 4.0, 0, TAU, 16, outline_color, 1.0, true)


## Lebensbalken bei Kämpfern, die verletzt oder ausgewählt sind: grün bei viel, rot bei wenig Rest.
func _draw_health(canvas: CanvasItem) -> void:
	if not _figure.is_fighter() or not (_figure.is_wounded() or selected):
		return
	var share := clampf(float(_figure.hp) / FighterType.max_hp(_figure.fighter_type()), 0.0, 1.0)
	canvas.draw_rect(HEALTH_RECT.grow(1.0), HEALTH_BACK_COLOR)
	var filled := Rect2(HEALTH_RECT.position, Vector2(HEALTH_RECT.size.x * share, HEALTH_RECT.size.y))
	canvas.draw_rect(filled, HEALTH_LOW_COLOR.lerp(HEALTH_HIGH_COLOR, share))
