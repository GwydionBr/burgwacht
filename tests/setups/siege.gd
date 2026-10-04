extends RefCounted
## Aufbau für Startparameter --setup=siege (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet; eine Mauer mit Tor schließt die Burg nach unten ab (y = 11
## über die ganze Breite). Vier Räuber kommen von unten; ein Umweg fehlt, also hacken sie an der
## Mauer (Hindernis, ADR 0005), die Mauerstücke sind beschädigt (Lebensbalken).

const KEEP_ORIGIN := Vector2i(2, 2)
const WAREHOUSE := 2
const WALL_Y := 11
const GATE := Vector2i(9, WALL_Y)
const BANDITS: Array[Vector2i] = [Vector2i(3, 14), Vector2i(7, 15), Vector2i(12, 14), Vector2i(16, 15)]
## So viele Takte nach dem Erscheinen der Räuber: Sie hacken eine Weile, keine Mauer ist gefallen.
const TICKS := 120


static func create() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	_ok(world.execute(Command.found(KEEP_ORIGIN)), "Gründung")
	helper.put_goods(world, WAREHOUSE, "stone", 100)
	_ok(world.execute(Command.build_line("wall", Vector2i(0, WALL_Y), GATE - Vector2i(1, 0))), "Mauerlinie")
	_ok(world.execute(Command.build_line("wall", GATE + Vector2i(1, 0), Vector2i(world.map.width - 1, WALL_Y))),
			"Mauerlinie")
	helper.build(world, "gate", GATE)
	for tile in BANDITS:
		helper.add_enemy(world, "bandit", tile)
	for i in TICKS:
		world.step()
	var attacking := 0
	for enemy in world.get_enemies():
		var target := world.get_building(enemy.target_building_id)
		if target != null and target.is_damaged() and target.origin.y == WALL_Y:
			attacking += 1
	assert(attacking == BANDITS.size(), "Alle Räuber hacken an der Mauer: %d" % attacking)
	return world


static func _ok(reason: String, what: String) -> void:
	assert(reason == "", "%s: %s" % [what, reason])
