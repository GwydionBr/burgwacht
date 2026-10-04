extends RefCounted
## Aufbau für Startparameter --setup=keep_attack (Presets in tools/presets.json): leere
## tiny_production-Karte, gegründet; fünf Räuber greifen den Bergfried an, er ist beschädigt
## (Lebensbalken über dem Dach).

const KEEP_ORIGIN := Vector2i(2, 2)
## Rund um den Bergfried (Grundfläche 2..5, 2..5).
const BANDITS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 1), Vector2i(3, 1)]
## So viele Takte nach dem Erscheinen der Räuber: Der Bergfried hat etwa die Hälfte verloren.
const TICKS := 80


static func create() -> GameWorld:
	var world := besiege()
	for i in TICKS:
		world.step()
	assert(world.get_building(1).is_damaged() and not world.is_defeated(), "Bergfried beschädigt, aber nicht gefallen")
	return world


## Gegründet, die Räuber stehen am Bergfried.
static func besiege() -> GameWorld:
	var helper := TestCase.new()
	var world := helper.empty_world("tiny_production")
	var reason := world.execute(Command.found(KEEP_ORIGIN))
	assert(reason == "", "Gründung: %s" % reason)
	for tile in BANDITS:
		helper.add_enemy(world, "bandit", tile)
	return world
