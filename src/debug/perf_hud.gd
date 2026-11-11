class_name PerfHud
extends Control
## `--debug-perf` overlay and the `[PERF]` log line (ARCH 11). Drop it into any CanvasLayer or the Game's DebugRoot:
## it measures every frame itself (wall clock, draw calls, primitives and video memory from the render monitors),
## logs `[PERF] fps=.. min=.. frame_ms=.. p95_ms=.. tick_ms=.. enemies=.. draws=.. prims=.. vid_mb=..` every
## `report_period_s` (5 s) and shows the same numbers on screen. The owner of the tick loop reports the sim tick time
## with `record_tick_usec` and the live enemy count through the `enemies_source` callable given to `setup`.
## Draw calls and primitives count the whole frame (3D and UI). Under the headless renderer they read 0.

const FONT_SIZE: int = 26
const LABEL_REFRESH_S: float = 0.5

var sampler: PerfSampler = PerfSampler.new()
var report_period_s: float = 5.0
var log_enabled: bool = true
var last_line: String = ""
var reports_logged: int = 0

var _label: Label
var _enemies_source: Callable = Callable()
var _last_usec: int = 0
var _since_report_s: float = 0.0
var _since_label_s: float = 0.0


## `enemies_source` is a Callable returning the alive enemy count (int); empty = 0. `overlay` shows the on-screen text.
func setup(enemies_source: Callable = Callable(), overlay: bool = true) -> void:
	name = "PerfHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemies_source = enemies_source
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0.0, 120.0)
	_label = Label.new()
	_label.name = "PerfText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(12.0, 8.0)
	_label.visible = overlay
	add_child(_label)
	_last_usec = Time.get_ticks_usec()


## The sim tick driver reports how long one tick took (microseconds).
func record_tick_usec(usec: float) -> void:
	sampler.add_tick(usec / 1000.0)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_s: float = float(now - _last_usec) / 1000000.0
	_last_usec = now
	sample_frame(frame_s)


## One frame of `frame_s` seconds: feeds the sampler (also the entry point of the tests) and runs the period timers.
func sample_frame(frame_s: float) -> void:
	sampler.add_frame(frame_s * 1000.0)
	sampler.add_render(
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	)
	sampler.set_enemies(_alive())
	_since_report_s += frame_s
	_since_label_s += frame_s
	if _since_label_s >= LABEL_REFRESH_S and _label != null and _label.visible:
		_since_label_s = 0.0
		_label.text = _overlay_text(sampler.report())
	if _since_report_s >= report_period_s:
		_since_report_s = 0.0
		var _line: String = report_now()


## Aggregates the period, logs the `[PERF]` line (when enabled), starts a new period and returns the line.
func report_now() -> String:
	var r: PerfSampler.Report = sampler.report()
	last_line = PerfSampler.format_line(r)
	if log_enabled:
		Log.info("PERF", PerfSampler.format_body(r))
	reports_logged += 1
	sampler.reset()
	return last_line


func _alive() -> int:
	if _enemies_source.is_valid():
		var n: Variant = _enemies_source.call()
		if n is int:
			var count: int = n
			return count
	return 0


func _overlay_text(r: PerfSampler.Report) -> String:
	return "%.0f fps  min %.0f  %.1f ms  p95 %.1f ms\ntick %.2f ms  enemies %d\ndraws %d  prims %d  vid %.0f MB" % [
		r.fps, r.min_fps, r.frame_ms, r.p95_ms, r.tick_ms, r.enemies, r.draws, r.prims, r.vid_mb
	]
