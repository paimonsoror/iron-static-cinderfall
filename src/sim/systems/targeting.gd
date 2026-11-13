class_name Targeting
extends RefCounted
## Target ranking and the lock rule (ARCH 6.6 "Combat", GDD 5.1). Shared by the Warden and the turrets.
##
## Rank order, best first: (1) attacking the core, (2) lower ETA bucket, (3) Rusher class,
## (4) smaller squared distance to the shooter, (5) lower stable id.
##
## Variety content (VARIETY_SPEC 5.1, 5.2, 5.4; the legacy content has none of these, so its order is unchanged):
## - "attacking the core" is ST_ATTACKING for a slot-taker, and for a standoff enemy only once it has fired (F_FIRED):
##   a parked reclaimer, or a spitter that has not shot yet, is ranked as a mover (with ETA bucket 0);
## - the mini rule: with equal ETA bucket a bodied enemy outranks a mini (rules 1 and 2 already put an attacking or
##   nearer body first), so a mini is shot only when it is strictly nearer the core than every body in range;
## - a body still under the ground (F_EMERGING) is no target;
## - SHROUDED: no target for a shooter farther than EliteSystem.SHROUD_RANGE_M;
## - MAGNETIC: while a MAGNETIC elite is in range and within EliteSystem.MAGNETIC_RANGE_M of the shooter, the shooter
##   must target a MAGNETIC elite (the best ranked one): `pick` returns it and `is_valid` drops any other target
##   (`is_valid` looks for one only while NavState.magnets, counted by StatusSystem every tick, is not 0).

const NO_BUCKET: int = 1 << 30  ## ETA bucket of an enemy that can never arrive (speed 0)
const MAGNETIC_SQ: float = EliteSystem.MAGNETIC_RANGE_M * EliteSystem.MAGNETIC_RANGE_M
const SHROUD_SQ: float = EliteSystem.SHROUD_RANGE_M * EliteSystem.SHROUD_RANGE_M


## Enemy id of the best living enemy within range_m of (from_x, from_z), or 0.
static func pick(world: SimWorld, from_x: float, from_z: float, range_m: float) -> int:
	var store: EnemyStore = world.enemies
	var range_sq: float = range_m * range_m
	var best: int = -1
	if world.content.run == null:
		for i: int in store.high_water:
			if store.alive[i] == 0:
				continue
			if _dist_sq(store, i, from_x, from_z) > range_sq:
				continue
			if best < 0 or compare(world, i, best, from_x, from_z):
				best = i
		return store.id[best] if best >= 0 else 0
	var magnet: int = -1
	var masks: PackedInt32Array = world.ext.affix_mask
	var flags: PackedInt32Array = world.ext.flags
	var magnetic: int = world.nav.aff[EliteSystem.A_MAGNETIC]
	var shroud: int = world.nav.aff[EliteSystem.A_SHROUD]
	var alive: PackedByteArray = store.alive
	var xs: PackedFloat64Array = store.x
	var zs: PackedFloat64Array = store.z
	for i: int in store.high_water:
		if alive[i] == 0:
			continue
		var dx: float = xs[i] - from_x
		var dz: float = zs[i] - from_z
		var d2: float = dx * dx + dz * dz
		if d2 > range_sq or (flags[i] & EnemyExtState.F_EMERGING) != 0:
			continue
		if masks[i] != 0:
			if d2 > SHROUD_SQ and (masks[i] & shroud) != 0:
				continue
			if (masks[i] & magnetic) != 0 and d2 <= MAGNETIC_SQ:
				if magnet < 0 or compare(world, i, magnet, from_x, from_z):
					magnet = i
		if best < 0 or compare(world, i, best, from_x, from_z):
			best = i
	if magnet >= 0:
		return store.id[magnet]
	return store.id[best] if best >= 0 else 0


## True while the enemy is alive and within range_m of the shooter.
static func is_valid(world: SimWorld, enemy_id: int, from_x: float, from_z: float, range_m: float) -> bool:
	var i: int = world.enemies.index_of(enemy_id)
	if i < 0:
		return false
	var d2: float = _dist_sq(world.enemies, i, from_x, from_z)
	if d2 > range_m * range_m:
		return false
	if world.content.run == null:
		return true
	if not _targetable(world, i, d2):
		return false
	if world.nav.magnets == 0:
		return true
	var magnetic: int = world.nav.aff[EliteSystem.A_MAGNETIC]
	if (world.ext.affix_mask[i] & magnetic) != 0 and d2 <= MAGNETIC_SQ:
		return true
	return _magnet_in_reach(world, from_x, from_z, range_m * range_m) < 0


