class_name HazardSystem
extends RefCounted
## The delayed-effect queue, ground pools, mines and fuel drums (tick step 11; VARIETY_SPEC 9.5 rule 2). The only
## writer of HazardState. Called every tick of a live run.
##
## Queue: entries are kept sorted by (due tick, sequence number). Each tick the entries that are due land in that
## order, at most RunDef.max_blasts_per_tick of them; the rest stay queued and land on the next ticks (a visible
## ripple and a bounded tick). A hit queued while another lands is due on a later tick at the earliest, so a chain
## of death blasts is never recursion.
## The queue keeps running outside combat (a blast that is in the air when the wave clears still lands and is seen);
## only its core part is dropped there, because a defeat is decided during a wave.
## Hazards that belong to events live in systems/events/: HazardDrums (fuel drums: ignition by any blast, pool, strike or
## freight car, the chain, the slag pool), HazardMines (mines laid by directives), EventCoreVent.land (the vent's knockback)
## and EventSupplyDrop.steer (squatters on a crate, steered here because this step runs after the movement step).
# TODO(V4-N): K_BOLT (a spitter bolt hits the core).

const DEFAULT_MAX_PER_TICK: int = 8
const POOL_PULSE_TICKS: int = 30  ## a pool deals half a second of its damage twice a second


static func step(world: SimWorld) -> void:
	var h: HazardState = world.hazards
	if not h.q_due.is_empty():
		_land_due(world, h)
	if not h.p_id.is_empty():
		_step_pools(world, h)
	if not h.m_x.is_empty():
		HazardMines.step(world)
	EventSupplyDrop.steer(world)


## Queues a hit that lands at `due_tick` (HazardState.K_* kind), never earlier than the next tick. Pushes
## DELAYED_HIT_LAUNCHED(kind, ticks until it lands, x, z). Returns its sequence number, or -1 when nothing was queued.
static func queue_hit(
	world: SimWorld, due_tick: int, kind: int, x: float, z: float, radius: float, damage: float, edge_frac: float,
	flags: int, source: int
) -> int:
	var seq: int = _insert(world, due_tick, kind, x, z, radius, damage, edge_frac, flags, source, 0.0, -1)
	if seq > 0:
		world.events.push(SimEventKind.Id.DELAYED_HIT_LAUNCHED, kind, maxi(due_tick, world.tick + 1) - world.tick, x, z)
	return seq


## A death blast (DeathHooks): like `queue_hit`, but nothing is launched, so no DELAYED_HIT_LAUNCHED (the death is its
## warning), and with a core part: when it lands during a wave the core takes `core_damage` (shield first), reported
## as a CORE_HIT of enemy type `type_index`.
static func queue_blast(
	world: SimWorld, due_tick: int, kind: int, x: float, z: float, radius: float, damage: float, edge_frac: float,
	flags: int, source: int, core_damage: float, type_index: int
) -> int:
	return _insert(world, due_tick, kind, x, z, radius, damage, edge_frac, flags, source, core_damage, type_index)


static func _insert(
	world: SimWorld, due_tick: int, kind: int, x: float, z: float, radius: float, damage: float, edge_frac: float,
	flags: int, source: int, core_damage: float, type_index: int
) -> int:
	if radius <= 0.0 or (damage <= 0.0 and core_damage <= 0.0):
		return -1
	var h: HazardState = world.hazards
	var due: int = maxi(due_tick, world.tick + 1)
	var seq: int = h.next_seq
	h.next_seq += 1
	var at: int = h.q_due.size()
	while at > 0 and h.q_due[at - 1] > due:
		at -= 1
	h.q_due.insert(at, due)
	h.q_seq.insert(at, seq)
	h.q_kind.insert(at, kind)
	h.q_source.insert(at, source)
	h.q_flags.insert(at, flags)
	h.q_x.insert(at, x)
	h.q_z.insert(at, z)
	h.q_radius.insert(at, radius)
	h.q_damage.insert(at, damage)
	h.q_edge.insert(at, edge_frac)
	h.q_core.insert(at, core_damage)
	h.q_type.insert(at, type_index)
	return seq


## Starts a ground pool; pushes POOL_STARTED. Returns the pool id, or -1.
static func add_pool(world: SimWorld, x: float, z: float, radius: float, ticks: int, dps: float, slow: float) -> int:
	if radius <= 0.0 or ticks <= 0:
		return -1
	var h: HazardState = world.hazards
	var pool_id: int = h.next_pool_id
	h.next_pool_id += 1
	h.p_id.append(pool_id)
	h.p_ticks_left.append(ticks)
	h.p_x.append(x)
	h.p_z.append(z)
	h.p_radius.append(radius)
	h.p_dps.append(dps)
	h.p_slow.append(slow)
	world.events.push(SimEventKind.Id.POOL_STARTED, pool_id, roundi(radius * 100.0), x, z)
	return pool_id


