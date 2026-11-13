class_name FireTargets
extends RefCounted
## Target picks of the missile salvo (VARIETY_SPEC 3.3 kind M) and the geometry the cone and line kinds share. The body of
## `Targeting.pick_many` lives here because targeting.gd belongs to another task of wave V4 (V4-N): that stub should
## return `FireTargets.pick_many(...)`; the contract is the same. Ranking is `Targeting.compare` (so the mini rule and
## the MAGNETIC and SHROUDED effects of V4-N apply by themselves) and range is `Targeting.is_valid`.


## The best `n` living enemies within `range_m` of (x, z), in rank order, as enemy ids written to `out` (cleared first).
## Returns how many were found.
static func pick_many(world: SimWorld, x: float, z: float, range_m: float, n: int, out: PackedInt32Array) -> int:
	out.clear()
	if n <= 0:
		return 0
	var store: EnemyStore = world.enemies
	var best: PackedInt32Array = PackedInt32Array()  # store indices, best first
	for i: int in store.high_water:
		if store.alive[i] == 0 or not Targeting.is_valid(world, store.id[i], x, z, range_m):
			continue
		var at: int = best.size()
		while at > 0 and Targeting.compare(world, i, best[at - 1], x, z):
			at -= 1
		if at >= n:
			continue
		best.insert(at, i)
		if best.size() > n:
			best.resize(n)
	for i: int in best:
		out.append(store.id[i])
	return out.size()


## The `n` enemy ids of one missile salvo: the locked target first, then the best-ranked others; when fewer than `n`
## enemies are in range the list repeats from the start. Empty when nothing is in range.
static func salvo_targets(
	world: SimWorld, locked_id: int, x: float, z: float, range_m: float, n: int
) -> PackedInt32Array:
	var ranked: PackedInt32Array = PackedInt32Array()
	pick_many(world, x, z, range_m, n, ranked)
	var distinct: PackedInt32Array = PackedInt32Array()
	if locked_id != 0 and world.enemies.index_of(locked_id) >= 0:
		distinct.append(locked_id)
	for enemy_id: int in ranked:
		if distinct.size() < n and not distinct.has(enemy_id):
			distinct.append(enemy_id)
	var out: PackedInt32Array = PackedInt32Array()
	if distinct.is_empty():
		return out
	for k: int in n:
		out.append(distinct[k % distinct.size()])
	return out


## The distance from (px, pz) to the segment (ax, az)-(bx, bz), and the position of the nearest point along the segment as
## a fraction written to `frac` (0 at A, 1 at B).
static func segment_distance(
	px: float, pz: float, ax: float, az: float, bx: float, bz: float, frac: PackedFloat64Array
) -> float:
	var sx: float = bx - ax
	var sz: float = bz - az
	var len_sq: float = sx * sx + sz * sz
	var t: float = 0.0
	if len_sq > 0.0:
		t = clampf(((px - ax) * sx + (pz - az) * sz) / len_sq, 0.0, 1.0)
	frac[0] = t
	var dx: float = px - (ax + sx * t)
	var dz: float = pz - (az + sz * t)
	return sqrt(dx * dx + dz * dz)


## Store indices of the enemies a chain of up to `jumps` bolts reaches from (x, z): each jump goes to the nearest living
## enemy not yet taken within `reach` of the last one (the lower id on a tie); `skip_id` (the enemy the chain starts
## from, 0 for none) is never taken. Positions are those of now, so call it before any damage is dealt.
static func chain_victims(
	world: SimWorld, x: float, z: float, skip_id: int, jumps: int, reach: float
) -> PackedInt32Array:
	var store: EnemyStore = world.enemies
	var taken: PackedInt32Array = PackedInt32Array([skip_id])
	var out: PackedInt32Array = PackedInt32Array()
	var at_x: float = x
	var at_z: float = z
	for _jump: int in jumps:
		var best: int = -1
		var best_sq: float = reach * reach
		for i: int in store.high_water:
			if store.alive[i] == 0 or taken.has(store.id[i]):
				continue
			var dx: float = store.x[i] - at_x
			var dz: float = store.z[i] - at_z
			var d_sq: float = dx * dx + dz * dz
			if d_sq > best_sq:
				continue
			if best < 0 or d_sq < best_sq or store.id[i] < store.id[best]:
				best = i
				best_sq = d_sq
		if best < 0:
			break
		out.append(best)
		taken.append(store.id[best])
		at_x = store.x[best]
		at_z = store.z[best]
	return out
