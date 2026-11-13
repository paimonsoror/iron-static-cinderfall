class_name EventFloorBreach
extends RefCounted
## FLOOR BREACH (`floor_breach`; VARIETY_SPEC 7.1, 7.4, CONTENT 6): world, harmful, not boss-safe, no weight in act I. The
## warning (2.5 s) picks `points_act2` (act I and II) or `points_act3` (act III) of the arena's breach points from the stream
## `event.place:<wave>` (a partial shuffle), shows the first one as the slot position and pushes one more EVENT_WARNED for
## each other point; EventState.breach_mask remembers them. Then every chosen point sends `borers_base + act` borers out of
## the ground, in a small ring around the point. Borers that emerge while the stun of an EMP is still running are stunned for
## what is left of it; mines and pools on a breach hit them as they emerge (they are ordinary enemies from the first tick).
## A borer the caps have no room for waits in the spawn queue (SpawnSystem.enqueue) and emerges as soon as there is room.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: points_act2, points_act3, borers_base, ring_m.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage == EventSystem.Stage.WARN:
		_pick(world, slot)
	elif stage == EventSystem.Stage.START:
		_open(world, slot)


## How many breach points open in `act`.
static func points_for(def: EventDef, act: int) -> int:
	return roundi(def.param(&"points_act3") if act >= 3 else def.param(&"points_act2"))


static func _pick(world: SimWorld, slot: int) -> void:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var points: PackedVector2Array = world.content.arena.breach_points
	var order: PackedInt32Array = PackedInt32Array()
	for k: int in points.size():
		order.append(k)
	var stream: RandomNumberGenerator = world.rng.stream(StringName("event.place:%d" % world.wave))
	var count: int = mini(points_for(def, world.phase_state.act), points.size())
	es.breach_mask = 0
	for n: int in count:
		var j: int = n + stream.randi_range(0, order.size() - 1 - n)
		var held: int = order[n]
		order[n] = order[j]
		order[j] = held
		es.breach_mask |= 1 << order[n]
		if n == 0:
			es.a_x[slot] = points[order[n]].x
			es.a_z[slot] = points[order[n]].y
		else:
			world.events.push(SimEventKind.Id.EVENT_WARNED, def.index, def.warn_ticks, points[order[n]].x, points[order[n]].y)


static func _open(world: SimWorld, slot: int) -> void:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var points: PackedVector2Array = world.content.arena.breach_points
	var borers: int = roundi(def.param(&"borers_base")) + world.phase_state.act
	var ring: float = def.param(&"ring_m")
	var stun_left: int = es.emp_until - world.tick
	for k: int in points.size():
		if (es.breach_mask & (1 << k)) == 0:
			continue
		for n: int in borers:
			var angle: float = float(n) * 2.399963229728653
			var x: float = points[k].x + ring * cos(angle)
			var z: float = points[k].y + ring * sin(angle)
			var i: int = world.spawn_enemy(Ids.EN_BORER, x, z)
			if i < 0:
				SpawnSystem.enqueue(world, Ids.EN_BORER, x, z)
			elif stun_left > 0:
				world.enemies.stun_ticks[i] = stun_left
				world.events.push(SimEventKind.Id.ENEMY_STUNNED, world.enemies.id[i], stun_left)
	es.breach_mask = 0
