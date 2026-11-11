class_name NavState
extends RefCounted
## Navigation state owned by the nav systems (ARCH 6.6): FlowField, SpatialHash, AttackSlots, the wave's spawn
## schedule and pending queue, and the per-enemy trackers and steering caches. `setup` derives the static parts
## from the content (they are never hashed); everything else is hashed by `hash_into`.

## Movement keeps this much clearance from props (capped so a boss still fits between them).
const CLEARANCE_CAP_M: float = 0.8
## Movement fence zones, one bit set per flow-grid cell. A cell with no bit set is "calm": an enemy standing in it
## cannot reach a prop, the core body or the grid border within a tick or two (half a cell diagonal plus the clearance
## cap plus a few ticks of travel fit inside the margins below), so movement skips those tests there.
const ZONE_PROPS: int = 1  ## a prop is within PROP_ZONE_M of the cell center
const ZONE_CORE: int = 2  ## the core body is within CORE_ZONE_M of the cell center
const ZONE_EDGE: int = 4  ## the cell is on the grid border
const PROP_ZONE_M: float = 2.0
const CORE_ZONE_M: float = 2.0
## Enemy centers stay this far inside the grid border.
const EDGE_M: float = 0.05
## Steering (flow heading, line of sight, separation push) is refreshed this often per enemy, staggered by id.
const RESAMPLE_TICKS: int = 6
## `grace` marker of an attacker that is still settling onto its slot.
const SETTLING: int = 2
## Enemies with a larger radius (the boss) are kept out of the spatial hash cells and tested through a short list.
const HEAVY_RADIUS_M: float = 0.75

# --- static, derived from the content by setup() (not hashed) ---
var flow: FlowField
var zone: PackedByteArray = PackedByteArray()  ## per flow-grid cell: ZONE_* bits, 0 = calm
var ob_x: PackedFloat64Array = PackedFloat64Array()  ## obstacle centers and bounding radii (quick reject)
var ob_z: PackedFloat64Array = PackedFloat64Array()
var ob_r: PackedFloat64Array = PackedFloat64Array()
var spatial: SpatialHash
var slots: AttackSlots
var tail_m: float = 0.0  ## meters from the approach circle to the first ring
var bound_min_x: float = 0.0  ## movement clamps enemy centers into the grid, EDGE_M short of its border
var bound_max_x: float = 0.0
var bound_min_z: float = 0.0
var bound_max_z: float = 0.0
# Per enemy type (indexed by Ids.EN_*): packed copies of the EnemyDef numbers the hot loop needs.
var t_step: PackedFloat64Array = PackedFloat64Array()  ## speed_mps * DT
var t_radius: PackedFloat64Array = PackedFloat64Array()
var t_mass: PackedFloat64Array = PackedFloat64Array()
var t_sepw: PackedFloat64Array = PackedFloat64Array()
var t_weave_amp: PackedFloat64Array = PackedFloat64Array()
var t_weave_rate: PackedFloat64Array = PackedFloat64Array()  ## radians per tick
var t_direct: PackedByteArray = PackedByteArray()
var t_clear: PackedFloat64Array = PackedFloat64Array()
var t_period: PackedInt32Array = PackedInt32Array()  ## attack_period_ticks

# --- spawn schedule of the current wave, sorted by (due tick, group, ordinal) ---
var wave_begun: int = 0  ## wave index of the schedule (0 = none yet)
var sched_due: PackedInt32Array = PackedInt32Array()  ## absolute tick
var sched_type: PackedInt32Array = PackedInt32Array()
var sched_group: PackedInt32Array = PackedInt32Array()
var sched_ordinal: PackedInt32Array = PackedInt32Array()
var sched_x: PackedFloat64Array = PackedFloat64Array()
var sched_z: PackedFloat64Array = PackedFloat64Array()
var sched_next: int = 0  ## first entry that has not become due yet
var pending: PackedInt32Array = PackedInt32Array()  ## due entries still waiting for room, FIFO from pending_head
var pending_head: int = 0

# --- per store index trackers and caches; valid while track_id[i] == enemies.id[i] ---
var track_id: PackedInt32Array = PackedInt32Array()
var stuck_ref: PackedFloat64Array = PackedFloat64Array()  ## path_dist at the start of the window
var stuck_timer: PackedInt32Array = PackedInt32Array()
var sep_off: PackedInt32Array = PackedInt32Array()  ## ticks left of ignoring separation after a stuck event
var grace: PackedByteArray = PackedByteArray()  ## 1 = waiting out sep_off before a forced move, SETTLING = see above
var recoveries: PackedInt32Array = PackedInt32Array()
var c_ttl: PackedInt32Array = PackedInt32Array()  ## ticks until the next steering refresh; -1 = never refreshed
var c_vx: PackedFloat64Array = PackedFloat64Array()  ## cached per-tick displacement: moving = heading + weave + push,
var c_vz: PackedFloat64Array = PackedFloat64Array()  ## seeking = the separation push only

# --- scratch for one MovementSystem.step (rewritten every tick, not hashed) ---
var neigh: PackedInt32Array = PackedInt32Array()
var claims: PackedInt32Array = PackedInt32Array()
var heavy: PackedInt32Array = PackedInt32Array()  ## store indices of moving heavy enemies this tick
var fix: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])  ## out-parameter of the prop fence (x, z)
var light_radius: float = 0.0  ## largest radius among the moving non-heavy enemies this tick


