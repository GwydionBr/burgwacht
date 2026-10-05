extends TestCase
## Richtung und Animationsbild einer Figur, ohne Grafik und unabhängig von der Bildrate.


func test_movement_selects_eight_directions_and_standing_keeps_facing() -> void:
	var movements: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	for index in movements.size():
		assert_eq(FigureAnimation.direction(movements[index], 6), index, "Richtung:")
	assert_eq(FigureAnimation.direction(Vector2i.ZERO, 6), 6, "Stehend bleibt die Richtung:")


func test_animation_uses_simulation_seconds_and_wraps() -> void:
	assert_eq(FigureAnimation.frame(0.0, 8, 8), 0, "Anfang:")
	assert_eq(FigureAnimation.frame(0.375, 8, 8), 3, "Nach drei Bildern:")
	assert_eq(FigureAnimation.frame(1.125, 8, 8), 1, "Neue Schleife:")


func test_pause_menu_and_double_speed_drive_animation_time() -> void:
	var world := found_castle(empty_world("tiny"))
	var clock := GameClock.new()
	clock.world = world
	for tick in clock.advance(0.375):
		world.step()
	var seconds := (world.get_tick() + clock.tick_fraction()) / float(GameClock.TICKS_PER_SECOND)
	assert_eq(FigureAnimation.frame(seconds, 8, 8), 3, "Bei 1×:")
	clock.toggle_pause()
	assert_eq(clock.advance(0.5), 0, "Pause:")
	assert_eq(FigureAnimation.frame((world.get_tick() + clock.tick_fraction()) / 10.0, 8, 8), 3, "Bild bleibt:")
	clock.set_speed(2)
	for tick in clock.advance(0.125):
		world.step()
	assert_eq(FigureAnimation.frame((world.get_tick() + clock.tick_fraction()) / 10.0, 8, 8), 5, "Bei 2× zwei Bilder:")
	clock.hold()
	assert_eq(clock.advance(0.5), 0, "Spielmenü:")
	assert_eq(FigureAnimation.frame((world.get_tick() + clock.tick_fraction()) / 10.0, 8, 8), 5, "Bild im Menü bleibt:")
	clock.free()
