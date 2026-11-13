class_name MovementSystem
extends RefCounted
## Flow following, separation, attack slots and stuck recovery (ARCH 6.6, GDD 6).
## One tick: copy prev positions, rebuild the spatial hash, then visit enemies in store order and move each one
## (positions are written as we go; the visiting order is deterministic). The 50-enemy budget is under 1 ms per tick
## in GDScript, so the expensive steering (flow heading, weave, line of sight, separation push, stuck bookkeeping) is
## refreshed every RESAMPLE_TICKS ticks per enemy, staggered by id, and the cached per-tick displacement is applied
## in between. Slot claims are collected and made at the end of the tick in ascending id order. Stunned enemies are
## frozen. Attackers stand on their slot and are neither pushed nor pushing. Nothing here removes an enemy.
## Minis (EnemyExtState.F_MINI, VARIETY_SPEC 5.4) take the cheap path: the flow heading (straight at the core inside the
## approach circle), no weave, no separation (they neither push nor are pushed), no slot. They wait just inside their
## burnout range (MINI_HOLD_MARGIN_M) for CoreAttackSystem, and keep the stuck window so a wedged mini cannot stall a wave.
## Standoff types (spitter, reclaimer) claim a standoff point instead of a slot (StandoffPoints) once they are within
## their standoff distance plus a margin, walk to it and park there (ST_ATTACKING with `slot` -1). An enemy that is still
## under the ground (F_EMERGING, the borer) does not move. Every displacement is scaled by `nav.speed_mul` (slow, SWIFT,
## the overclock aura), which StatusSystem derives earlier in the tick; it is exactly 1.0 for a plain enemy.
## The helpers (separation, prop fence, claims, capture, settle) live in NavSteering.

## Within this distance of its slot a seeking enemy is captured: ST_ATTACKING, then it settles onto the slot.
const SNAP_M: float = 0.25
## Two enemies keep this fraction of the sum of their radii between centers.
const SEP_SPACE: float = 0.75
## Fraction of the overlap resolved per tick (before weight and mass share): 0.4 per steering period of 6 ticks.
const SEP_GAIN: float = 0.0667
const SEP_MAX_NEIGHBORS: int = 6
## Hard bound on one tick's displacement, in multiples of speed * DT.
const MAX_STEP_MULT: float = 1.5
const GOLDEN_ANGLE: float = 2.399963229728653
const PUSH_EPS: float = 0.000001
## A mini stops this far inside its burnout range (`burnout_m`, CONTENT 4.2: 0.6 m from the cage), so CoreAttackSystem
## always reaches it.
const MINI_HOLD_MARGIN_M: float = 0.1
## Enemies with one of these flags neither push nor are pushed: minis and bodies still under the ground.
const F_NO_PUSH: int = EnemyExtState.F_MINI | EnemyExtState.F_EMERGING
## A knockback moves a body of at most this mass by the full distance; heavier bodies move mass-proportionally less.
const KNOCKBACK_FULL_MASS: float = 1.5


