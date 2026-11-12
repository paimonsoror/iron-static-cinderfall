class_name EventDeadfallStrike
extends RefCounted
## DEADFALL STRIKE (`deadfall_strike`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered. After warn_ticks, `damage` lands
## within `radius_m` of the densest cluster at the moment of the call (it does not track; 50% at the edge; bosses take
## half; armor is ignored). Charges: start_charges at run start, charges_per_act at each act start, cap charge_cap.
## The first user of HazardSystem.queue_hit(K_STRIKE): the hit is queued when the warning starts and lands on the
## tick the event starts. Rules of every event: no direct damage to the core, the Warden or a turret; a warning
## before the effect.
##
## The `sys_*` functions below are the player-called part of EventSystem (charges, CALL_EVENT, the warn/start/finish
## clock of the active slots). They live here because event_system.gd is not a file of task V2-C: EventSystem's
## init_world, block_reason, call_event and step should delegate to them (see the V2-C report, "needs owner").

const FAR_M: float = 1000.0  ## the whole arena is in reach of a strike


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage != EventSystem.Stage.WARN:
		return
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var radius: float = def.param(&"radius_m") * world.mods.area_mul
	var at: Vector2 = AreaDamage.densest_cluster(world, world.warden.x, world.warden.z, 0.0, FAR_M, radius)
	es.a_x[slot] = at.x
	es.a_z[slot] = at.y
	var flags: int = DamageResolver.F_AREA | DamageResolver.F_IGNORE_ARMOR
	if def.param(&"boss_mult", 1.0) < 1.0:
		flags |= DamageResolver.F_BOSS_HALF
	HazardSystem.queue_hit(
		world, world.tick + def.warn_ticks, HazardState.K_STRIKE, es.a_x[slot], es.a_z[slot], radius,
		def.param(&"damage"), def.param(&"edge_frac", 1.0), flags, DamageSource.Id.STRIKE
	)


## EventSystem.init_world: every player-triggered event starts with `start_charges`.
static func sys_init(world: SimWorld) -> void:
	for def: EventDef in world.content.events:
		if def.who == EventDef.Who.PLAYER:
			world.events_state.charges[def.index] = _capped(def, roundi(def.param(&"start_charges")))


## Adds `n` charges of a player-triggered event up to its `charge_cap` (act starts, route rewards). Pushes
## CHARGES_CHANGED when the count changed.
static func sys_grant(world: SimWorld, event_index: int, n: int) -> void:
	if event_index < 0 or event_index >= world.content.events.size():
		return
	var es: EventState = world.events_state
	var now: int = _capped(world.content.events[event_index], es.charges[event_index] + n)
	if now == es.charges[event_index]:
		return
	es.charges[event_index] = now
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, event_index, now)


## EventSystem.block_reason: OK when the player may call the event now. UNKNOWN_ID; WRONG_STATE for a world event,
## outside a wave, and for a strike with no enemy on the field; NO_CHARGES.
static func sys_block_reason(world: SimWorld, event_index: int) -> int:
	if event_index < 0 or event_index >= world.content.events.size():
		return Reason.Id.UNKNOWN_ID
	var def: EventDef = world.content.events[event_index]
	if def.who != EventDef.Who.PLAYER or not GameState.is_combat(world.phase):
		return Reason.Id.WRONG_STATE
	if world.events_state.charges_of(event_index) <= 0:
		return Reason.Id.NO_CHARGES
	if def.id == &"deadfall_strike" and world.alive_count() == 0:
		return Reason.Id.WRONG_STATE
	return Reason.Id.OK


## EventSystem.call_event: spends a charge (CHARGES_CHANGED), opens an active slot in the warning phase, runs the
## event's WARN stage (which sets the slot's place) and pushes EVENT_WARNED(event, warn ticks, x, z). Returns a
## Reason.Id; a refusal changes nothing. Commands are applied before EventSystem.step of the same tick, so the slot
## starts at warn_ticks + 1: the event starts exactly warn_ticks ticks after the call.
static func sys_call(world: SimWorld, _command_id: int, event_index: int) -> int:
	var reason: int = sys_block_reason(world, event_index)
	if reason != Reason.Id.OK:
		return reason
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[event_index]
	es.charges[event_index] -= 1
	es.used_this_wave[event_index] += 1
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, event_index, es.charges[event_index])
	es.a_event.append(event_index)
	es.a_phase.append(EventState.PH_WARN)
	es.a_ticks_left.append(def.warn_ticks + 1)
	es.a_x.append(0.0)
	es.a_z.append(0.0)
	var slot: int = es.a_event.size() - 1
	EventSystem.dispatch(world, slot, EventSystem.Stage.WARN)
	world.events.push(SimEventKind.Id.EVENT_WARNED, event_index, def.warn_ticks, es.a_x[slot], es.a_z[slot])
	return Reason.Id.OK


## EventSystem.step for the active slots, oldest first: a warning that ends starts the event (START stage,
## EVENT_STARTED, RunStats.events_seen); a running event gets TICK; an event whose duration ends, or has none, gets
## FINISH and EVENT_ENDED and leaves the list.
static func sys_step(world: SimWorld) -> void:
	var es: EventState = world.events_state
	var slot: int = 0
	while slot < es.a_event.size():
		var event_index: int = es.a_event[slot]
		var def: EventDef = world.content.events[event_index]
		es.a_ticks_left[slot] -= 1
		if es.a_ticks_left[slot] > 0:
			if es.a_phase[slot] == EventState.PH_ACTIVE:
				EventSystem.dispatch(world, slot, EventSystem.Stage.TICK)
			slot += 1
			continue
		if es.a_phase[slot] == EventState.PH_WARN:
			es.a_phase[slot] = EventState.PH_ACTIVE
			es.a_ticks_left[slot] = def.duration_ticks
			EventSystem.dispatch(world, slot, EventSystem.Stage.START)
			world.events.push(SimEventKind.Id.EVENT_STARTED, event_index, def.duration_ticks, es.a_x[slot], es.a_z[slot])
			if event_index < world.stats.events_seen.size():
				world.stats.events_seen[event_index] += 1
			if def.duration_ticks > 0:
				slot += 1
				continue
		EventSystem.dispatch(world, slot, EventSystem.Stage.FINISH)
		world.events.push(SimEventKind.Id.EVENT_ENDED, event_index)
		es.a_event.remove_at(slot)
		es.a_phase.remove_at(slot)
		es.a_ticks_left.remove_at(slot)
		es.a_x.remove_at(slot)
		es.a_z.remove_at(slot)


static func _capped(def: EventDef, charges: int) -> int:
	var cap: int = roundi(def.param(&"charge_cap", 99.0))
	return clampi(charges, 0, cap)
