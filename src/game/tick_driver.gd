class_name TickDriver
extends RefCounted
## Fixed-step accumulator (ARCH 7.3). TODO(W2-A).

@warning_ignore_start("unused_parameter")

const MAX_TICKS_PER_FRAME: int = 4

var acc: float = 0.0
var dropped_ticks: int = 0


## Runs floor(acc / DT) ticks, capped; extra time is dropped, never carried. Returns the ticks run.
func advance(world: SimWorld, delta: float) -> int:
	# TODO(W2-A)
	return 0


## acc / DT, for interpolation.
func alpha() -> float:
	# TODO(W2-A)
	return 0.0
