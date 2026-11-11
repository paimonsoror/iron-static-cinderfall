extends GdUnitTestSuite
## W2-E: PerfSampler and PerfHud. The `[PERF]` line is key=value pairs in the order of ARCH 11, and every value matches
## the smoke script's `(\w+)=([\d.]+)` (tools/smoke_android.ps1 of W1-H parses exactly that).

const KEYS: Array[String] = ["fps", "min", "frame_ms", "p95_ms", "tick_ms", "enemies", "draws", "prims", "vid_mb"]


## What smoke_android.ps1 does with a logcat line: `[PERF]\s+(.*)$`, then every `(\w+)=([\d.]+)`.
func _parse_like_the_smoke_script(line: String) -> Dictionary:
	var out: Dictionary = {}
	var head: RegEx = RegEx.create_from_string("\\[PERF\\]\\s+(.*)$")
	var m: RegExMatch = head.search(line)
	if m == null:
		return out
	var pairs: RegEx = RegEx.create_from_string("(\\w+)=([\\d.]+)")
	for pm: RegExMatch in pairs.search_all(m.get_string(1)):
		out[pm.get_string(1)] = pm.get_string(2).to_float()
	return out


func _steady(sampler: PerfSampler, frames: int, ms: float) -> void:
	for _i: int in frames:
		sampler.add_frame(ms)


func test_steady_sixty_fps_reports_sixty_and_flat_percentiles() -> void:
	var s: PerfSampler = PerfSampler.new()
	_steady(s, 300, 1000.0 / 60.0)
	var r: PerfSampler.Report = s.report()
	assert_float(r.fps).is_equal_approx(60.0, 0.05)
	assert_float(r.min_fps).is_equal_approx(60.0, 0.5)
	assert_float(r.frame_ms).is_equal_approx(16.667, 0.01)
	assert_float(r.p95_ms).is_equal_approx(16.667, 0.01)
	assert_int(r.frames).is_equal(300)


func test_worst_second_and_p95_show_a_stutter_that_the_average_hides() -> void:
	var s: PerfSampler = PerfSampler.new()
	_steady(s, 120, 1000.0 / 60.0)  # two good seconds
	_steady(s, 30, 1000.0 / 30.0)  # one second at 30 fps
	_steady(s, 120, 1000.0 / 60.0)
	var r: PerfSampler.Report = s.report()
	assert_float(r.min_fps).is_between(29.0, 34.0)  # the one-second windows are not aligned with the slow second
	assert_float(r.fps).is_greater(r.min_fps + 10.0)
	var t: PerfSampler = PerfSampler.new()
	_steady(t, 94, 10.0)
	_steady(t, 6, 50.0)  # 6 percent of the frames are slow: the 95th percentile sees them
	assert_float(t.report().p95_ms).is_equal_approx(50.0, 0.01)
	var u: PerfSampler = PerfSampler.new()
	_steady(u, 96, 10.0)
	_steady(u, 4, 50.0)
	assert_float(u.report().p95_ms).is_equal_approx(10.0, 0.01)


func test_a_period_shorter_than_a_second_falls_back_to_the_average_for_min() -> void:
	var s: PerfSampler = PerfSampler.new()
	_steady(s, 10, 20.0)
	var r: PerfSampler.Report = s.report()
	assert_float(r.min_fps).is_equal_approx(r.fps, 0.001)


func test_tick_render_and_enemy_numbers_are_averaged_and_reset_clears_the_period() -> void:
	var s: PerfSampler = PerfSampler.new()
	s.add_frame(16.0)
	s.add_tick(0.2)
	s.add_tick(0.4)
	s.add_render(100.0, 20000.0, 8.0 * 1048576.0)
	s.add_render(120.0, 22000.0, 9.0 * 1048576.0)
	s.set_enemies(50)
	var r: PerfSampler.Report = s.report()
	assert_float(r.tick_ms).is_equal_approx(0.3, 0.0001)
	assert_int(r.draws).is_equal(110)
	assert_int(r.prims).is_equal(21000)
	assert_float(r.vid_mb).is_equal_approx(9.0, 0.0001)
	assert_int(r.enemies).is_equal(50)
	s.reset()
	assert_int(s.report().frames).is_equal(0)
	assert_float(s.report().tick_ms).is_equal(0.0)


