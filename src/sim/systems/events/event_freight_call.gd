class_name EventFreightCall
extends RefCounted
## FREIGHT (`freight_call`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered, needs `signal_hijack` (the directive grants the
## charge: one per act, cap 1). It calls the Runaway Freight on the rail line with more enemies on it: the warning
## (4 s) shows the lane, then the car crosses it exactly as the world event does, with the damage, boss share and
## knockback of the `runaway_freight` entry (EventRunawayFreight does the work for both).
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: start_charges, charges_per_act, charge_cap.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	EventRunawayFreight.run_pass(world, slot, stage)
