class_name SpawnSystem
extends RefCounted
## Scheduled spawns and the pending queue (ARCH 6.6, GDD 7). `begin_wave` lays out the wave as entries sorted by
## (tick, group, ordinal) with their spawn points drawn from the `spawn` stream; `step` moves due entries into a FIFO
## queue and spawns from it while fewer than `enemy_cap` enemies live, at most `max_spawns_per_tick` per tick.
## Nothing is ever dropped: an entry leaves the queue only by spawning.

## Stratified spread along the region: golden-ratio step plus a seeded jitter.
const GOLDEN_STEP: float = 0.618034
const JITTER: float = 0.08


## Builds the tick-ordered schedule of wave `wave_index` (1..5). Due ticks are relative to the current tick, so an
## entry with start 0 is due on the tick this is called. Replaces any earlier schedule and queue.
static func begin_wave(world: SimWorld, wave_index: int) -> void:
	var content: ContentSet = world.content
	if wave_index < 1 or wave_index > content.waves.size():
		return
	var nav: NavState = world.nav
	var wave: WaveDef = content.waves[wave_index - 1]
	var rel: PackedInt32Array = PackedInt32Array()
	var grp: PackedInt32Array = PackedInt32Array()
	var ord: PackedInt32Array = PackedInt32Array()
	for g: int in wave.groups.size():
		var gd: SpawnGroupDef = wave.groups[g]
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
		var gd: SpawnGroupDef = wave.groups[grp[e]]
		nav.sched_due[s] = world.tick + rel[e]
		nav.sched_type[s] = gd.enemy_index
		nav.sched_group[s] = grp[e]
		nav.sched_ordinal[s] = ord[e]
		var region: SpawnRegionDef = arena.region(gd.region_id)
		if region == null and not arena.spawn_regions.is_empty():
			region = arena.spawn_regions[0]
		var jitter: float = stream.randf_range(-JITTER, JITTER)
		var t: float = fposmod(float(ord[e]) * GOLDEN_STEP + jitter, 1.0)
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
	if nav.pending_head >= nav.pending.size():
		nav.pending.clear()
		nav.pending_head = 0
	var left: int = nav.pending_count()
	var old_left: int = maxi(0, queued_before - spawned)
	for k: int in left - old_left:
		world.events.push(SimEventKind.Id.SPAWN_QUEUED, old_left + k + 1)
	world.stats.max_pending = maxi(world.stats.max_pending, left)


## Schedule exhausted AND pending queue empty. False until a wave has begun.
static func is_wave_fully_spawned(world: SimWorld) -> bool:
	var nav: NavState = world.nav
	return nav.wave_begun > 0 and nav.sched_next >= nav.sched_due.size() and nav.pending_count() == 0


## Due spawns still waiting for room under the cap.
static func pending_count(world: SimWorld) -> int:
	return world.nav.pending_count()


static func _sorts_after(rel: PackedInt32Array, grp: PackedInt32Array, ord: PackedInt32Array, i: int, j: int) -> bool:
	if rel[i] != rel[j]:
		return rel[i] > rel[j]
	if grp[i] != grp[j]:
		return grp[i] > grp[j]
	return ord[i] > ord[j]
