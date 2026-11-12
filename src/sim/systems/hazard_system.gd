class_name HazardSystem
extends RefCounted
## The delayed-effect queue, ground pools, mines and fuel drums (tick step 11; VARIETY_SPEC 9.5 rule 2). The only
## writer of HazardState. At most RunDef.max_blasts_per_tick blasts resolve per tick, the rest stay queued. Called
## every tick of a live run: gate on `GameState.is_combat(world.phase)` inside.
# TODO(V2-C): queue, blasts, pools. TODO(V4-V): mines, drums, the core vent.


static func step(_world: SimWorld) -> void:
	pass


## Queues a hit that lands at `due_tick` (HazardState.K_* kind). Pushes DELAYED_HIT_LAUNCHED. Returns its sequence
## number, or -1 when nothing was queued.
static func queue_hit(
	_world: SimWorld, _due_tick: int, _kind: int, _x: float, _z: float, _radius: float, _damage: float, _edge_frac: float,
	_flags: int, _source: int
) -> int:
	return -1


## Starts a ground pool; pushes POOL_STARTED. Returns the pool id, or -1.
static func add_pool(_world: SimWorld, _x: float, _z: float, _radius: float, _ticks: int, _dps: float, _slow: float) -> int:
	return -1


## Drops everything that is queued or burning (wave clear).
static func clear(_world: SimWorld) -> void:
	pass