static func step(world: SimWorld) -> void:
	var es: EnemyStore = world.enemies
	var nav: NavState = world.nav
	var arena: ArenaDef = world.content.arena
	nav.light_radius = nav.spatial.rebuild_movers(
		es, EnemyStore.ST_ATTACKING, nav.t_radius, NavState.HEAVY_RADIUS_M, nav.heavy
	)
	nav.claims.clear()
	var alive: PackedByteArray = es.alive
	var ex: PackedFloat64Array = es.x
	var ez: PackedFloat64Array = es.z
	var prev_x: PackedFloat64Array = es.prev_x
	var prev_z: PackedFloat64Array = es.prev_z
	var ids: PackedInt32Array = es.id
	var types: PackedByteArray = es.type
	var states: PackedByteArray = es.state
	var slot_of: PackedInt32Array = es.slot
	var stun: PackedInt32Array = es.stun_ticks
	var track_id: PackedInt32Array = nav.track_id
	var ttl: PackedInt32Array = nav.c_ttl
	var c_vx: PackedFloat64Array = nav.c_vx
	var c_vz: PackedFloat64Array = nav.c_vz
	var t_step: PackedFloat64Array = nav.t_step
	var t_clear: PackedFloat64Array = nav.t_clear
	var t_claim2: PackedFloat64Array = nav.t_claim2
	var t_hold2: PackedFloat64Array = nav.t_hold2
	var speed_mul: PackedFloat64Array = nav.speed_mul
	var zone: PackedByteArray = nav.zone
	var gcols: int = nav.flow.grid.cols
	var gox: float = nav.flow.grid.origin_x
	var goz: float = nav.flow.grid.origin_z
	var ginv: float = 1.0 / nav.flow.grid.cell_m
	var core_x: float = arena.core_x
	var core_z: float = arena.core_z
	var core_radius: float = arena.core_radius
	var bmin_x: float = nav.bound_min_x
	var bmax_x: float = nav.bound_max_x
	var bmin_z: float = nav.bound_min_z
	var bmax_z: float = nav.bound_max_z
	var xflags: PackedInt32Array = world.ext.flags
	var anchor: PackedInt32Array = world.ext.anchor_point
	for i: int in es.high_water:
		if alive[i] == 0:
			continue
		var px: float = ex[i]
		var pz: float = ez[i]
		prev_x[i] = px
		prev_z[i] = pz
		var xf: int = xflags[i]
		if stun[i] > 0 or (xf & EnemyExtState.F_EMERGING) != 0:
			continue
		var enemy_id: int = ids[i]
		if track_id[i] != enemy_id:
			px = clampf(px, nav.bound_min_x, nav.bound_max_x)
			pz = clampf(pz, nav.bound_min_z, nav.bound_max_z)
			ex[i] = px
			ez[i] = pz
			es.path_dist[i] = nav.path_dist_of(es, i)
			nav.track(i, enemy_id, es.path_dist[i])
		var t: int = types[i]
		var k: float = speed_mul[i]
		var spd: float = t_step[t] * k
		var st: int = states[i]
		if st == EnemyStore.ST_ATTACKING:
			if nav.grace[i] == NavState.SETTLING:
				NavSteering.settle(world, nav, es, i, px, pz, spd)
			continue
		var slot_i: int = slot_of[i]
		var tx: float = 0.0
		var tz: float = 0.0
		if st == EnemyStore.ST_SEEK_SLOT:
			if slot_i >= 0:
				tx = nav.slots.pos_x[slot_i]
				tz = nav.slots.pos_z[slot_i]
			elif anchor[i] >= 0:
				tx = nav.sp_x[anchor[i]]
				tz = nav.sp_z[anchor[i]]
			else:
				st = EnemyStore.ST_MOVING
				states[i] = st
		var cdx: float = px - core_x
		var cdz: float = pz - core_z
		var core_d2: float = cdx * cdx + cdz * cdz
		var is_mini: bool = (xf & EnemyExtState.F_MINI) != 0
		if is_mini and core_d2 <= t_hold2[t]:
			es.path_dist[i] = 0.0
			continue
		var left: int = ttl[i] - 1
		ttl[i] = left
		var mx: float
		var mz: float
		if st == EnemyStore.ST_MOVING:
			if core_d2 <= t_claim2[t]:
				nav.claims.append(i)
			if left <= 0 and _resample(world, es, nav, arena, i, t, enemy_id, st, px, pz, cdx, cdz, core_d2, 0.0, is_mini):
				continue
			mx = c_vx[i] * k
			mz = c_vz[i] * k
		else:
			var vx: float = tx - px
			var vz: float = tz - pz
			var d: float = sqrt(vx * vx + vz * vz)
			if d <= SNAP_M:
				NavSteering.capture(world, es, nav, arena, i, t, slot_i, px, pz, spd)
				continue
			es.path_dist[i] = d
			if left <= 0 and _resample(world, es, nav, arena, i, t, enemy_id, st, px, pz, cdx, cdz, core_d2, d, false):
				continue
			var reach: float = minf(spd, d)
			mx = vx / d * reach + c_vx[i] * k
			mz = vz / d * reach + c_vz[i] * k
			es.face_x[i] = vx / d
			es.face_z[i] = vz / d
			var limit: float = spd * MAX_STEP_MULT
			var ml2: float = mx * mx + mz * mz
			if ml2 > limit * limit:
				var shrink: float = limit / sqrt(ml2)
				mx *= shrink
				mz *= shrink
		var qx: float = px + mx
		var qz: float = pz + mz
		var zf: int = zone[int((pz - goz) * ginv) * gcols + int((px - gox) * ginv)]
		if zf != 0:
			if (zf & NavState.ZONE_PROPS) != 0:
				NavSteering.push_props(nav, arena, t_clear[t], px, pz, qx, qz)
				qx = nav.fix[0]
				qz = nav.fix[1]
			if (zf & NavState.ZONE_CORE) != 0:
				var core_r: float = core_radius + t_clear[t]
				var ex2: float = qx - core_x
				var ez2: float = qz - core_z
				var e2: float = ex2 * ex2 + ez2 * ez2
				if e2 < core_r * core_r:
					var e: float = sqrt(e2)
					if e < 0.000000001:
						ex2 = 1.0
						ez2 = 0.0
						e = 1.0
					qx = core_x + ex2 / e * (core_r + PUSH_EPS)
					qz = core_z + ez2 / e * (core_r + PUSH_EPS)
			if qx < bmin_x:
				qx = bmin_x
			elif qx > bmax_x:
				qx = bmax_x
			if qz < bmin_z:
				qz = bmin_z
			elif qz > bmax_z:
				qz = bmax_z
		ex[i] = qx
		ez[i] = qz
	if not nav.claims.is_empty():
		NavSteering.make_claims(world, es, nav)


