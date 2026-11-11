class_name IntegrationShotLog
extends RefCounted
## Test helper (W3-A): records every `Events.shot_fired` with the sim tick it arrived on (the run is stepped one tick
## per frame, so that is the tick of the shot). Call `detach` in after_test.

## Each row: Vector2i(tick, source), source = DamageSource.Id.
var shots: Array[Vector2i] = []

var _tick_source: Callable = Callable()


## `tick_source` is a Callable returning the current sim tick.
func attach(tick_source: Callable) -> void:
	detach()
	_tick_source = tick_source
	Events.shot_fired.connect(_on_shot)


func detach() -> void:
	if Events.shot_fired.is_connected(_on_shot):
		Events.shot_fired.disconnect(_on_shot)


## Ticks of the shots of `source` in (from_tick, to_tick].
func ticks_of(source: int, from_tick: int, to_tick: int) -> Array[int]:
	var out: Array[int] = []
	for s: Vector2i in shots:
		if s.y == source and s.x > from_tick and s.x <= to_tick:
			out.append(s.x)
	return out


func count_of(source: int, from_tick: int, to_tick: int) -> int:
	return ticks_of(source, from_tick, to_tick).size()


## Sources that fired at least once in (from_tick, to_tick].
func sources_in(from_tick: int, to_tick: int) -> Array[int]:
	var out: Array[int] = []
	for s: Vector2i in shots:
		if s.x > from_tick and s.x <= to_tick and not out.has(s.y):
			out.append(s.y)
	out.sort()
	return out


## Smallest gap between consecutive entries (0 when fewer than two).
static func min_gap(ticks: Array[int]) -> int:
	var best: int = 0
	for i: int in range(1, ticks.size()):
		var gap: int = ticks[i] - ticks[i - 1]
		if best == 0 or gap < best:
			best = gap
	return best


func _on_shot(source: int, _target_id: int) -> void:
	var tick: int = _tick_source.call()
	shots.append(Vector2i(tick, source))
