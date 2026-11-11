extends GdUnitTestSuite
## TickDriver (ARCH 7.3): frame time to whole sim ticks, capped, never carrying a backlog.

var _hook_calls: int = 0
var _hook_ticks: Array[int] = []


func _frames(driver: TickDriver, world: SimWorld, count: int, delta: float) -> int:
	var total: int = 0
	for i: int in count:
		total += driver.advance(world, delta)
	return total


func test_one_second_of_60_fps_frames_gives_60_ticks() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	assert_int(_frames(d, w, 60, 1.0 / 60.0)).is_equal(60)
	assert_int(w.tick).is_equal(60)
	assert_int(d.dropped_ticks).is_equal(0)


func test_one_second_of_30_fps_frames_gives_60_ticks_two_per_frame() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	assert_int(d.advance(w, 1.0 / 30.0)).is_equal(2)
	assert_int(_frames(d, w, 29, 1.0 / 30.0)).is_equal(58)
	assert_int(w.tick).is_equal(60)
	assert_int(d.dropped_ticks).is_equal(0)


func test_a_144_hz_second_gives_59_or_60_ticks_and_never_more() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	var ticks: int = _frames(d, w, 144, 1.0 / 144.0)
	assert_int(ticks).is_between(59, 60)
	assert_int(w.tick).is_equal(ticks)


func test_a_one_second_hitch_runs_at_most_four_ticks_and_drops_the_rest() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	assert_int(d.advance(w, 1.0)).is_equal(TickDriver.MAX_TICKS_PER_FRAME)
	assert_int(w.tick).is_equal(4)
	assert_int(d.dropped_ticks).is_equal(56)
	assert_float(d.acc).is_less(SimWorld.DT)


func test_after_a_hitch_the_next_frame_is_normal_not_a_catch_up_burst() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	d.advance(w, 1.0)
	assert_int(d.advance(w, 1.0 / 60.0)).is_equal(1)
	assert_int(d.advance(w, 1.0 / 60.0)).is_equal(1)
	assert_int(w.tick).is_equal(6)


func test_a_small_remainder_is_kept_and_alpha_reports_it() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	assert_int(d.advance(w, SimWorld.DT * 1.5)).is_equal(1)
	assert_float(d.alpha()).is_equal_approx(0.5, 0.001)
	assert_int(d.advance(w, SimWorld.DT * 0.5)).is_equal(1)
	assert_float(d.alpha()).is_less(0.01)


func test_alpha_stays_inside_zero_to_one() -> void:
	var d: TickDriver = TickDriver.new()
	assert_float(d.alpha()).is_equal(0.0)
	d.acc = SimWorld.DT * 7.0
	assert_float(d.alpha()).is_equal(1.0)
	d.acc = -1.0
	assert_float(d.alpha()).is_equal(0.0)


func test_zero_and_negative_deltas_run_no_ticks() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	assert_int(d.advance(w, 0.0)).is_equal(0)
	assert_int(d.advance(w, -0.5)).is_equal(0)
	assert_int(w.tick).is_equal(0)
	assert_float(d.acc).is_equal(0.0)


func test_a_finished_world_runs_no_ticks_and_keeps_no_backlog() -> void:
	var w: SimWorld = TestContent.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.set_phase(GameState.Id.CLEARING)
	w.set_phase(GameState.Id.VICTORY)
	var d: TickDriver = TickDriver.new()
	assert_int(d.advance(w, 1.0)).is_equal(0)
	assert_int(w.tick).is_equal(0)
	assert_float(d.acc).is_equal(0.0)


func _count_tick(world: SimWorld) -> void:
	_hook_calls += 1
	_hook_ticks.append(world.tick)


func test_before_tick_runs_once_before_every_tick() -> void:
	var w: SimWorld = TestContent.world()
	var d: TickDriver = TickDriver.new()
	d.before_tick = _count_tick
	_hook_calls = 0
	_hook_ticks.clear()
	d.advance(w, 1.0 / 30.0)
	assert_int(_hook_calls).is_equal(2)
	assert_array(_hook_ticks).is_equal([0, 1])  # it sees the world before the tick is applied
	assert_int(d.ticks_run).is_equal(2)
