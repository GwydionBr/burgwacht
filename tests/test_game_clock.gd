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
