class_name NavSteering
extends RefCounted
## The parts of MovementSystem that are not its per-tick loop (split out for the file-size rule): the separation push,
## the prop fence, the end-of-tick claims (attack slots and standoff points), the capture at a slot or point and the
## settle onto it. Same numbers and order as before the split; the constants live in MovementSystem.


## Keeps a move that starts near props out of them (and off the prop's box, sliding along its face); writes the
## result into nav.fix. A quick distance test against each prop's bounding circle skips the exact geometry in the
## common case.
static func push_props(nav: NavState, arena: ArenaDef, clear: float, px: float, pz: float, qx: float, qz: float) -> void:
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


## Push away from overlapping movers: weight_i * overlap * mass share of the other, from up to six neighbors,
## capped at the enemy's own speed per tick. Attackers are not in the hash and are ignored; a zero weight (the boss)
## is never pushed. Heavy movers (the boss) are tested from a short list instead of the cells.
static func separation(
	es: EnemyStore, nav: NavState, i: int, t: int, enemy_id: int, px: float, pz: float, sepw: float, spd: float,
	xflags: PackedInt32Array
) -> Vector2:
	var r_i: float = nav.t_radius[t]
	var m_i: float = nav.t_mass[t]
	var neigh: PackedInt32Array = nav.neigh
	var cnt: int = nav.spatial.gather(px, pz, MovementSystem.SEP_SPACE * (r_i + nav.light_radius), neigh)
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
		if j == i or states[j] == EnemyStore.ST_ATTACKING or (xflags[j] & MovementSystem.F_NO_PUSH) != 0:
			continue
		var tj: int = types[j]
		var space: float = MovementSystem.SEP_SPACE * (r_i + radii[tj])
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
		var amount: float = (space - d) * MovementSystem.SEP_GAIN * sepw * (m_j / (m_i + m_j))
		sx += ux * amount
		sz += uz * amount
		used += 1
		if used >= MovementSystem.SEP_MAX_NEIGHBORS:
			break
	var s2: float = sx * sx + sz * sz
	if s2 > spd * spd:
		var shrink: float = spd / sqrt(s2)
		sx *= shrink
		sz *= shrink
	return Vector2(sx, sz)


## Movers inside their claim distance claim their place, in ascending id order (the one order-sensitive effect): a
## bodied enemy an attack slot, a standoff enemy a standoff point. A standoff enemy that finds its ring full parks
## where it stands once it is inside its standoff distance.
static func make_claims(world: SimWorld, es: EnemyStore, nav: NavState) -> void:
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
		var t: int = es.type[i]
		if nav.t_standoff[t] == 1:
			_claim_standoff(world, es, nav, i, t)
			continue
		var slot_i: int = nav.slots.claim(world, i)
		if slot_i >= 0:
			es.state[i] = EnemyStore.ST_SEEK_SLOT
			nav.c_ttl[i] = 0


static func _claim_standoff(world: SimWorld, es: EnemyStore, nav: NavState, i: int, t: int) -> void:
	if StandoffPoints.claim(world, i) >= 0:
		es.state[i] = EnemyStore.ST_SEEK_SLOT
		nav.c_ttl[i] = 0
		return
	var arena: ArenaDef = world.content.arena
	var dx: float = es.x[i] - arena.core_x
	var dz: float = es.z[i] - arena.core_z
	var standoff: float = world.content.enemies[t].standoff_m
	if dx * dx + dz * dz <= standoff * standoff:
		capture(world, es, nav, arena, i, t, -1, es.x[i], es.z[i], nav.t_step[t])


## The enemy came within SNAP_M of its slot or standoff point (`slot_i` -1 = a standoff point, or no place at all): it
## starts attacking now and settles onto it. Pushes ENEMY_REACHED_SLOT(enemy id, slot or -1).
static func capture(
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
	settle(world, nav, es, i, px, pz, spd)


## Moves an attacker toward its slot (or standoff point) by at most the per-tick displacement bound (exactly onto it
## when closer), so the final snap never breaks the bound either.
static func settle(world: SimWorld, nav: NavState, es: EnemyStore, i: int, px: float, pz: float, spd: float) -> void:
	var slot_i: int = es.slot[i]
	var tx: float
	var tz: float
	if slot_i >= 0:
		tx = nav.slots.pos_x[slot_i]
		tz = nav.slots.pos_z[slot_i]
	else:
		var point: int = world.ext.anchor_point[i]
		if point < 0 or point >= nav.sp_x.size():
			nav.grace[i] = 0
			return
		tx = nav.sp_x[point]
		tz = nav.sp_z[point]
	var vx: float = tx - px
	var vz: float = tz - pz
	var d: float = sqrt(vx * vx + vz * vz)
	var limit: float = spd * MovementSystem.MAX_STEP_MULT
	if d <= limit:
		es.x[i] = tx
		es.z[i] = tz
		nav.grace[i] = 0
	else:
		es.x[i] = px + vx / d * limit
		es.z[i] = pz + vz / d * limit


## Clamps a wanted position (qx, qz) of a body with clearance `clear` that stands at (px, pz): out of props, out of
## the core body, inside the grid. Writes nav.fix. Used by the knockback (the per-tick loop has its own zoned copy).
static func fence(nav: NavState, arena: ArenaDef, clear: float, px: float, pz: float, qx: float, qz: float) -> void:
	push_props(nav, arena, clear, px, pz, qx, qz)
	var x: float = nav.fix[0]
	var z: float = nav.fix[1]
	var core_r: float = arena.core_radius + clear
	var dx: float = x - arena.core_x
	var dz: float = z - arena.core_z
	var d2: float = dx * dx + dz * dz
	if d2 < core_r * core_r:
		var d: float = sqrt(d2)
		if d < 0.000000001:
			dx = 1.0
			dz = 0.0
			d = 1.0
		x = arena.core_x + dx / d * (core_r + MovementSystem.PUSH_EPS)
		z = arena.core_z + dz / d * (core_r + MovementSystem.PUSH_EPS)
	nav.fix[0] = clampf(x, nav.bound_min_x, nav.bound_max_x)
	nav.fix[1] = clampf(z, nav.bound_min_z, nav.bound_max_z)
