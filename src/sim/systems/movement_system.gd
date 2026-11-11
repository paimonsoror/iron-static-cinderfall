class_name MovementSystem
extends RefCounted
## Flow following, separation, attack slots and stuck recovery (ARCH 6.6, GDD 6).
## One tick: copy prev positions, rebuild the spatial hash, then visit enemies in store order and move each one
## (positions are written as we go; the visiting order is deterministic). The 50-enemy budget is under 1 ms per tick
## in GDScript, so the expensive steering (flow heading, weave, line of sight, separation push, stuck bookkeeping) is
## refreshed every RESAMPLE_TICKS ticks per enemy, staggered by id, and the cached per-tick displacement is applied
## in between. Slot claims are collected and made at the end of the tick in ascending id order. Stunned enemies are
## frozen. Attackers stand on their slot and are neither pushed nor pushing. Nothing here removes an enemy.

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
	var app2: float = arena.approach_radius * arena.approach_radius
	for i: int in es.high_water:
		if alive[i] == 0:
			continue
		var px: float = ex[i]
		var pz: float = ez[i]
		prev_x[i] = px
		prev_z[i] = pz
		if stun[i] > 0:
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
		var spd: float = t_step[t]
		var st: int = states[i]
		if st == EnemyStore.ST_ATTACKING:
			if nav.grace[i] == NavState.SETTLING:
				_settle(nav, es, i, px, pz, spd)
			continue
		if st == EnemyStore.ST_SEEK_SLOT and slot_of[i] < 0:
			st = EnemyStore.ST_MOVING
			states[i] = st
		var cdx: float = px - core_x
		var cdz: float = pz - core_z
		var core_d2: float = cdx * cdx + cdz * cdz
		var left: int = ttl[i] - 1
		ttl[i] = left
		var mx: float
		var mz: float
		if st == EnemyStore.ST_MOVING:
			if core_d2 <= app2:
				nav.claims.append(i)
			if left <= 0 and _resample(world, es, nav, arena, i, t, enemy_id, st, px, pz, cdx, cdz, core_d2, 0.0):
				continue
			mx = c_vx[i]
			mz = c_vz[i]
		else:
			var slot_i: int = slot_of[i]
			var vx: float = nav.slots.pos_x[slot_i] - px
			var vz: float = nav.slots.pos_z[slot_i] - pz
			var d: float = sqrt(vx * vx + vz * vz)
			if d <= SNAP_M:
				_capture(world, es, nav, arena, i, t, slot_i, px, pz, spd)
				continue
			es.path_dist[i] = d
			if left <= 0 and _resample(world, es, nav, arena, i, t, enemy_id, st, px, pz, cdx, cdz, core_d2, d):
				continue
			var reach: float = minf(spd, d)
			mx = vx / d * reach + c_vx[i]
			mz = vz / d * reach + c_vz[i]
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
				_push_props(nav, arena, t_clear[t], px, pz, qx, qz)
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
		_make_claims(world, es, nav)


## Keeps a move that starts near props out of them (and off the prop's box, sliding along its face); writes the
## result into nav.fix. A quick distance test against each prop's bounding circle skips the exact geometry in the
## common case.
static func _push_props(nav: NavState, arena: ArenaDef, clear: float, px: float, pz: float, qx: float, qz: float) -> void:
	var fix: PackedFloat64Array = nav.fix
	fix[0] = qx
	fix[1] = qz
	var margin: float = clear * 1.5 + 0.01
	var near: bool = false
	for k: int in nav.ob_x.size():
		var dx: float = qx - nav.ob_x[k]
		var dz: float = qz - nav.ob_z[k]
		var reach: float = nav.ob_r[k] + margin
		if dx * dx + dz * dz <= reach * reach:
			near = true
			break
	if not near:
		return
	var obstacles: Array[ObstacleDef] = arena.obstacles
	NavGeometry.push_out_into(obstacles, qx, qz, clear, fix)
	if NavGeometry.inside_any(obstacles, fix[0], fix[1], 0.0):
		fix[0] = px
		fix[1] = pz


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
	seek_d: float
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
		if nav.t_direct[t] == 1 and core_d2 > 0.0001:
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
		if amp > 0.0:
			var rate: float = nav.t_weave_rate[t]
			var phase: float = rate * float(world.tick - es.spawn_tick[i]) + float(enemy_id) * GOLDEN_ANGLE
			var lateral: float = amp * rate * cos(phase)
			vx -= hz * lateral
			vz += hx * lateral
		path = es.path_dist[i] if is_inf(sample.z) else sample.z + nav.tail_m
		es.path_dist[i] = path
	var sepw: float = nav.t_sepw[t]
	if sepw > 0.0 and nav.sep_off[i] == 0:
		var push: Vector2 = _separation(es, nav, i, t, enemy_id, px, pz, sepw, spd)
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