func test_the_line_has_every_key_in_architecture_order() -> void:
	var r: PerfSampler.Report = PerfSampler.Report.new()
	r.fps = 59.94
	r.min_fps = 41.2
	r.frame_ms = 16.68
	r.p95_ms = 21.4
	r.tick_ms = 0.31
	r.enemies = 50
	r.draws = 143
	r.prims = 96250
	r.vid_mb = 61.5
	var line: String = PerfSampler.format_line(r)
	assert_str(line).is_equal(
		"[PERF] fps=59.9 min=41.2 frame_ms=16.68 p95_ms=21.40 tick_ms=0.31 enemies=50 draws=143 prims=96250 vid_mb=61.5"
	)
	assert_str(line).starts_with("[PERF] ")
	assert_bool(line.contains("\n")).is_false()
	var order: int = -1
	for key: String in KEYS:
		var at: int = line.find(" " + key + "=")
		assert_int(at).is_greater(order)
		order = at


func test_the_smoke_script_parse_reads_every_field_back() -> void:
	var r: PerfSampler.Report = PerfSampler.Report.new()
	r.fps = 31.0
	r.min_fps = 22.5
	r.frame_ms = 32.2
	r.p95_ms = 40.0
	r.tick_ms = 1.25
	r.enemies = 50
	r.draws = 187
	r.prims = 120000
	r.vid_mb = 70.25
	# a logcat line: "<epoch> <pid> <tid> I godot  : [PERF] ..." (the tag is printed by Log.info)
	var logcat: String = "1731300000.123  4242  4242 I godot   : " + PerfSampler.format_line(r)
	var kv: Dictionary = _parse_like_the_smoke_script(logcat)
	for key: String in KEYS:
		assert_bool(kv.has(key)).is_true()
	assert_float(kv["fps"]).is_equal_approx(31.0, 0.05)
	assert_float(kv["min"]).is_equal_approx(22.5, 0.05)
	assert_float(kv["p95_ms"]).is_equal_approx(40.0, 0.01)
	var enemies: float = kv["enemies"]
	var draws: float = kv["draws"]
	assert_int(roundi(enemies)).is_equal(50)
	assert_int(roundi(draws)).is_equal(187)
	assert_float(kv["vid_mb"]).is_equal_approx(70.3, 0.06)


func test_bad_numbers_never_break_the_line() -> void:
	var r: PerfSampler.Report = PerfSampler.Report.new()
	r.fps = NAN
	r.min_fps = -5.0
	r.frame_ms = INF
	r.p95_ms = -INF
	r.tick_ms = NAN
	r.enemies = -3
	r.draws = -1
	r.prims = -1
	r.vid_mb = NAN
	var kv: Dictionary = _parse_like_the_smoke_script(PerfSampler.format_line(r))
	for key: String in KEYS:
		assert_bool(kv.has(key)).is_true()
		var v: float = kv[key]
		assert_float(v).is_greater_equal(0.0)
	var s: PerfSampler = PerfSampler.new()
	s.add_frame(NAN)
	s.add_tick(-1.0)
	s.add_render(NAN, -1.0, NAN)
	assert_float(s.report().frame_ms).is_equal(0.0)


func test_hud_logs_a_period_and_starts_the_next_one() -> void:
	var hud: PerfHud = PerfHud.new()
	auto_free(hud)
	add_child(hud)
	var alive: Array[int] = [37]
	hud.setup(func() -> int: return alive[0], true)
	hud.log_enabled = false  # no log noise from the test; the line is still built
	hud.record_tick_usec(250.0)
	for _i: int in 60:
		hud.sample_frame(1.0 / 60.0)
	assert_int(hud.reports_logged).is_equal(0)
	assert_str(hud.last_line).is_empty()
	var line: String = hud.report_now()
	assert_str(line).is_equal(hud.last_line)
	var kv: Dictionary = _parse_like_the_smoke_script(line)
	var alive_read: float = kv["enemies"]
	assert_int(roundi(alive_read)).is_equal(37)
	assert_float(kv["fps"]).is_equal_approx(60.0, 0.1)
	assert_float(kv["tick_ms"]).is_equal_approx(0.25, 0.005)
	assert_int(hud.sampler.frame_count()).is_equal(0)
	# 5 s of frames close a period by themselves
	for _i: int in 301:
		hud.sample_frame(1.0 / 60.0)
	assert_int(hud.reports_logged).is_equal(2)


func test_hud_overlay_text_shows_the_numbers_and_can_be_hidden() -> void:
	var hud: PerfHud = PerfHud.new()
	auto_free(hud)
	add_child(hud)
	hud.setup(Callable(), false)
	hud.log_enabled = false
	var label: Label = hud.get_node("PerfText") as Label
	assert_bool(label.visible).is_false()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	label.visible = true
	for _i: int in 40:
		hud.sample_frame(1.0 / 60.0)
	assert_str(label.text).contains("fps")
	assert_str(label.text).contains("draws")
