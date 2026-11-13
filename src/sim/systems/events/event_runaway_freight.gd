class_name EventRunawayFreight
extends RefCounted
## RUNAWAY FREIGHT (`runaway_freight`; VARIETY_SPEC 7.1, CONTENT 6): world, boss-safe. The warning (4 s) picks the rail line
## with more enemies on it (ties go to the line of the wave number) and shows the lane. Then a freight car crosses the
## yard on that line from the right edge to the left in `duration` (1.2 s), one segment per tick: every enemy whose centre is
## within the line's half width of the line when the car passes it takes `damage` (armor ignored; a boss takes
## `boss_mult` of it) and the survivors are thrown `knockback_m` sideways, out of the lane (a stunned enemy stays where
## it is: "stunned enemies cannot leave the lane"). Standing fuel drums in the lane ignite. The car is the slot position
## (a_x moves along the line, a_z is the line) for the view. The Core, the Warden and the turrets are never in a lane.
## FREIGHT, the player's call, runs this same pass (EventFreightCall -> run_pass) with the numbers of this entry.
## params: damage, boss_mult, knockback_m.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	run_pass(world, slot, stage)


## The pass for a slot of this event or of freight_call: WARN picks the lane, TICK and FINISH sweep the car's segment.
static func run_pass(world: SimWorld, slot: int, stage: int) -> void:
	if stage == EventSystem.Stage.WARN:
		_pick(world, slot)
	elif stage == EventSystem.Stage.TICK or stage == EventSystem.Stage.FINISH:
		_sweep(world, slot)


## The rail line (index into ArenaDef.rail_z) with more enemies within its half width; ties go to wave % lines. -1 when the
## arena has no rail.
static func pick_line(world: SimWorld) -> int:
	var arena: ArenaDef = world.content.arena
	var lines: int = arena.rail_z.size()
	if lines == 0:
		return -1
	var best: int = world.wave % lines
	var best_count: int = -1
	for line: int in lines:
		var n: int = _count_on(world, arena.rail_z[line], arena.rail_half_width[line])
		if n > best_count or (n == best_count and line == world.wave % lines):
			best = line
			best_count = n
	return best


static func _pick(world: SimWorld, slot: int) -> void:
	var es: EventState = world.events_state
	var line: int = pick_line(world)
	if line < 0:
		return
	es.a_x[slot] = world.content.arena.max_x
	es.a_z[slot] = world.content.arena.rail_z[line]


static func _count_on(world: SimWorld, lane_z: float, half_width: float) -> int:
	var store: EnemyStore = world.enemies
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 1 and absf(store.z[i] - lane_z) <= half_width:
			n += 1
	return n


## The car moves from x_hi to x_lo this tick (t of `total` ticks gone): hit what it passes.
static func _sweep(world: SimWorld, slot: int) -> void:
	var es: EventState = world.events_state
	var arena: ArenaDef = world.content.arena
	var total: int = world.content.events[es.a_event[slot]].duration_ticks
	var t: int = total - es.a_ticks_left[slot]
	var line: int = _line_of(arena, es.a_z[slot])
	if total <= 0 or t <= 0 or line < 0:
		return
	var x_hi: float = _car_x(arena, total, t - 1)
	var x_lo: float = _car_x(arena, total, t)
	es.a_x[slot] = x_lo
	var lane_z: float = es.a_z[slot]
	var half_width: float = arena.rail_half_width[line]
	var rule: EventDef = world.content.event_def(&"runaway_freight")
	if rule == null:
		return
	var flags: int = DamageResolver.F_AREA | DamageResolver.F_IGNORE_ARMOR
	if rule.param(&"boss_mult", 1.0) < 1.0:
		flags |= DamageResolver.F_BOSS_HALF
	var half_len: float = (x_hi - x_lo) * 0.5
	var near: PackedInt32Array = PackedInt32Array()
	var _n: int = AreaDamage.query(
		world, (x_hi + x_lo) * 0.5, lane_z, sqrt(half_len * half_len + half_width * half_width), near
	)
	var store: EnemyStore = world.enemies
	for i: int in near:
		if store.alive[i] == 0 or absf(store.z[i] - lane_z) > half_width:
			continue
		var ex: float = store.x[i]
		if ex > x_hi or ex < x_lo or (ex == x_lo and t < total):
			continue
		var side: float = 1.0 if store.z[i] >= lane_z else -1.0
		var _dealt: float = DamageResolver.hit_ex(world, i, rule.param(&"damage"), flags, DamageSource.Id.HAZARD)
		if store.alive[i] == 1 and store.stun_ticks[i] == 0:
			var _moved: bool = EventPush.away(world, i, ex, store.z[i] - side, rule.param(&"knockback_m"))
	HazardDrums.touch_lane(world, lane_z, half_width, x_lo, x_hi)


static func _car_x(arena: ArenaDef, total: int, t: int) -> float:
	return arena.max_x - (arena.max_x - arena.min_x) * float(t) / float(total)


static func _line_of(arena: ArenaDef, lane_z: float) -> int:
	for line: int in arena.rail_z.size():
		if absf(arena.rail_z[line] - lane_z) < 0.001:
			return line
	return -1