## True if store index i outranks j. A tie on every criterion cannot happen: ids are unique.
static func compare(world: SimWorld, i: int, j: int, from_x: float, from_z: float) -> bool:
	if i == j:
		return false
	var store: EnemyStore = world.enemies
	var i_attacking: bool = store.state[i] == EnemyStore.ST_ATTACKING and _strikes(world, i)
	var j_attacking: bool = store.state[j] == EnemyStore.ST_ATTACKING and _strikes(world, j)
	if i_attacking != j_attacking:
		return i_attacking
	var i_bucket: int = eta_bucket(world, i)
	var j_bucket: int = eta_bucket(world, j)
	if i_bucket != j_bucket:
		return i_bucket < j_bucket
	var i_mini: bool = (world.ext.flags[i] & EnemyExtState.F_MINI) != 0
	var j_mini: bool = (world.ext.flags[j] & EnemyExtState.F_MINI) != 0
	if i_mini != j_mini:
		return j_mini
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
static func pick_cluster(
	world: SimWorld, from_x: float, from_z: float, min_range: float, max_range: float, radius: float
) -> Vector2:
	return AreaDamage.densest_cluster(world, from_x, from_z, min_range, max_range, radius)


## The best `n` living enemies within `range_m`, in rank order, as enemy ids written to `out` (cleared first).
## MAGNETIC elites within their pull come first (in rank order), then everything else. Returns how many were found.
static func pick_many(world: SimWorld, from_x: float, from_z: float, range_m: float, n: int, out: PackedInt32Array) -> int:
	out.clear()
	if n <= 0:
		return 0
	var store: EnemyStore = world.enemies
	var variety: bool = world.content.run != null
	var range_sq: float = range_m * range_m
	var magnetic: int = world.nav.aff[EliteSystem.A_MAGNETIC] if variety else 0
	var ranked: PackedInt32Array = PackedInt32Array()  # store indices, best first, at most n
	var pulled: PackedByteArray = PackedByteArray()  # parallel: 1 = a MAGNETIC elite within its pull
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var d2: float = _dist_sq(store, i, from_x, from_z)
		if d2 > range_sq or (variety and not _targetable(world, i, d2)):
			continue
		var pull: int = 1 if (magnetic != 0 and (world.ext.affix_mask[i] & magnetic) != 0 and d2 <= MAGNETIC_SQ) else 0
		var at: int = ranked.size()
		while at > 0 and (pull > pulled[at - 1] or (pull == pulled[at - 1] and compare(world, i, ranked[at - 1], from_x, from_z))):
			at -= 1
		if at >= n:
			continue
		ranked.insert(at, i)
		pulled.insert(at, pull)
		if ranked.size() > n:
			ranked.resize(n)
			pulled.resize(n)
	for i: int in ranked:
		out.append(store.id[i])
	return out.size()


## False for a body under the ground, and for a SHROUDED elite farther than its shroud range (`d2` = squared distance
## to the shooter). Variety content only.
static func _targetable(world: SimWorld, index: int, d2: float) -> bool:
	var ext: EnemyExtState = world.ext
	if (ext.flags[index] & EnemyExtState.F_EMERGING) != 0:
		return false
	var mask: int = ext.affix_mask[index]
	return mask == 0 or d2 <= SHROUD_SQ or (mask & world.nav.aff[EliteSystem.A_SHROUD]) == 0


## True when an enemy in ST_ATTACKING really is attacking the core: a slot-taker and a planted boss always, another
## standoff enemy once it fired.
static func _strikes(world: SimWorld, index: int) -> bool:
	var t: int = world.enemies.type[index]
	if world.nav.t_standoff[t] == 0 or world.nav.t_boss[t] == 1:
		return true
	return (world.ext.flags[index] & EnemyExtState.F_FIRED) != 0


## Store index of a living, targetable MAGNETIC elite within `range_sq` and its pull of the shooter, or -1.
static func _magnet_in_reach(world: SimWorld, from_x: float, from_z: float, range_sq: float) -> int:
	var store: EnemyStore = world.enemies
	var masks: PackedInt32Array = world.ext.affix_mask
	var magnetic: int = world.nav.aff[EliteSystem.A_MAGNETIC]
	for i: int in store.high_water:
		if store.alive[i] == 0 or (masks[i] & magnetic) == 0:
			continue
		var d2: float = _dist_sq(store, i, from_x, from_z)
		if d2 <= range_sq and d2 <= MAGNETIC_SQ and _targetable(world, i, d2):
			return i
	return -1
