class_name EventDeadfallStrike
extends RefCounted
## DEADFALL STRIKE (`deadfall_strike`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered. After warn_ticks, `damage` lands within `radius_m` of the densest cluster
## at the moment of the call (it does not track; 50% at the edge; bosses take half). Charges: start_charges at run
## start, charges_per_act at each act start, cap charge_cap. The first user of HazardSystem.queue_hit(K_STRIKE).
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
# TODO(V2-C)


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(_world: SimWorld, _slot: int, _stage: int) -> void:
	pass