## Shoves the enemy at store index `enemy_index` by `meters` along (dir_x, dir_z) now (scattergun, core vent, freight).
## A body heavier than KNOCKBACK_FULL_MASS moves mass-proportionally less; a boss, an ANCHORED elite, a parked standoff
## enemy and a body still under the ground do not move. The move is fenced like a walk (props, the core body, the
## grid); an attacker walks back to its slot afterwards. Returns the meters moved.
static func knockback(world: SimWorld, enemy_index: int, dir_x: float, dir_z: float, meters: float) -> float:
	var es: EnemyStore = world.enemies
	if enemy_index < 0 or enemy_index >= es.capacity or es.alive[enemy_index] == 0 or meters <= 0.0:
		return 0.0
	var len2: float = dir_x * dir_x + dir_z * dir_z
	var t: int = es.type[enemy_index]
	var def: EnemyDef = world.content.enemies[t]
	if len2 < 0.000000001 or def.is_boss or def.speed_mps <= 0.0 or EliteSystem.is_anchored(world, enemy_index):
		return 0.0
	if world.ext.has_flag(enemy_index, EnemyExtState.F_EMERGING):
		return 0.0
	var attacking: bool = es.state[enemy_index] == EnemyStore.ST_ATTACKING
	if attacking and es.slot[enemy_index] < 0:
		return 0.0
	var nav: NavState = world.nav
	var push: float = meters * minf(1.0, KNOCKBACK_FULL_MASS / maxf(0.001, def.mass)) / sqrt(len2)
	var px: float = es.x[enemy_index]
	var pz: float = es.z[enemy_index]
	NavSteering.fence(nav, world.content.arena, nav.t_clear[t], px, pz, px + dir_x * push, pz + dir_z * push)
	es.x[enemy_index] = nav.fix[0]
	es.z[enemy_index] = nav.fix[1]
	if attacking:
		nav.grace[enemy_index] = NavState.SETTLING
	else:
		nav.c_ttl[enemy_index] = 0
	return sqrt((nav.fix[0] - px) * (nav.fix[0] - px) + (nav.fix[1] - pz) * (nav.fix[1] - pz))


