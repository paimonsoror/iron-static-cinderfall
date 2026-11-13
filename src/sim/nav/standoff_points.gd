class_name StandoffPoints
extends RefCounted
## Standoff points (VARIETY_SPEC 5.1; arena.json schema 2 `standoff`): the places where a standoff enemy (spitter,
## reclaimer) parks instead of taking an attack slot. A ring of points per standoff distance, on the slot arc, every
## ring outside the approach circle (the validator checks it), so a point never overlaps an attack slot.
##
## Occupancy is not stored: a point is taken while a living enemy holds its index in `EnemyExtState.anchor_point`.
## Claims are made by MovementSystem at the end of a tick, in ascending enemy id order.

## A standoff mover claims its point when it is within its standoff distance plus this margin of the core.
const CLAIM_MARGIN_M: float = 2.5
const RADIUS_EPS: float = 0.001


## Index into ArenaDef.standoff_radii of the ring at `standoff_m`, or -1.
static func ring_of(arena: ArenaDef, standoff_m: float) -> int:
	if standoff_m <= 0.0:
		return -1
	for r: int in arena.standoff_radii.size():
		if absf(arena.standoff_radii[r] - standoff_m) < RADIUS_EPS:
			return r
	return -1


## Store index of the living enemy that holds standoff point `point`, or -1.
static func holder(world: SimWorld, point: int) -> int:
	var es: EnemyStore = world.enemies
	var anchor: PackedInt32Array = world.ext.anchor_point
	for j: int in es.high_water:
		if es.alive[j] == 1 and anchor[j] == point:
			return j
	return -1


## Gives enemy `enemy_index` the nearest free point of its type's ring (tie: the lower point index) and writes it to
## `ext.anchor_point`. Returns the point index, or -1 when the ring has no free point. An enemy that already holds a
## point keeps it.
static func claim(world: SimWorld, enemy_index: int) -> int:
	var es: EnemyStore = world.enemies
	var ext: EnemyExtState = world.ext
	if ext.anchor_point[enemy_index] >= 0:
		return ext.anchor_point[enemy_index]
	var nav: NavState = world.nav
	var ring: int = nav.t_ring[es.type[enemy_index]]
	if ring < 0:
		return -1
	var rings: PackedInt32Array = world.content.arena.standoff_ring
	var taken: PackedByteArray = PackedByteArray()
	taken.resize(rings.size())
	for j: int in es.high_water:
		if es.alive[j] == 1 and ext.anchor_point[j] >= 0 and ext.anchor_point[j] < taken.size():
			taken[ext.anchor_point[j]] = 1
	var px: float = es.x[enemy_index]
	var pz: float = es.z[enemy_index]
	var best: int = -1
	var best_d2: float = INF
	for k: int in rings.size():
		if rings[k] != ring or taken[k] == 1:
			continue
		var dx: float = nav.sp_x[k] - px
		var dz: float = nav.sp_z[k] - pz
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			best = k
	if best >= 0:
		ext.anchor_point[enemy_index] = best
	return best


## Free points left on ring `ring`.
static func free_count(world: SimWorld, ring: int) -> int:
	var rings: PackedInt32Array = world.content.arena.standoff_ring
	var n: int = 0
	for k: int in rings.size():
		if rings[k] == ring and holder(world, k) < 0:
			n += 1
	return n
