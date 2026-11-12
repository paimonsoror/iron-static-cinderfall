class_name EventFreightCall
extends RefCounted
## FREIGHT (`freight_call`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered, needs signal_hijack. Calls runaway_freight on the rail line with more
## enemies. One charge per act.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
