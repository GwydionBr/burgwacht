class_name DepositView
extends Node2D
## Zeigt ein Vorkommen als Sprite mit getrenntem Bodenschatten oder gezeichneten Platzhalter. Liegt in einem
## y-sortierten Container, damit weiter vorne stehende Objekte davor erscheinen.

const SHADOW_COLOR := Color(0, 0, 0, 0.22)
const TRUNK_COLOR := Color("#5b3d24")
const STONE_COLOR := Color("#8d8a82")
const IRON_STONE_COLOR := Color("#6f6660")
const ORE_COLOR := Color("#b0562e")
const GAME_COLOR := Color("#7a5232")
const GAME_BELLY_COLOR := Color("#c9a77c")

const SPRITE_SCALE := 0.5

var deposit: Deposit
var _sprite: Sprite2D
var _shadow: Sprite2D


## Die gespeicherte Variante bestimmt das Bild; shadows liegt unter den sortierten Objekten.
func setup(tile: Vector2i, shown: Deposit, shadows: Node2D = null) -> void:
	deposit = shown
	position = Iso.tile_to_world(tile)
	for old: Sprite2D in [_sprite, _shadow]:
		if is_instance_valid(old):
			old.queue_free()
	_sprite = null
	_shadow = null
	var def: Dictionary = GameDefs.get_instance().deposits[deposit.type]
	var path := GameDefs.sprite_path(def, deposit.variant)
	if ResourceLoader.exists(path):
		_sprite = _make_sprite(path)
		add_child(_sprite)
		var shadow_path := GameDefs.shadow_path(def, deposit.variant)
		if shadows != null and ResourceLoader.exists(shadow_path):
			_shadow = _make_sprite(shadow_path)
			_shadow.position = position - shadows.global_position
			shadows.add_child(_shadow)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_shadow):
		_shadow.queue_free()


static func _make_sprite(path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite


func _draw() -> void:
	if _sprite != null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = deposit.variant
	match deposit.type:
		"tree":
			_draw_tree(rng)
		"stone":
			_draw_rocks(rng, STONE_COLOR, false)
		"iron":
			_draw_rocks(rng, IRON_STONE_COLOR, true)
		"game":
			_draw_game(rng)


func _draw_tree(rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.2)
	var base := Vector2(rng.randf_range(-8, 8), rng.randf_range(-3, 3))
	var green := Color.from_hsv(rng.randf_range(0.26, 0.33), rng.randf_range(0.55, 0.75), rng.randf_range(0.32, 0.45))
	_draw_shadow(base + Vector2(4, 0), 13 * s)
	draw_rect(Rect2(base + Vector2(-2.5, -12) * s, Vector2(5, 13) * s), TRUNK_COLOR)

	if rng.randf() < 0.55:
		# Nadelbaum: drei gestapelte Dreiecke
		for i in 3:
			var w := (15.0 - i * 3.5) * s
			var bottom := (-8.0 - i * 9.0) * s
			var tip := bottom - 17.0 * s
			var color := green.darkened(0.15).lightened(i * 0.07)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-w, bottom), base + Vector2(w, bottom), base + Vector2(0, tip),
			]), color)
	else:
		# Laubbaum: mehrere Kreise als Krone
		draw_circle(base + Vector2(-7, -19) * s, 9 * s, green.darkened(0.1))
		draw_circle(base + Vector2(7, -20) * s, 9 * s, green.darkened(0.1))
		draw_circle(base + Vector2(0, -27) * s, 12 * s, green)
		draw_circle(base + Vector2(-4, -31) * s, 6 * s, green.lightened(0.15))


func _draw_rocks(rng: RandomNumberGenerator, color: Color, with_ore: bool) -> void:
	var rocks: Array[Vector3] = []  # x, y = Position, z = Radius
	for i in rng.randi_range(2, 3):
		rocks.append(Vector3(rng.randf_range(-12, 12), rng.randf_range(-5, 5), rng.randf_range(9, 15)))
	rocks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)

	for rock in rocks:
		var c := Vector2(rock.x, rock.y)
		var r := rock.z
		_draw_shadow(c + Vector2(3, 1), r)
		var points := PackedVector2Array()
		var corners := 7
		for k in corners:
			var angle := TAU * k / corners + rng.randf_range(-0.25, 0.25)
			var radius := r * rng.randf_range(0.8, 1.1)
			points.append(c + Vector2(cos(angle) * radius, sin(angle) * radius * 0.75 - r * 0.55))
		var shade := rng.randf_range(-0.08, 0.08)
		draw_colored_polygon(points, color.lightened(shade) if shade > 0 else color.darkened(-shade))
		draw_circle(c + Vector2(-r * 0.3, -r * 0.95), r * 0.35, color.lightened(0.25))
		if with_ore:
			for k in 3:
				var spot := c + Vector2(rng.randf_range(-r, r) * 0.55, -r * 0.55 + rng.randf_range(-r, r) * 0.35)
				draw_circle(spot, rng.randf_range(1.5, 2.8), ORE_COLOR)


## Zwei bis drei kleine braune Tiere (Rumpf, Hals und Kopf, Beine), stehend.
func _draw_game(rng: RandomNumberGenerator) -> void:
	var animals: Array[Vector2] = []
	for i in rng.randi_range(2, 3):
		animals.append(Vector2(rng.randf_range(-13, 13), rng.randf_range(-5, 5)))
	animals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for base in animals:
		var facing := 1.0 if rng.randf() < 0.5 else -1.0
		var color := GAME_COLOR.lightened(rng.randf_range(-0.1, 0.1))
		_draw_shadow(base + Vector2(1, 0), 7)
		for leg_x: float in [-4.0, -2.0, 3.0, 5.0]:
			draw_line(base + Vector2(leg_x * facing, -5), base + Vector2(leg_x * facing, 0), color.darkened(0.3), 1.2)
		draw_set_transform(base + Vector2(0, -7), 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, 6.5, color)
		draw_circle(Vector2(0, 2.5), 4.0, GAME_BELLY_COLOR)
		draw_set_transform(Vector2.ZERO)
		draw_line(base + Vector2(5 * facing, -8), base + Vector2(7 * facing, -13), color, 2.0)
		draw_circle(base + Vector2(8 * facing, -14), 2.2, color)
		draw_line(base + Vector2(7 * facing, -16), base + Vector2(6 * facing, -19), color.darkened(0.4), 1.0)


func _draw_shadow(center: Vector2, radius: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
