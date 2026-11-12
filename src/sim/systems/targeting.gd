class_name Targeting
extends RefCounted
## Target ranking and the lock rule (ARCH 6.6 "Combat", GDD 5.1). Shared by the Warden and the turrets.
##
## Rank order, best first: (1) attacking the core, (2) lower ETA bucket, (3) Rusher class,
## (4) smaller squared distance to the shooter, (5) lower stable id.

const NO_BUCKET: int = 1 << 30  ## ETA bucket of an enemy that can never arrive (speed 0)


## Enemy id of the best living enemy within range_m of (from_x, from_z), or 0.
static func pick(world: SimWorld, from_x: float, from_z: float, range_m: float) -> int:
	var store: EnemyStore = world.enemies
	var range_sq: float = range_m * range_m
	var best: int = -1
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if _dist_sq(store, i, from_x, from_z) > range_sq:
			continue
		if best < 0 or compare(world, i, best, from_x, from_z):
			best = i
	if best < 0:
		return 0
	return store.id[best]


## True while the enemy is alive and within range_m of the shooter.
static func is_valid(world: SimWorld, enemy_id: int, from_x: float, from_z: float, range_m: float) -> bool:
	var i: int = world.enemies.index_of(enemy_id)
	if i < 0:
		return false
	return _dist_sq(world.enemies, i, from_x, from_z) <= range_m * range_m


## True if store index i outranks j. A tie on every criterion cannot happen: ids are unique.
static func compare(world: SimWorld, i: int, j: int, from_x: float, from_z: float) -> bool:
	if i == j:
		return false
	var store: EnemyStore = world.enemies
	var i_attacking: bool = store.state[i] == EnemyStore.ST_ATTACKING
	var j_attacking: bool = store.state[j] == EnemyStore.ST_ATTACKING
	if i_attacking != j_attacking:
		return i_attacking
	var i_bucket: int = eta_bucket(world, i)
	var j_bucket: int = eta_bucket(world, j)
	if i_bucket != j_bucket:
		return i_bucket < j_bucket
	var i_rusher: bool = world.content.enemies[store.type[i]].priority_class
	var j_rusher: bool = world.content.enemies[store.type[j]].priority_class
	if i_rusher != j_rusher:
		return i_rusher
	var i_dist: float = _dist_sq(store, i, from_x, from_z)
	var j_dist: float = _dist_sq(store, j, from_x, from_z)
	if i_dist != j_dist:
		return i_dist < j_dist
	return store.id[i] < store.id[j]


## floor(eta_ticks / eta_bucket_ticks) with eta_ticks = path_dist / (speed_mps * DT).
static func eta_bucket(world: SimWorld, index: int) -> int:
	var per_tick: float = world.content.enemies[world.enemies.type[index]].speed_mps * SimWorld.DT
	if per_tick <= 0.0:
		return NO_BUCKET
	var bucket_ticks: int = maxi(1, world.content.mission.eta_bucket_ticks)
	var eta_ticks: float = world.enemies.path_dist[index] / per_tick
	return floori(eta_ticks / float(bucket_ticks))


## One shooter's lock rule for this tick. Returns [target_id, lock_ticks_left] (target_id 0 = none).
## The lock counts down first. The target is kept while the lock is still running and the target is valid
## (alive, in range). Otherwise the shooter drops it, picks anew the same tick and the lock restarts at
## lock_ticks. A pick on tick T therefore holds the target for lock_ticks ticks (T .. T + lock_ticks - 1).
static func refresh_lock(
	world: SimWorld,
	target_id: int,
	lock_left: int,
	from_x: float,
	from_z: float,
	range_m: float,
	lock_ticks: int
) -> PackedInt32Array:
	var left: int = maxi(0, lock_left - 1)
	if target_id != 0 and left > 0 and is_valid(world, target_id, from_x, from_z, range_m):
		return PackedInt32Array([target_id, left])
	var picked: int = pick(world, from_x, from_z, range_m)
	if picked == 0:
		return PackedInt32Array([0, 0])
	return PackedInt32Array([picked, lock_ticks])


static func _dist_sq(store: EnemyStore, index: int, from_x: float, from_z: float) -> float:
	var dx: float = store.x[index] - from_x
	var dz: float = store.z[index] - from_z
	return dx * dx + dz * dz


# --- variety milestone (VARIETY_SPEC 13.2): new queries; the signatures above are frozen ---


## The centre of the densest cluster: the point (an enemy position) with the most living enemies within `radius`,
## among enemies between `min_range` and `max_range` of (from_x, from_z); ties by the best-ranked enemy in it.
## Returns (x, z), or (from_x, from_z) when no enemy is in range.
# TODO(V2-C): the stub finds no cluster.
static func pick_cluster(
	_world: SimWorld, from_x: float, from_z: float, _min_range: float, _max_range: float, _radius: float
) -> Vector2:
	return Vector2(from_x, from_z)


## The best `n` living enemies within `range_m`, in rank order, as enemy ids written to `out` (cleared first).
## Returns how many were found.
# TODO(V4-W): the stub finds none.
static func pick_many(_world: SimWorld, _from_x: float, _from_z: float, _range_m: float, _n: int, out: PackedInt32Array) -> int:
	out.clear()
	return 0
