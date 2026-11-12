class_name PlanRng
extends RefCounted
## The `plan.*` streams of VARIETY_SPEC 9.2. Each is a RandomNumberGenerator seeded exactly like `SimRng.stream(name)`
## (hash of "<run seed>|<name>"), but owned by the code that builds the plan: the plan is decided at tick 0 and stored in
## the RunPlan, so the stream states are never needed again and building a world draws nothing from `world.rng`.


## A fresh stream of `stream_name` for the run `run_seed`; the first draw equals the first draw of `SimRng.stream`.
static func stream(run_seed: int, stream_name: StringName) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = ("%d|%s" % [run_seed, String(stream_name)]).hash()
	return r


## One draw in [0, 1).
static func unit(r: RandomNumberGenerator) -> float:
	return r.randf_range(0.0, 1.0)


## True with probability `p` (always one draw).
static func chance(r: RandomNumberGenerator, p: float) -> bool:
	return unit(r) < p


## An index in [0, n) (always one draw, so the position of the stream never depends on n; 0 when n <= 1).
static func index(r: RandomNumberGenerator, n: int) -> int:
	return r.randi_range(0, maxi(0, n - 1))


## An index chosen with `weights` (always one draw), or -1 when every weight is zero.
static func weighted(r: RandomNumberGenerator, weights: PackedFloat64Array) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += maxf(0.0, w)
	var roll: float = unit(r) * total
	if not total > 0.0:
		return -1
	var acc: float = 0.0
	var last: int = -1
	for i: int in weights.size():
		if not weights[i] > 0.0:
			continue
		last = i
		acc += weights[i]
		if roll < acc:
			return i
	return last
