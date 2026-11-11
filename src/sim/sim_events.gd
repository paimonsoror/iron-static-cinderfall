class_name SimEvents
extends RefCounted
## Event buffer plus a rolling hash of every event ever pushed (determinism check).
## SimWorld.step() sets `current_tick` so events carry their tick.

var event_hash: int = 0
var total: int = 0
var current_tick: int = 0
var _buffer: Array[SimEvent] = []


func push(kind: int, a: int = 0, b: int = 0, f: float = 0.0, g: float = 0.0) -> void:
	var e: SimEvent = SimEvent.new()
	e.kind = kind
	e.tick = current_tick
	e.a = a
	e.b = b
	e.f = f
	e.g = g
	_buffer.append(e)
	total += 1
	var h: int = event_hash
	h = (h * 1000003) ^ kind
	h = (h * 1000003) ^ current_tick
	h = (h * 1000003) ^ a
	h = (h * 1000003) ^ b
	h = (h * 1000003) ^ _quant(f)
	h = (h * 1000003) ^ _quant(g)
	event_hash = h


## Returns and clears the buffer. Single consumer (RunController).
func drain() -> Array[SimEvent]:
	var out: Array[SimEvent] = _buffer
	_buffer = []
	return out


## For tests: the buffer without clearing it.
func peek() -> Array[SimEvent]:
	return _buffer


static func _quant(v: float) -> int:
	if not is_finite(v):
		return -1
	return roundi(v * 1000.0)
