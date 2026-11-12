class_name EventStaticFront
extends RefCounted
## STATIC FRONT (`static_front`; VARIETY_SPEC 7.1, CONTENT 6): world, harmful. 12 s: abilities cannot be activated (cooldowns frozen, active effects
## continue); wards and auras are down too.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