## Refreshes the cached steering of enemy `i` and its stuck bookkeeping. Moving enemies: heading from the flow field
## (or straight at the core for a direct-seeking enemy with a clear line), weave and separation push combined into one
## per-tick displacement. Seeking enemies: the separation push only (`seek_d` is the distance to the slot).
## Returns true when a stuck recovery moved the enemy (the caller skips its own move this tick).
static func _resample(
	world: SimWorld,
	es: EnemyStore,
	nav: NavState,
	arena: ArenaDef,
	i: int,
	t: int,
	enemy_id: int,
	st: int,
	px: float,
	pz: float,
	cdx: float,
	cdz: float,
	core_d2: float,
	seek_d: float,
	mini: bool
) -> bool:
	var fresh: bool = nav.c_ttl[i] < -1
	nav.c_ttl[i] = (1 + enemy_id % NavState.RESAMPLE_TICKS) if fresh else NavState.RESAMPLE_TICKS
	var spd: float = nav.t_step[t]
	var vx: float = 0.0
	var vz: float = 0.0
	var path: float = seek_d
	if st == EnemyStore.ST_MOVING:
		var sample: Vector3 = nav.flow.sample_flow(px, pz)
		var hx: float = sample.x
		var hz: float = sample.y
		var seek_core: bool = nav.t_direct[t] == 1 or (mini and core_d2 <= arena.approach_radius * arena.approach_radius)
		if seek_core and core_d2 > 0.0001:
			if NavGeometry.segment_clear(arena.obstacles, px, pz, arena.core_x, arena.core_z, nav.t_clear[t] + 0.1):
				var inv: float = 1.0 / sqrt(core_d2)
				hx = -cdx * inv
				hz = -cdz * inv
		if hx != 0.0 or hz != 0.0:
			es.face_x[i] = hx
			es.face_z[i] = hz
		vx = hx * spd
		vz = hz * spd
		var amp: float = nav.t_weave_amp[t]
		if amp > 0.0 and not mini:
			var rate: float = nav.t_weave_rate[t]
			var phase: float = rate * float(world.tick - es.spawn_tick[i]) + float(enemy_id) * GOLDEN_ANGLE
			var lateral: float = amp * rate * cos(phase)
			vx -= hz * lateral
			vz += hx * lateral
		path = es.path_dist[i] if is_inf(sample.z) else sample.z + nav.tail_m
		es.path_dist[i] = path
	var sepw: float = nav.t_sepw[t]
	if sepw > 0.0 and nav.sep_off[i] == 0 and not mini:
		var push: Vector2 = NavSteering.separation(es, nav, i, t, enemy_id, px, pz, sepw, spd, world.ext.flags)
		vx += push.x
		vz += push.y
	var limit: float = spd * MAX_STEP_MULT
	var v2: float = vx * vx + vz * vz
	if v2 > limit * limit:
		var shrink: float = limit / sqrt(v2)
		vx *= shrink
		vz *= shrink
	nav.c_vx[i] = vx
	nav.c_vz[i] = vz
	var elapsed: int = 1 if fresh else NavState.RESAMPLE_TICKS
	if nav.sep_off[i] > 0:
		var moved_to: float = StuckRecovery.grace_tick(world, i, path, elapsed)
		es.path_dist[i] = moved_to
		return moved_to != path
	var timer: int = nav.stuck_timer[i] + elapsed
	if timer >= world.content.mission.stuck_ticks:
		StuckRecovery.window_end(world, i, path)
	else:
		nav.stuck_timer[i] = timer
	return false
