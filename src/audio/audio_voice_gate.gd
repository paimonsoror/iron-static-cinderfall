class_name AudioVoiceGate
extends RefCounted
## Pure start limiter (no engine calls; frame and time are passed in): per sound id at most MAX_STARTS_PER_FRAME
## starts in one frame, and no start sooner than the id's minimum interval after its previous start.

const MAX_STARTS_PER_FRAME: int = 3

## Tests switch the real-time interval off so they do not depend on the wall clock; the per-frame cap stays.
var intervals_enabled: bool = true

var _frame: int = -1
var _frame_starts: Dictionary[StringName, int] = {}
var _last_start_ms: Dictionary[StringName, int] = {}


## True and counted as a start, or false (cap or interval hit). `frame` is Engine.get_process_frames().
func try_start(id: StringName, frame: int, now_ms: int, min_interval_ms: int) -> bool:
	if frame != _frame:
		_frame = frame
		_frame_starts.clear()
	var started: int = _frame_starts.get(id, 0)
	if started >= MAX_STARTS_PER_FRAME:
		return false
	if intervals_enabled and _last_start_ms.has(id) and now_ms - _last_start_ms[id] < min_interval_ms:
		return false
	_frame_starts[id] = started + 1
	_last_start_ms[id] = now_ms
	return true


func clear() -> void:
	_frame = -1
	_frame_starts.clear()
	_last_start_ms.clear()
