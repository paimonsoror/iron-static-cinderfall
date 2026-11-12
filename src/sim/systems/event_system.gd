class_name EventSystem
extends RefCounted
## Chaos events (tick step 4; VARIETY_SPEC 7): warnings, starts and ends of planned and called events, the fairness
## rules of 7.3, the charges of player-triggered events. The only writer of EventState. Each event lives in its own
## file under systems/events/ with the same four functions (warn, start, tick, finish); `dispatch` is the one place
## that maps an EventDef id to its file. Called every tick of a live run: gate on combat inside.
# TODO(V2-C): CALL_EVENT, charges and the Deadfall Strike. TODO(V4-V): planned events and the rest.

enum Stage { WARN, START, TICK, FINISH }


## Starting charges of the player-triggered events. Called once by SimWorld._init.
static func init_world(world: SimWorld) -> void:
	EventDeadfallStrike.sys_init(world)


static func step(world: SimWorld) -> void:
	EventDeadfallStrike.sys_step(world)


## Resets the per-wave counters and the plan cursor. Called by PhaseSystem when a wave starts.
static func begin_wave(_world: SimWorld, _wave: int) -> void:
	pass


## CALL_EVENT: a HUD button (STRIKE, VENT, FREIGHT). Returns a Reason.Id; pushes EVENT_WARNED or COMMAND_REJECTED.
static func call_event(world: SimWorld, command_id: int, event_index: int) -> int:
	return EventDeadfallStrike.sys_call(world, command_id, event_index)


## Reason.Id.OK when the player may call the event right now (NO_CHARGES, LOCKED_BY_EVENT, WRONG_STATE, UNKNOWN_ID).
static func block_reason(world: SimWorld, event_index: int) -> int:
	return EventDeadfallStrike.sys_block_reason(world, event_index)


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
