class_name EventSlots
extends RefCounted
## The active slots of EventState (`a_*`): one entry per event that is warning or running, oldest first, and the charges of
## the player-triggered events. Every event goes through the same clock:
##   open: the slot is made in the warning phase with warn_ticks + 1 ticks (the tick it opens on counts, because the
##         command or the schedule runs before the slot clock of the same tick), the WARN stage picks the place, and
##         EVENT_WARNED(event, warn ticks, x, z) is pushed;
##   step: a warning that runs out starts the event (START stage, EVENT_STARTED, RunStats.events_seen); a running event
##         gets TICK each tick; an event whose duration ends, or has none, gets FINISH and EVENT_ENDED and leaves.
## So an event starts exactly warn_ticks ticks after it was called or scheduled, and ends duration_ticks ticks later.

const FAR_RESERVE: int = 99  ## charge cap of an event without `charge_cap`


## Starting charges (once per world: a kit grant made before this call is kept and the start is added to it).
static func init_charges(world: SimWorld) -> void:
	var es: EventState = world.events_state
	if es.charges_ready == 1:
		return
	es.charges_ready = 1
	for def: EventDef in world.content.events:
		if def.who == EventDef.Who.PLAYER:
			es.charges[def.index] = capped(def, es.charges[def.index] + roundi(def.param(&"start_charges")))


## Adds `n` charges of a player-triggered event up to its `charge_cap`. Pushes CHARGES_CHANGED when the count changed.
static func grant(world: SimWorld, event_index: int, n: int) -> void:
	if event_index < 0 or event_index >= world.content.events.size():
		return
	var es: EventState = world.events_state
	var now: int = capped(world.content.events[event_index], es.charges[event_index] + n)
	if now == es.charges[event_index]:
		return
	es.charges[event_index] = now
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, event_index, now)


## Sets the charges of a player-triggered event (the Core Vent's one charge per wave). Pushes CHARGES_CHANGED on a change.
static func set_charges(world: SimWorld, event_index: int, n: int) -> void:
	var es: EventState = world.events_state
	var now: int = capped(world.content.events[event_index], n)
	if now == es.charges[event_index]:
		return
	es.charges[event_index] = now
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, event_index, now)


## Opens a slot for `event_index` in the warning phase, runs its WARN stage and pushes EVENT_WARNED. Returns the slot.
static func open(world: SimWorld, event_index: int) -> int:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[event_index]
	es.a_event.append(event_index)
	es.a_phase.append(EventState.PH_WARN)
	es.a_ticks_left.append(def.warn_ticks + 1)
	es.a_x.append(0.0)
	es.a_z.append(0.0)
	var slot: int = es.a_event.size() - 1
	EventSystem.dispatch(world, slot, EventSystem.Stage.WARN)
	world.events.push(SimEventKind.Id.EVENT_WARNED, event_index, def.warn_ticks, es.a_x[slot], es.a_z[slot])
	return slot


## The slot clock (see the class comment), oldest slot first.
static func step(world: SimWorld) -> void:
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
		remove(es, slot)


## The wave is over: world events end now (a warning is cancelled, a running event finishes); events the player called
## (a strike in the air) play out.
static func end_world_events(world: SimWorld) -> void:
	var es: EventState = world.events_state
	var slot: int = es.a_event.size() - 1
	while slot >= 0:
		var event_index: int = es.a_event[slot]
		if world.content.events[event_index].who == EventDef.Who.WORLD:
			if es.a_phase[slot] == EventState.PH_WARN:
				world.events.push(SimEventKind.Id.EVENT_CANCELLED, event_index, Reason.Id.WRONG_STATE)
				es.cancelled += 1
			else:
				EventSystem.dispatch(world, slot, EventSystem.Stage.FINISH)
				world.events.push(SimEventKind.Id.EVENT_ENDED, event_index)
			remove(es, slot)
		slot -= 1


static func remove(es: EventState, slot: int) -> void:
	es.a_event.remove_at(slot)
	es.a_phase.remove_at(slot)
	es.a_ticks_left.remove_at(slot)
	es.a_x.remove_at(slot)
	es.a_z.remove_at(slot)


## `charges` held at most `charge_cap` (99 without one) and never negative.
static func capped(def: EventDef, charges: int) -> int:
	return clampi(charges, 0, roundi(def.param(&"charge_cap", float(FAR_RESERVE))))
