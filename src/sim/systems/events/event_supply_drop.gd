class_name EventSupplyDrop
extends RefCounted
## ACCORD DROP (`supply_drop`; VARIETY_SPEC 7.1, CONTENT 6): world. A crate lands on a drop point (SalvageSystem.drop_crate); the nearest skitters and
## rushers divert to stand on it.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V4-V)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