## Push away from overlapping movers: weight_i * overlap * mass share of the other, from up to six neighbors,
## capped at the enemy's own speed per tick. Attackers are not in the hash and are ignored; a zero weight (the boss)
## is never pushed. Heavy movers (the boss) are tested from a short list instead of the cells.
static func _separation(
	es: EnemyStore, nav: NavState, i: int, t: int, enemy_id: int, px: float, pz: float, sepw: float, spd: float
) -> Vector2:
	var r_i: float = nav.t_radius[t]
	var m_i: float = nav.t_mass[t]
	var neigh: PackedInt32Array = nav.neigh
	var cnt: int = nav.spatial.gather(px, pz, SEP_SPACE * (r_i + nav.light_radius), neigh)
	var heavy: PackedInt32Array = nav.heavy
	for h: int in heavy:
		neigh.append(h)
	cnt += heavy.size()
	if cnt < 2:
		return Vector2.ZERO
	var xs: PackedFloat64Array = es.x
	var zs: PackedFloat64Array = es.z
	var types: PackedByteArray = es.type
	var states: PackedByteArray = es.state
	var radii: PackedFloat64Array = nav.t_radius
	var masses: PackedFloat64Array = nav.t_mass
	var sx: float = 0.0
	var sz: float = 0.0
	var used: int = 0
	for q: int in cnt:
		var j: int = neigh[q]
		if j == i or states[j] == EnemyStore.ST_ATTACKING:
			continue
		var tj: int = types[j]
		var space: float = SEP_SPACE * (r_i + radii[tj])
		var dx: float = px - xs[j]
		var dz: float = pz - zs[j]
		var d2: float = dx * dx + dz * dz
		if d2 >= space * space:
			continue
		var d: float = sqrt(d2)
		var ux: float
		var uz: float = 0.0
		if d < 0.000001:
			ux = 1.0 if enemy_id < es.id[j] else -1.0
		else:
			ux = dx / d
			uz = dz / d
		var m_j: float = masses[tj]
		var amount: float = (space - d) * SEP_GAIN * sepw * (m_j / (m_i + m_j))
		sx += ux * amount
		sz += uz * amount
		used += 1
		if used >= SEP_MAX_NEIGHBORS:
			break
	var s2: float = sx * sx + sz * sz
	if s2 > spd * spd:
		var shrink: float = spd / sqrt(s2)
		sx *= shrink
		sz *= shrink
	return Vector2(sx, sz)


## Moving enemies inside the approach circle claim a slot, in ascending id order (the one order-sensitive effect).
static func _make_claims(world: SimWorld, es: EnemyStore, nav: NavState) -> void:
	var claims: PackedInt32Array = nav.claims
	for a: int in range(1, claims.size()):
		var cur: int = claims[a]
		var b: int = a - 1
		while b >= 0 and es.id[claims[b]] > es.id[cur]:
			claims[b + 1] = claims[b]
			b -= 1
		claims[b + 1] = cur
	for k: int in claims.size():
		var i: int = claims[k]
		if es.state[i] != EnemyStore.ST_MOVING:
			continue
		var slot_i: int = nav.slots.claim(world, i)
		if slot_i >= 0:
			es.state[i] = EnemyStore.ST_SEEK_SLOT
			nav.c_ttl[i] = 0


## The enemy came within SNAP_M of its slot: it starts attacking now and settles onto the slot.
static func _capture(
	world: SimWorld,
	es: EnemyStore,
	nav: NavState,
	arena: ArenaDef,
	i: int,
	t: int,
	slot_i: int,
	px: float,
	pz: float,
	spd: float
) -> void:
	es.state[i] = EnemyStore.ST_ATTACKING
	es.attack_cd[i] = nav.t_period[t]
	es.path_dist[i] = 0.0
	nav.grace[i] = NavState.SETTLING
	var fx: float = arena.core_x - px
	var fz: float = arena.core_z - pz
	var f: float = sqrt(fx * fx + fz * fz)
	if f > 0.000001:
		es.face_x[i] = fx / f
		es.face_z[i] = fz / f
	world.events.push(SimEventKind.Id.ENEMY_REACHED_SLOT, es.id[i], slot_i)
	_settle(nav, es, i, px, pz, spd)


## Moves an attacker toward its slot position by at most the per-tick displacement bound (exactly onto it when
## closer), so the final snap never breaks the bound either.
static func _settle(nav: NavState, es: EnemyStore, i: int, px: float, pz: float, spd: float) -> void:
	var slot_i: int = es.slot[i]
	if slot_i < 0:
		nav.grace[i] = 0
		return
	var tx: float = nav.slots.pos_x[slot_i]
	var tz: float = nav.slots.pos_z[slot_i]
	var vx: float = tx - px
	var vz: float = tz - pz
	var d: float = sqrt(vx * vx + vz * vz)
	var limit: float = spd * MAX_STEP_MULT
	if d <= limit:
		es.x[i] = tx
		es.z[i] = tz
		nav.grace[i] = 0
	else:
		es.x[i] = px + vx / d * limit
		es.z[i] = pz + vz / d * limit