## Drops everything that is queued or burning (wave clear). Pushes POOL_ENDED for every pool.
static func clear(world: SimWorld) -> void:
	var h: HazardState = world.hazards
	while not h.q_due.is_empty():
		_remove_hit(h, h.q_due.size() - 1)
	while not h.p_id.is_empty():
		_end_pool(world, h, h.p_id.size() - 1)


## Hits queued and not yet landed that are due at or before `tick`.
static func due_count(world: SimWorld, tick: int) -> int:
	var n: int = 0
	for due: int in world.hazards.q_due:
		if due <= tick:
			n += 1
	return n


static func _land_due(world: SimWorld, h: HazardState) -> void:
	var run: RunDef = world.content.run
	var limit: int = run.max_blasts_per_tick if run != null else DEFAULT_MAX_PER_TICK
	var landed: int = 0
	while landed < limit and not h.q_due.is_empty() and h.q_due[0] <= world.tick:
		var kind: int = h.q_kind[0]
		var source: int = h.q_source[0]
		var flags: int = h.q_flags[0]
		var x: float = h.q_x[0]
		var z: float = h.q_z[0]
		var radius: float = h.q_radius[0]
		var damage: float = h.q_damage[0]
		var edge: float = h.q_edge[0]
		var core_damage: float = h.q_core[0]
		var type_index: int = h.q_type[0]
		_remove_hit(h, 0)
		landed += 1
		if kind == HazardState.K_BOLT:
			continue
		world.events.push(SimEventKind.Id.AREA_BLAST, kind, roundi(radius * 100.0), x, z)
		if damage > 0.0:
			AreaDamage.apply(world, x, z, radius, damage, edge, flags, source)
		if core_damage > 0.0 and GameState.is_combat(world.phase):
			CoreAttackSystem.damage_core(world, core_damage, 0, type_index)
		_after_landing(world, kind, x, z, radius)


## What a landed hit sets off: the vent throws the survivors back, a drum blast leaves its slag pool, and any blast
## ignites the standing fuel drums it reaches (the ignition is queued, so a chain is a ripple, never recursion).
static func _after_landing(world: SimWorld, kind: int, x: float, z: float, radius: float) -> void:
	if kind == HazardState.K_VENT:
		EventCoreVent.land(world, x, z, radius)
	elif kind == HazardState.K_DRUM:
		HazardDrums.after_blast(world, x, z)
	if not world.hazards.d_alive.is_empty():
		HazardDrums.touch(world, x, z, radius)


static func _remove_hit(h: HazardState, at: int) -> void:
	h.q_due.remove_at(at)
	h.q_seq.remove_at(at)
	h.q_kind.remove_at(at)
	h.q_source.remove_at(at)
	h.q_flags.remove_at(at)
	h.q_x.remove_at(at)
	h.q_z.remove_at(at)
	h.q_radius.remove_at(at)
	h.q_damage.remove_at(at)
	h.q_edge.remove_at(at)
	h.q_core.remove_at(at)
	h.q_type.remove_at(at)


## Pools count down; every POOL_PULSE_TICKS a pool burns and slows the enemies standing in it (id order).
static func _step_pools(world: SimWorld, h: HazardState) -> void:
	var victims: PackedInt32Array = PackedInt32Array()
	var at: int = 0
	while at < h.p_id.size():
		h.p_ticks_left[at] -= 1
		if h.p_ticks_left[at] % POOL_PULSE_TICKS == 0:
			var pulse: float = h.p_dps[at] * float(POOL_PULSE_TICKS) / 60.0
			var slow_milli: int = roundi(h.p_slow[at] * 1000.0)
			if not h.d_alive.is_empty():
				HazardDrums.touch(world, h.p_x[at], h.p_z[at], h.p_radius[at])
			AreaDamage.query(world, h.p_x[at], h.p_z[at], h.p_radius[at], victims)
			for i: int in victims:
				if slow_milli > 0:
					StatusSystem.apply_slow(world, i, POOL_PULSE_TICKS, slow_milli)
				if pulse > 0.0:
					DamageResolver.hit_ex(
						world, i, pulse, DamageResolver.F_BURN | DamageResolver.F_AREA, DamageSource.Id.HAZARD
					)
		if h.p_ticks_left[at] <= 0:
			_end_pool(world, h, at)
		else:
			at += 1


static func _end_pool(world: SimWorld, h: HazardState, at: int) -> void:
	world.events.push(SimEventKind.Id.POOL_ENDED, h.p_id[at], 0, h.p_x[at], h.p_z[at])
	h.p_id.remove_at(at)
	h.p_ticks_left.remove_at(at)
	h.p_x.remove_at(at)
	h.p_z.remove_at(at)
	h.p_radius.remove_at(at)
	h.p_dps.remove_at(at)
	h.p_slow.remove_at(at)
