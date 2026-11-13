class_name EventPowerSurge
extends RefCounted
## CORE SURGE (`power_surge`; VARIETY_SPEC 7.1, 7.4, CONTENT 6): world, helpful, boss-safe. For `duration` (10 s) the turrets
## fire at `turret_rate_mult` (x2) and the Warden's reload and vent are instant (EventSystem.surge_active is the
## question ArsenalSystem asks). Then a `brownout_s` (5 s) brownout: the turrets are offline (EventState.turret_offline_ticks)
## unless a Shield was activated during the surge (AbilitySystem -> EventSystem.on_shield_activated sets
## brownout_cancelled), and never while a Static Front is in force (no two tool-denying events at once). The brownout is
## an aftermath, not a slot: the event itself ends when the surge does.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: turret_rate_mult, brownout_s.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	match stage:
		EventSystem.Stage.START:
			es.turret_rate_milli = roundi(def.param(&"turret_rate_mult", 2.0) * 1000.0)
			es.turret_rate_ticks = def.duration_ticks
			es.brownout_cancelled = 0
		EventSystem.Stage.FINISH:
			es.turret_rate_milli = 1000
			es.turret_rate_ticks = 0
			if es.brownout_cancelled == 0 and es.ability_lock_ticks == 0:
				EventSystem.take_turrets_offline(world, roundi(def.param(&"brownout_s") * 60.0))
			es.brownout_cancelled = 0
