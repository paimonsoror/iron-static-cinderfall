class_name EventRunawayFreight
extends RefCounted
## RUNAWAY FREIGHT (`runaway_freight`; VARIETY_SPEC 7.1, CONTENT 6): world. A freight car crosses a rail line in 1.2 s: 700 damage to every enemy within 1.3 m
## of the line (bosses 350), knockback 1.5 m.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