## Builds the static structures and sizes the per-enemy arrays. Called by NavSystemHooks.init_world.
func setup(world: SimWorld) -> void:
	var arena: ArenaDef = world.content.arena
	flow = FlowField.build(arena)
	_build_zones(arena)
	bound_min_x = flow.grid.origin_x + EDGE_M
	bound_max_x = flow.grid.max_x() - EDGE_M
	bound_min_z = flow.grid.origin_z + EDGE_M
	bound_max_z = flow.grid.max_z() - EDGE_M
	spatial = SpatialHash.new()
	slots = AttackSlots.new()
	slots.setup(arena)
	tail_m = 0.0
	if arena.slot_positions.size() > 0:
		var first: Vector2 = arena.slot_positions[0]
		tail_m = maxf(0.0, arena.approach_radius - Vector2(first.x - arena.core_x, first.y - arena.core_z).length())
	var types: int = world.content.enemies.size()
	t_step.resize(types)
	t_radius.resize(types)
	t_mass.resize(types)
	t_sepw.resize(types)
	t_weave_amp.resize(types)
	t_weave_rate.resize(types)
	t_direct.resize(types)
	t_clear.resize(types)
	t_period.resize(types)
	for t: int in types:
		var def: EnemyDef = world.content.enemies[t]
		t_step[t] = def.speed_mps * SimWorld.DT
		t_radius[t] = def.radius
		t_mass[t] = def.mass
		t_sepw[t] = def.separation_weight
		t_weave_amp[t] = def.weave_amp_m
		t_weave_rate[t] = TAU / float(maxi(1, def.weave_period_ticks))
		t_direct[t] = 1 if def.direct_seek else 0
		t_clear[t] = minf(def.radius, CLEARANCE_CAP_M)
		t_period[t] = def.attack_period_ticks
	var cap: int = world.enemies.capacity
	track_id.resize(cap)
	stuck_ref.resize(cap)
	stuck_timer.resize(cap)
	sep_off.resize(cap)
	grace.resize(cap)
	recoveries.resize(cap)
	c_ttl.resize(cap)
	c_vx.resize(cap)
	c_vz.resize(cap)


func _build_zones(arena: ArenaDef) -> void:
	var g: ArenaGrid = flow.grid
	var far: ArenaGrid = ArenaGrid.build(arena, PROP_ZONE_M)
	zone.resize(g.cols * g.rows)
	var core_zone: float = arena.core_radius + CORE_ZONE_M
	for c: int in g.cols * g.rows:
		var cz: int = floori(float(c) / float(g.cols))
		var cx: int = c - cz * g.cols
		var p: Vector2 = g.cell_center(c)
		var bits: int = 0
		if far.blocked[c] == 1:
			bits |= ZONE_PROPS
		if Vector2(p.x - arena.core_x, p.y - arena.core_z).length() < core_zone:
			bits |= ZONE_CORE
		if cx == 0 or cz == 0 or cx == g.cols - 1 or cz == g.rows - 1:
			bits |= ZONE_EDGE
		zone[c] = bits
	ob_x.resize(arena.obstacles.size())
	ob_z.resize(arena.obstacles.size())
	ob_r.resize(arena.obstacles.size())
	for k: int in arena.obstacles.size():
		var o: ObstacleDef = arena.obstacles[k]
		ob_x[k] = o.x
		ob_z[k] = o.z
		ob_r[k] = o.radius if o.shape == ObstacleDef.Shape.CIRCLE else (o.size_x + o.size_z) * 0.5


## Due spawn entries that are waiting for room.
func pending_count() -> int:
	return pending.size() - pending_head


## Starts (or restarts) the tracker and steering cache of the enemy in store slot `i`.
func track(i: int, enemy_id: int, path_dist: float) -> void:
	track_id[i] = enemy_id
	stuck_ref[i] = path_dist
	stuck_timer[i] = 0
	sep_off[i] = 0
	grace[i] = 0
	recoveries[i] = 0
	c_ttl[i] = -1
	c_vx[i] = 0.0
	c_vz[i] = 0.0


## Meters still to travel for the enemy in store slot `i`, from the state it is in now.
func path_dist_of(es: EnemyStore, i: int) -> float:
	var state: int = es.state[i]
	if state == EnemyStore.ST_ATTACKING:
		return 0.0
	if state == EnemyStore.ST_SEEK_SLOT and es.slot[i] >= 0:
		var target: Vector2 = slots.slot_position(es.slot[i])
		return Vector2(target.x - es.x[i], target.y - es.z[i]).length()
	var c: float = flow.sample_cost(es.x[i], es.z[i])
	if is_inf(c):
		return es.path_dist[i]
	return c + tail_m


func hash_into(h: StateHasher) -> void:
	if slots != null:
		slots.hash_into(h)
	h.put_int(wave_begun)
	h.put_int(sched_next)
	h.put_int(pending_head)
	h.put_ints(sched_due)
	h.put_ints(sched_type)
	h.put_ints(sched_group)
	h.put_ints(sched_ordinal)
	h.put_floats(sched_x)
	h.put_floats(sched_z)
	h.put_ints(pending)
	h.put_ints(track_id)
	h.put_floats(stuck_ref)
	h.put_ints(stuck_timer)
	h.put_ints(sep_off)
	h.put_bytes(grace)
	h.put_ints(recoveries)
	h.put_ints(c_ttl)
	h.put_floats(c_vx)
	h.put_floats(c_vz)
