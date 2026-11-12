class_name SpawnSystem
extends RefCounted
## Scheduled spawns and the pending queue (ARCH 6.6, GDD 7). `begin_wave` lays out the wave as entries sorted by
## (tick, group, ordinal) with their spawn points drawn from the `spawn` stream; `step` moves due entries into a FIFO
## queue and spawns from it while the caps allow, at most `max_spawns_per_tick` per tick. Nothing is ever dropped: an
## entry leaves the queue only by spawning.
##
## The legacy content (no `run`) spawns while fewer than `enemy_cap` enemies live, exactly as before. A generated run
## (VARIETY_SPEC 5.5) has four caps, each applied in queue order: bodied enemies alive (`enemy_cap`), minis alive
## (`swarm_cap`), per type alive (`EnemyDef.alive_cap`) and elites alive (`max_elites_alive`). An entry that is blocked by
## one cap keeps its place and does not hold up entries that no cap blocks, so a full yard of bodies never stops the minis.
## `begin_wave` reads the groups and elites of the CHOSEN RouteOption of the plan instead of `content.waves`.

## Stratified spread along the region: golden-ratio step plus a seeded jitter.
const GOLDEN_STEP: float = 0.618034
const JITTER: float = 0.08
## Region id of the groups that enter at one of the arena's breach points (VARIETY_SPEC 5.1).
const BREACH_REGION: StringName = &"breach"


## Builds the tick-ordered schedule of wave `wave_index` (1..wave count). Due ticks are relative to the current tick, so
## an entry with start 0 is due on the tick this is called. Replaces any earlier schedule and queue.
static func begin_wave(world: SimWorld, wave_index: int) -> void:
	var content: ContentSet = world.content
	var groups: Array[SpawnGroupDef] = []
	if world.plan != null:
		var option: RouteOption = world.plan.option(wave_index)
		if option == null:
			return
		groups = option.groups
	else:
		if wave_index < 1 or wave_index > content.waves.size():
			return
		groups = content.waves[wave_index - 1].groups
	var nav: NavState = world.nav
	var rel: PackedInt32Array = PackedInt32Array()
	var grp: PackedInt32Array = PackedInt32Array()
	var ord: PackedInt32Array = PackedInt32Array()
	for g: int in groups.size():
		var gd: SpawnGroupDef = groups[g]
		for k: int in gd.count:
			rel.append(gd.start_tick + k * gd.interval_ticks)
			grp.append(g)
			ord.append(k)
	var n: int = rel.size()
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(n)
	for i: int in n:
		idx[i] = i
	for a: int in range(1, n):
		var cur: int = idx[a]
		var b: int = a - 1
		while b >= 0 and _sorts_after(rel, grp, ord, idx[b], cur):
			idx[b + 1] = idx[b]
			b -= 1
		idx[b + 1] = cur
	nav.sched_due.resize(n)
	nav.sched_type.resize(n)
	nav.sched_group.resize(n)
	nav.sched_ordinal.resize(n)
	nav.sched_x.resize(n)
	nav.sched_z.resize(n)
	var stream: RandomNumberGenerator = world.rng.stream(&"spawn")
	var arena: ArenaDef = content.arena
	for s: int in n:
		var e: int = idx[s]
		var gd: SpawnGroupDef = groups[grp[e]]
		nav.sched_due[s] = world.tick + rel[e]
		nav.sched_type[s] = gd.enemy_index
		nav.sched_group[s] = grp[e]
		nav.sched_ordinal[s] = ord[e]
		var jitter: float = stream.randf_range(-JITTER, JITTER)
		var t: float = fposmod(float(ord[e]) * GOLDEN_STEP + jitter, 1.0)
		if gd.region_id == BREACH_REGION and not arena.breach_points.is_empty():
			var point: Vector2 = arena.breach_points[mini(floori(t * float(arena.breach_points.size())), arena.breach_points.size() - 1)]
			nav.sched_x[s] = point.x
			nav.sched_z[s] = point.y
			continue
		var region: SpawnRegionDef = arena.region(gd.region_id)
		if region == null and not arena.spawn_regions.is_empty():
			region = arena.spawn_regions[0]
		if region != null:
			nav.sched_x[s] = region.x0 + (region.x1 - region.x0) * t
			nav.sched_z[s] = region.z0 + (region.z1 - region.z0) * t
	nav.sched_next = 0
	nav.pending.clear()
	nav.pending_head = 0
	nav.wave_begun = wave_index


static func step(world: SimWorld) -> void:
	var nav: NavState = world.nav
	var queued_before: int = nav.pending_count()
	var total: int = nav.sched_due.size()
	while nav.sched_next < total and nav.sched_due[nav.sched_next] <= world.tick:
		nav.pending.append(nav.sched_next)
		nav.sched_next += 1
	if nav.pending_count() == 0:
		return
	var spawned: int = _spawn_capped(world) if world.content.run != null else _spawn_legacy(world)
	if nav.pending_head >= nav.pending.size():
		nav.pending.clear()
		nav.pending_head = 0
	var left: int = nav.pending_count()
	var old_left: int = maxi(0, queued_before - spawned)
	for k: int in left - old_left:
		world.events.push(SimEventKind.Id.SPAWN_QUEUED, old_left + k + 1)
	world.stats.max_pending = maxi(world.stats.max_pending, left)


