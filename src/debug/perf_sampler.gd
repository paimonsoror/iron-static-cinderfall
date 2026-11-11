class_name PerfSampler
extends RefCounted
## Frame and render statistics for the `[PERF]` line (ARCH 11). Pure bookkeeping, no engine calls: PerfHud feeds it
## frame times, sim tick times and the render monitors; `report()` aggregates everything since the last `reset()`.
## All reported numbers are finite and not negative, so the smoke script's `(\w+)=([\d.]+)` parse never skips a field.

## One aggregated period.
class Report:
	extends RefCounted
	var fps: float = 0.0  ## frames per second over the whole period
	var min_fps: float = 0.0  ## the worst one-second window (the whole period when it is shorter than a second)
	var frame_ms: float = 0.0  ## average frame time
	var p95_ms: float = 0.0  ## 95th percentile frame time
	var tick_ms: float = 0.0  ## average sim tick time (0 when no tick was recorded)
	var enemies: int = 0
	var draws: int = 0  ## draw calls per frame, averaged over the period
	var prims: int = 0  ## primitives per frame, averaged over the period
	var vid_mb: float = 0.0  ## video memory in MB (the last sample)
	var frames: int = 0


var _frames_ms: PackedFloat32Array = PackedFloat32Array()
var _window_ms: float = 0.0
var _window_frames: int = 0
var _worst_fps: float = INF
var _tick_ms_sum: float = 0.0
var _tick_n: int = 0
var _draws_sum: float = 0.0
var _prims_sum: float = 0.0
var _render_n: int = 0
var _vid_mb: float = 0.0
var _enemies: int = 0


func add_frame(frame_ms: float) -> void:
	var ms: float = _clean(frame_ms)
	_frames_ms.append(ms)
	_window_ms += ms
	_window_frames += 1
	if _window_ms >= 1000.0:
		_worst_fps = minf(_worst_fps, float(_window_frames) * 1000.0 / _window_ms)
		_window_ms = 0.0
		_window_frames = 0


func add_tick(tick_ms: float) -> void:
	_tick_ms_sum += _clean(tick_ms)
	_tick_n += 1


## Render monitors of one frame (draw calls, primitives, video memory in bytes).
func add_render(draw_calls: float, primitives: float, video_bytes: float) -> void:
	_draws_sum += _clean(draw_calls)
	_prims_sum += _clean(primitives)
	_render_n += 1
	_vid_mb = _clean(video_bytes) / 1048576.0


func set_enemies(alive: int) -> void:
	_enemies = maxi(0, alive)


func frame_count() -> int:
	return _frames_ms.size()


func report() -> Report:
	var r: Report = Report.new()
	var n: int = _frames_ms.size()
	r.frames = n
	r.enemies = _enemies
	r.vid_mb = _vid_mb
	if _tick_n > 0:
		r.tick_ms = _tick_ms_sum / float(_tick_n)
	if _render_n > 0:
		r.draws = roundi(_draws_sum / float(_render_n))
		r.prims = roundi(_prims_sum / float(_render_n))
	if n == 0:
		return r
	var total: float = 0.0
	for ms: float in _frames_ms:
		total += ms
	r.frame_ms = total / float(n)
	r.fps = 1000.0 / r.frame_ms if r.frame_ms > 0.0 else 0.0
	r.min_fps = r.fps if is_inf(_worst_fps) else minf(_worst_fps, r.fps)
	var sorted: PackedFloat32Array = _frames_ms.duplicate()
	sorted.sort()
	r.p95_ms = sorted[clampi(ceili(0.95 * float(n)) - 1, 0, n - 1)]
	return r


func reset() -> void:
	_frames_ms.clear()
	_window_ms = 0.0
	_window_frames = 0
	_worst_fps = INF
	_tick_ms_sum = 0.0
	_tick_n = 0
	_draws_sum = 0.0
	_prims_sum = 0.0
	_render_n = 0


## The `[PERF]` line of ARCH 11, key=value pairs separated by single spaces:
## `[PERF] fps=<avg> min=<worst 1s> frame_ms=<avg> p95_ms=<p95> tick_ms=<avg sim tick> enemies=<alive> draws=<n> prims=<n> vid_mb=<n>`
static func format_line(r: Report) -> String:
	return "[PERF] " + format_body(r)


## The same pairs without the tag (`Log.info("PERF", body)` prints `[PERF] <body>`).
static func format_body(r: Report) -> String:
	return "fps=%.1f min=%.1f frame_ms=%.2f p95_ms=%.2f tick_ms=%.2f enemies=%d draws=%d prims=%d vid_mb=%.1f" % [
		_clean(r.fps), _clean(r.min_fps), _clean(r.frame_ms), _clean(r.p95_ms), _clean(r.tick_ms),
		maxi(r.enemies, 0), maxi(r.draws, 0), maxi(r.prims, 0), _clean(r.vid_mb),
	]


static func _clean(v: float) -> float:
	if not is_finite(v) or v < 0.0:
		return 0.0
	return v
