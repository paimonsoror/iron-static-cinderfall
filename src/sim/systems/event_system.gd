class_name EventSystem
extends RefCounted
## Chaos events (tick step 4; VARIETY_SPEC 7): warnings, starts and ends of planned and called events, the fairness
## rules of 7.3, the charges of player-triggered events. The only writer of EventState. Each event lives in its own
## file under systems/events/ with the same four stages (warn, start, tick, finish); `dispatch` is the one place
## that maps an EventDef id to its file. Called every tick of a live run: gate on combat inside.
##
## One step: (1) in combat, the planned events whose time has come start their warning (EventSchedule: mercy, harmful
## limits, one tool-denying event at a time), out of combat the world events end; (2) the timers count down
## (Static Front lock, brownout, Core Surge, Relay Window); (3) the slot clock runs (EventSlots). Commands were applied
## before this step, so a called event and a planned one both start exactly warn_ticks ticks after they opened.
## Related files: events/event_slots.gd (the clock and the charges), events/event_schedule.gd (the plan side),
## events/event_rates.gd (cooldown and turret rates read by AbilitySystem and TurretSystem).

enum Stage { WARN, START, TICK, FINISH }


## Starting charges of the player-triggered events. Called once by SimWorld._init, after the kit grants.
static func init_world(world: SimWorld) -> void:
	EventSlots.init_charges(world)


static func step(world: SimWorld) -> void:
	if GameState.is_combat(world.phase):
		EventSchedule.launch_due(world)
	else:
		EventSchedule.end_of_wave(world)
	_count_down(world.events_state)
	EventSlots.step(world)


## Resets the per-wave counters and the plan cursor and lays the drums of a new act. Called by PhaseSystem when a wave starts.
static func begin_wave(world: SimWorld, wave: int) -> void:
	EventSchedule.begin_wave(world, wave)


## CALL_EVENT: a HUD button (STRIKE, VENT, FREIGHT). Returns a Reason.Id; a refusal changes nothing (CommandSystem
## answers it with COMMAND_REJECTED). On success it spends a charge (CHARGES_CHANGED), opens the slot in the warning
## phase and pushes EVENT_WARNED(event, warn ticks, x, z).
static func call_event(world: SimWorld, _command_id: int, event_index: int) -> int:
	var reason: int = block_reason(world, event_index)
	if reason != Reason.Id.OK:
		return reason
	var es: EventState = world.events_state
	es.charges[event_index] -= 1
	es.used_this_wave[event_index] += 1
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, event_index, es.charges[event_index])
	var _slot: int = EventSlots.open(world, event_index)
	return Reason.Id.OK


## Reason.Id.OK when the player may call the event right now. UNKNOWN_ID for an index that is no event; WRONG_STATE for
## a world event, outside a wave, for a strike with no enemy on the field and for a vent at or below `block_core_frac`
## of the core; NO_CHARGES.
static func block_reason(world: SimWorld, event_index: int) -> int:
	if event_index < 0 or event_index >= world.content.events.size():
		return Reason.Id.UNKNOWN_ID
	var def: EventDef = world.content.events[event_index]
	if def.who != EventDef.Who.PLAYER or not GameState.is_combat(world.phase):
		return Reason.Id.WRONG_STATE
	if world.events_state.charges_of(event_index) <= 0:
		return Reason.Id.NO_CHARGES
	if def.id == &"deadfall_strike" and world.alive_count() == 0:
		return Reason.Id.WRONG_STATE
	if def.id == &"core_vent" and world.core_hp <= def.param(&"block_core_frac") * world.core_max_hp:
		return Reason.Id.WRONG_STATE
	return Reason.Id.OK


## Adds `n` charges of a player-triggered event up to its cap (act starts, route rewards, directives).
static func grant_charges(world: SimWorld, event_index: int, n: int) -> void:
	EventSlots.grant(world, event_index, n)


## Takes the turrets offline for `ticks` more ticks (a Tremor Rig stomp); a longer outage already running stays.
static func take_turrets_offline(world: SimWorld, ticks: int) -> void:
	world.events_state.turret_offline_ticks = maxi(world.events_state.turret_offline_ticks, ticks)


## True during the 10 s of a Core Surge: the Warden's reload and vent are instant while it lasts (ArsenalSystem asks).
static func surge_active(world: SimWorld) -> bool:
	return EventRates.surge_active(world)


## A Shield was activated (AbilitySystem): during a Core Surge it cancels the brownout that follows.
static func on_shield_activated(world: SimWorld) -> void:
	if EventRates.surge_active(world):
		world.events_state.brownout_cancelled = 1


## Runs one stage of the event in active slot `slot` (index into EventState.a_*).
static func dispatch(world: SimWorld, slot: int, stage: int) -> void:
	var es: EventState = world.events_state
	if slot < 0 or slot >= es.a_event.size():
		return
	match world.content.events[es.a_event[slot]].id:
		&"deadfall_strike":
			EventDeadfallStrike.run(world, slot, stage)
		&"core_vent":
			EventCoreVent.run(world, slot, stage)
		&"freight_call":
			EventFreightCall.run(world, slot, stage)
		&"accord_window":
			EventAccordWindow.run(world, slot, stage)
		&"supply_drop":
			EventSupplyDrop.run(world, slot, stage)
		&"power_surge":
			EventPowerSurge.run(world, slot, stage)
		&"runaway_freight":
			EventRunawayFreight.run(world, slot, stage)
		&"static_front":
			EventStaticFront.run(world, slot, stage)
		&"floor_breach":
			EventFloorBreach.run(world, slot, stage)
		&"recount":
			EventRecount.run(world, slot, stage)


## The timers of the events count down once per tick; a timer that reaches 0 puts its rate back to normal.
static func _count_down(es: EventState) -> void:
	if es.ability_lock_ticks > 0:
		es.ability_lock_ticks -= 1
	if es.turret_offline_ticks > 0:
		es.turret_offline_ticks -= 1
	if es.turret_rate_ticks > 0:
		es.turret_rate_ticks -= 1
		if es.turret_rate_ticks == 0:
			es.turret_rate_milli = 1000
	if es.scrap_mult_ticks > 0:
		es.scrap_mult_ticks -= 1
		if es.scrap_mult_ticks == 0:
			es.scrap_mult_milli = 1000
