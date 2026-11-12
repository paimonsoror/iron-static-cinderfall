class_name EventPowerSurge
extends RefCounted
## CORE SURGE (`power_surge`; VARIETY_SPEC 7.1, CONTENT 6): world. 10 s: turrets fire x2, reload and vent are instant; then a 5 s brownout (turrets
## offline) unless a Shield was activated during the surge.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
