extends TestCase


func _ticks_over(clock: GameClock, frames: int, delta: float) -> int:
	var total := 0
	for i in frames:
		total += clock.advance(delta)
	return total


func test_one_second_at_normal_speed_gives_ten_ticks() -> void:
	var clock := GameClock.new()
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 10, "Takte bei 60 fps:")
	clock.free()


func test_result_does_not_depend_on_framerate() -> void:
	var slow := GameClock.new()
	var fast := GameClock.new()
	assert_eq(_ticks_over(slow, 30, 1.0 / 15.0), _ticks_over(fast, 288, 1.0 / 144.0), "15 fps gegen 144 fps über 2 s:")
	slow.free()
	fast.free()


func test_speed_multiplies_ticks() -> void:
	var clock := GameClock.new()
	clock.set_speed(4)
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 40, "Takte bei 4×:")
	clock.free()


func test_paused_clock_gives_no_ticks() -> void:
	var clock := GameClock.new()
	clock.toggle_pause()
	assert_true(clock.is_paused(), "Uhr sollte pausiert sein")
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 0, "Takte in der Pause:")
	clock.toggle_pause()
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 10, "Takte nach der Pause:")
	clock.free()


func test_long_frame_is_capped() -> void:
	var clock := GameClock.new()
	assert_eq(clock.advance(5.0), GameClock.MAX_TICKS_PER_FRAME, "Takte nach einem Hänger:")
	assert_eq(clock.advance(0.0), 0, "Rückstand wird verworfen:")
	clock.free()


func test_new_world_drops_pending_time() -> void:
	var clock := GameClock.new()
	assert_eq(clock.advance(0.09), 0, "Takte nach 0,09 s:")
	clock.world = run_scenario("tiny", 0)
	assert_eq(clock.advance(0.09), 0, "Zeitrest der alten Welt zählt nicht mit:")
	clock.free()


func test_clock_cannot_start_before_founding() -> void:
	var clock := GameClock.new()
	clock.world = new_world("tiny")
	assert_true(clock.is_paused(), "Uhr steht während der Gründung")
	clock.toggle_pause()
	clock.set_speed(2)
	assert_true(clock.is_paused(), "Uhr lässt sich in der Gründung nicht starten")
	found_castle(clock.world)
	clock.toggle_pause()
	assert_true(not clock.is_paused(), "Nach der Gründung lässt sich die Uhr starten")
	assert_eq(clock.advance(1.0), 10, "Takte nach der Gründung:")
	clock.free()


func test_held_clock_gives_no_ticks_and_keeps_the_previous_speed() -> void:
	var clock := GameClock.new()
	clock.set_speed(2)
	clock.hold()
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 0, "Takte bei angehaltener Uhr:")
	clock.release()
	assert_true(not clock.is_paused(), "Uhr sollte nach dem Anhalten wieder laufen")
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 20, "Takte nach dem Anhalten bei 2×:")
	clock.free()


func test_released_clock_stays_paused_if_it_was_paused() -> void:
	var clock := GameClock.new()
	clock.toggle_pause()
	clock.hold()
	clock.release()
	assert_true(clock.is_paused(), "Pause sollte bleiben")
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 0, "Takte in der Pause:")
	clock.free()


func test_held_clock_ignores_speed_and_pause_keys() -> void:
	var clock := GameClock.new()
	clock.hold()
	clock.set_speed(4)
	clock.toggle_pause()
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 0, "Takte bei angehaltener Uhr:")
	clock.release()
	assert_eq(_ticks_over(clock, 60, 1.0 / 60.0), 10, "vorige Geschwindigkeit 1×:")
	clock.free()
