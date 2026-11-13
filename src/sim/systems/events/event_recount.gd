class_name EventRecount
extends RefCounted
## RECOUNT (`recount`; VARIETY_SPEC 7.1, CONTENT 6): world, harmful, not boss-safe, no weight in act I. The warning (3 s)
## chooses "the other edge": of the arena's spawn regions, the one that holds the fewest of the next `spawns` (12) entries of
## the wave's spawn schedule (ties go to the later region) and shows its middle. Then those entries, whatever time they
## were due, are due at once and enter spread along that edge, together; SpawnSystem releases them under its usual caps.
## Fewer than 12 entries left means fewer move; none left, nothing happens. The schedule stays sorted: the entries that
## move are the next ones to be released, and they all become due now.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: spawns.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage == EventSystem.Stage.WARN:
		_pick(world, slot)
	elif stage == EventSystem.Stage.START:
		_move(world, slot)


static func _pick(world: SimWorld, slot: int) -> void:
	var regions: Array[SpawnRegionDef] = world.content.arena.spawn_regions
	if regions.is_empty():
		return
	var def: EventDef = world.content.events[world.events_state.a_event[slot]]
	var nav: NavState = world.nav
	var held: PackedInt32Array = PackedInt32Array()
	held.resize(regions.size())
	var last: int = mini(nav.sched_due.size(), nav.sched_next + roundi(def.param(&"spawns")))
	for e: int in range(nav.sched_next, last):
		held[_nearest_region(regions, nav.sched_x[e], nav.sched_z[e])] += 1
	var target: int = 0
	for r: int in regions.size():
		if held[r] <= held[target]:
			target = r
	world.events_state.a_x[slot] = (regions[target].x0 + regions[target].x1) * 0.5
	world.events_state.a_z[slot] = (regions[target].z0 + regions[target].z1) * 0.5


static func _move(world: SimWorld, slot: int) -> void:
	var regions: Array[SpawnRegionDef] = world.content.arena.spawn_regions
	if regions.is_empty():
		return
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var nav: NavState = world.nav
	var target: SpawnRegionDef = regions[_nearest_region(regions, es.a_x[slot], es.a_z[slot])]
	var first: int = nav.sched_next
	var count: int = mini(nav.sched_due.size() - first, roundi(def.param(&"spawns")))
	for k: int in count:
		var e: int = first + k
		var t: float = (float(k) + 0.5) / float(count)
		nav.sched_due[e] = world.tick
		nav.sched_x[e] = target.x0 + (target.x1 - target.x0) * t
		nav.sched_z[e] = target.z0 + (target.z1 - target.z0) * t


## Index of the region whose middle is nearest to (x, z).
static func _nearest_region(regions: Array[SpawnRegionDef], x: float, z: float) -> int:
	var best: int = 0
	var best_d2: float = INF
	for r: int in regions.size():
		var dx: float = (regions[r].x0 + regions[r].x1) * 0.5 - x
		var dz: float = (regions[r].z0 + regions[r].z1) * 0.5 - z
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2:
			best = r
			best_d2 = d2
	return best