## Puts one body into the pending queue now, behind everything already due (FIFO). For spawns that were not in the
## wave's schedule and had no room: a splitter's shards at its death position (VARIETY_SPEC 5.5). The body enters under
## the same caps as a scheduled one, never as an elite.
static func enqueue(world: SimWorld, type_index: int, x: float, z: float) -> void:
	var nav: NavState = world.nav
	var at: int = nav.sched_next
	nav.sched_due.insert(at, world.tick)
	nav.sched_type.insert(at, type_index)
	nav.sched_group.insert(at, -1)
	nav.sched_ordinal.insert(at, 0)
	nav.sched_x.insert(at, x)
	nav.sched_z.insert(at, z)
	nav.pending.append(at)
	nav.sched_next += 1


## Schedule exhausted AND pending queue empty. False until a wave has begun.
static func is_wave_fully_spawned(world: SimWorld) -> bool:
	var nav: NavState = world.nav
	return nav.wave_begun > 0 and nav.sched_next >= nav.sched_due.size() and nav.pending_count() == 0


## Due spawns still waiting for room under the cap.
static func pending_count(world: SimWorld) -> int:
	return world.nav.pending_count()


## The legacy loop: strict FIFO while fewer than `enemy_cap` enemies of any kind live. Returns the number spawned.
static func _spawn_legacy(world: SimWorld) -> int:
	var nav: NavState = world.nav
	var es: EnemyStore = world.enemies
	var cap: int = world.content.mission.enemy_cap
	var per_tick: int = world.content.mission.max_spawns_per_tick
	var alive: int = world.alive_count()
	var spawned: int = 0
	while nav.pending_head < nav.pending.size() and spawned < per_tick and alive < cap:
		var e: int = nav.pending[nav.pending_head]
		var i: int = world.spawn_enemy(nav.sched_type[e], nav.sched_x[e], nav.sched_z[e])
		if i < 0:
			break
		nav.pending_head += 1
		spawned += 1
		alive += 1
		es.path_dist[i] = nav.path_dist_of(es, i)
		nav.track(i, es.id[i], es.path_dist[i])
	return spawned


## The queue of a generated run. Walks the pending entries in order and spawns every one that no cap blocks; the blocked
## ones are kept, in order, for the next tick. Returns the number spawned.
static func _spawn_capped(world: SimWorld) -> int:
	var nav: NavState = world.nav
	var es: EnemyStore = world.enemies
	var content: ContentSet = world.content
	var run: RunDef = content.run
	var bodied: int = 0
	var minis: int = 0
	var elites: int = 0
	var of_type: PackedInt32Array = PackedInt32Array()
	of_type.resize(content.enemies.size())
	for j: int in es.high_water:
		if es.alive[j] == 0:
			continue
		if world.ext.has_flag(j, EnemyExtState.F_MINI):
			minis += 1
		else:
			bodied += 1
		of_type[es.type[j]] += 1
		if world.ext.is_elite(j):
			elites += 1
	var bodied_cap: int = content.mission.enemy_cap
	var per_tick: int = content.mission.max_spawns_per_tick
	var spawned: int = 0
	var kept: PackedInt32Array = PackedInt32Array()
	for k: int in range(nav.pending_head, nav.pending.size()):
		var e: int = nav.pending[k]
		if spawned >= per_tick or (bodied >= bodied_cap and minis >= run.swarm_cap):
			kept.append(e)
			continue
		var type_index: int = nav.sched_type[e]
		var def: EnemyDef = content.enemies[type_index]
		var mask: int = _elite_mask(world, e)
		var full: bool = minis >= run.swarm_cap if def.is_mini() else bodied >= bodied_cap
		full = full or (def.alive_cap > 0 and of_type[type_index] >= def.alive_cap)
		full = full or (mask != 0 and elites >= run.max_elites_alive)
		var i: int = -1 if full else world.spawn_enemy(type_index, nav.sched_x[e], nav.sched_z[e], mask)
		if i < 0:
			kept.append(e)
			continue
		spawned += 1
		of_type[type_index] += 1
		if def.is_mini():
			minis += 1
		else:
			bodied += 1
		if mask != 0:
			elites += 1
		es.path_dist[i] = nav.path_dist_of(es, i)
		nav.track(i, es.id[i], es.path_dist[i])
	nav.pending = kept
	nav.pending_head = 0
	return spawned


## The affix mask the plan gives the scheduled body of queue entry `e` (0 for a normal body or an enqueued one).
static func _elite_mask(world: SimWorld, e: int) -> int:
	var nav: NavState = world.nav
	if world.plan == null or nav.sched_group[e] < 0:
		return 0
	var option: RouteOption = world.plan.option(nav.wave_begun)
	if option == null:
		return 0
	for planned: PlannedElite in option.elites:
		if planned.group == nav.sched_group[e] and planned.ordinal == nav.sched_ordinal[e]:
			return planned.affix_mask
	return 0


static func _sorts_after(rel: PackedInt32Array, grp: PackedInt32Array, ord: PackedInt32Array, i: int, j: int) -> bool:
	if rel[i] != rel[j]:
		return rel[i] > rel[j]
	if grp[i] != grp[j]:
		return grp[i] > grp[j]
	return ord[i] > ord[j]
