class_name EventCoreVent
extends RefCounted
## CORE VENT (`core_vent`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered. Costs 8% of the core maximum (blocked at 10% or less), 220 damage within
## 6 m of the core, knockback 2 m, attack timers reset. Once per wave.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
