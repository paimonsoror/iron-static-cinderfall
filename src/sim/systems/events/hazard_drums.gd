class_name HazardDrums
extends RefCounted
## FUEL DRUMS (VARIETY_SPEC 7.1, CONTENT 6; numbers in `hazards.fuel_drums` of events.json). At each act start three drums
## stand on three of the arena's six drum points (the plan chose them from `plan.hazard:<act>`). A drum does not block
## movement or shots. It ignites when a blast, pool, strike or freight car touches it, or after `stray_damage` of stray
## LMG or pellet damage; the ignition queues a K_DRUM blast `fuse_ticks` later (so a chain of drums, or of drums and
## bursters, is a visible ripple and never recursion), and the blast leaves a slag pool. Written to HazardState (d_*) by
## HazardSystem's callers only; the drum blast hurts enemies, never the core, the Warden or a turret.

const MILLI: float = 1000.0


## Puts the drums of `act` (1-based) on the plan's points; the drums of the act before are gone. No-op without a plan.
static func place(world: SimWorld, act: int) -> void:
	var h: HazardState = world.hazards
	h.d_point = PackedInt32Array()
	h.d_alive = PackedInt32Array()
	h.d_damage_milli = PackedInt32Array()
	if world.plan == null or world.content.run == null or not world.content.run.hazards.has(&"fuel_drums"):
		return
	var per_act: int = roundi(_num(world, &"per_act", 3.0))
	var first: int = (act - 1) * per_act
	for k: int in per_act:
		if first + k >= world.plan.drum_points.size():
			break
		var point: int = world.plan.drum_points[first + k]
		if point < 0 or point >= world.content.arena.drum_points.size():
			continue
		h.d_point.append(point)
		h.d_alive.append(1)
		h.d_damage_milli.append(0)


## The position of drum `k`.
static func position_of(world: SimWorld, k: int) -> Vector2:
	return world.content.arena.drum_points[world.hazards.d_point[k]]


## Drums standing now.
static func alive_count(world: SimWorld) -> int:
	var n: int = 0
	for a: int in world.hazards.d_alive:
		n += a
	return n


## A blast, pool pulse or freight car at (x, z) with reach `radius`: every standing drum inside it ignites.
static func touch(world: SimWorld, x: float, z: float, radius: float) -> void:
	var h: HazardState = world.hazards
	for k: int in h.d_alive.size():
		if h.d_alive[k] == 0:
			continue
		var p: Vector2 = position_of(world, k)
		var reach: float = radius + _num(world, &"radius_m", 0.4)
		var dx: float = p.x - x
		var dz: float = p.y - z
		if dx * dx + dz * dz <= reach * reach:
			ignite(world, k)


## The freight car sweeps the lane |z - lane_z| <= half_width from x_lo to x_hi: every standing drum in it ignites.
static func touch_lane(world: SimWorld, lane_z: float, half_width: float, x_lo: float, x_hi: float) -> void:
	var h: HazardState = world.hazards
	var drum_r: float = _num(world, &"radius_m", 0.4)
	for k: int in h.d_alive.size():
		if h.d_alive[k] == 0:
			continue
		var p: Vector2 = position_of(world, k)
		if p.x >= x_lo - drum_r and p.x <= x_hi + drum_r and absf(p.y - lane_z) <= half_width + drum_r:
			ignite(world, k)


## Stray damage (a missed LMG round, a pellet that found no enemy) that landed at (x, z): drums within their own radius
## take it; a drum that has taken `stray_damage` ignites. Fire kinds call this for shots that hit nothing.
static func stray(world: SimWorld, x: float, z: float, damage: float) -> void:
	var h: HazardState = world.hazards
	var reach: float = _num(world, &"radius_m", 0.4)
	for k: int in h.d_alive.size():
		if h.d_alive[k] == 0:
			continue
		var p: Vector2 = position_of(world, k)
		var dx: float = p.x - x
		var dz: float = p.y - z
		if dx * dx + dz * dz <= reach * reach:
			hit(world, k, damage)


## Fills `out` with the indices of the standing drums within `reach` of (x, z), nearest first (ties: the lower index), and
## returns how many. A fire kind that lets a stray round go to a neighbour of its target offers it the drums here.
static func standing_near(world: SimWorld, x: float, z: float, reach: float, out: PackedInt32Array) -> int:
	var h: HazardState = world.hazards
	var dist: PackedFloat64Array = PackedFloat64Array()
	out.clear()
	for k: int in h.d_alive.size():
		if h.d_alive[k] == 0:
			continue
		var p: Vector2 = position_of(world, k)
		var dx: float = p.x - x
		var dz: float = p.y - z
		var d2: float = dx * dx + dz * dz
		if d2 > reach * reach:
			continue
		var at: int = out.size()
		while at > 0 and dist[at - 1] > d2:
			at -= 1
		out.insert(at, k)
		dist.insert(at, d2)
	return out.size()


## One round of damage on standing drum `k` (a stray round that was sent at it): the damage adds to what it has taken, and it
## ignites when that reaches `stray_damage`. A drum that is gone takes nothing.
static func hit(world: SimWorld, k: int, damage: float) -> void:
	var h: HazardState = world.hazards
	if k < 0 or k >= h.d_alive.size() or h.d_alive[k] == 0:
		return
	h.d_damage_milli[k] += roundi(damage * MILLI)
	if h.d_damage_milli[k] >= roundi(_num(world, &"stray_damage", 80.0) * MILLI):
		ignite(world, k)


## Lights drum `k` (a no-op for one that is gone): it is removed now and its blast lands `fuse_ticks` later.
static func ignite(world: SimWorld, k: int) -> void:
	var h: HazardState = world.hazards
	if k < 0 or k >= h.d_alive.size() or h.d_alive[k] == 0:
		return
	h.d_alive[k] = 0
	var p: Vector2 = position_of(world, k)
	var due: int = world.tick + maxi(1, roundi(_num(world, &"fuse_ticks", 6.0)))
	HazardSystem.queue_hit(
		world, due, HazardState.K_DRUM, p.x, p.y, _num(world, &"blast_radius_m", 3.0), _num(world, &"blast_damage", 150.0), 1.0,
		DamageResolver.F_AREA | DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.HAZARD
	)


## A drum blast has landed at (x, z): the slag pool it leaves.
static func after_blast(world: SimWorld, x: float, z: float) -> void:
	var ticks: int = roundi(_num(world, &"slag_s", 5.0) * 60.0)
	var _pool: int = HazardSystem.add_pool(
		world, x, z, _num(world, &"slag_radius_m", 2.2), ticks, _num(world, &"slag_dps", 15.0), _num(world, &"slag_slow", 0.25)
	)


static func _num(world: SimWorld, key: StringName, fallback: float) -> float:
	return hazard_num(world, &"fuel_drums", key, fallback)


## One number of `hazards.<hazard>` in events.json, or `fallback` (also for the legacy content).
static func hazard_num(world: SimWorld, hazard: StringName, key: StringName, fallback: float) -> float:
	var run: RunDef = world.content.run
	if run == null or not run.hazards.has(hazard):
		return fallback
	var row: Dictionary = run.hazards[hazard]
	if not row.has(key):
		return fallback
	var value: float = row[key]
	return value
