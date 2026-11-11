class_name TickDriver
extends RefCounted
## Fixed-step accumulator (ARCH 7.3): turns frame time into whole sim ticks. 60 FPS gives one tick per frame, 30 FPS
## gives two. At most MAX_TICKS_PER_FRAME ticks run per frame; whole ticks beyond that are dropped (counted in
## `dropped_ticks`), never carried, so a hitch cannot cause a catch-up burst. The remainder below one tick is kept for
## interpolation. The driver knows nothing about pausing: a paused RunController simply does not call `advance`.

const MAX_TICKS_PER_FRAME: int = 4
## Float noise tolerance in ticks: 1/30 s must be exactly two ticks, not 1.9999999.
const EPSILON: float = 1e-6

var acc: float = 0.0
var dropped_ticks: int = 0
var ticks_run: int = 0  ## total ticks this driver has run
## Optional `func(world: SimWorld) -> void`, called before every tick (the autoplay bot and debug scenarios hook in).
var before_tick: Callable = Callable()


## Runs floor(acc / DT) ticks, capped; extra time is dropped, never carried. Returns the ticks run.
func advance(world: SimWorld, delta: float) -> int:
	if world.is_over():
		acc = 0.0
		return 0
	acc += maxf(delta, 0.0)
	var due: int = floori(acc / SimWorld.DT + EPSILON)
	var allowed: int = mini(due, MAX_TICKS_PER_FRAME)
	var ran: int = 0
	while ran < allowed and not world.is_over():
		if before_tick.is_valid():
			before_tick.call(world)
		world.step()
		ran += 1
	if world.is_over():
		acc = 0.0
	else:
		dropped_ticks += due - allowed
		acc = maxf(0.0, acc - float(due) * SimWorld.DT)
	ticks_run += ran
	return ran


## acc / DT in [0, 1], for interpolation.
func alpha() -> float:
	return clampf(acc / SimWorld.DT, 0.0, 1.0)
