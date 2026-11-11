extends GdUnitTestSuite
## W3-A: `RunController.tick_sink` (what Game points at `PerfHud.record_tick_usec` for --debug-perf) is called once per
## frame that ran ticks, with the average microseconds of one tick of that frame, and never for a frame that ran none.

var _calls: Array[float] = []


func before_test() -> void:
	GameRunKit.fresh_save()
	_calls.clear()


func after_test() -> void:
	GameRunKit.reset_save()


func _sink(usec: float) -> void:
	_calls.append(usec)


func test_a_frame_that_ran_ticks_reports_their_average_cost() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.tick_sink = _sink
	GameRunKit.frames(rc, 10)
	assert_int(_calls.size()).is_equal(10)
	for usec: float in _calls:
		assert_float(usec).is_greater_equal(0.0)
		assert_float(usec).is_less(50000.0)  # a tick is never 50 ms


func test_a_slow_frame_of_several_ticks_is_one_call_with_the_per_tick_average() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.tick_sink = _sink
	assert_int(rc.step_frame(4.0 * GameRunKit.DT)).is_equal(4)
	assert_int(_calls.size()).is_equal(1)


func test_no_call_while_paused_or_when_the_frame_is_too_short_for_a_tick() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.tick_sink = _sink
	rc.api.pause()
	GameRunKit.frames(rc, 5)
	assert_int(_calls.size()).is_equal(0)
	rc.api.resume()
	assert_int(rc.step_frame(0.001)).is_equal(0)  # 1 ms: no tick due yet
	assert_int(_calls.size()).is_equal(0)


func test_without_a_sink_nothing_is_called_and_nothing_breaks() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	assert_bool(rc.tick_sink.is_valid()).is_false()
	assert_int(GameRunKit.frames(rc, 5)).is_equal(5)
