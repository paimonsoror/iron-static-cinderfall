class_name EventAccordWindow
extends RefCounted
## RELAY WINDOW (`accord_window`; VARIETY_SPEC 7.1, CONTENT 6): world, helpful, boss-safe. For `duration` (10 s) the Scrap
## from kills is multiplied by `scrap_mult` (2.0): DeathHooks.scrap_for reads EventState.scrap_mult_milli while
## scrap_mult_ticks runs. There is no warning to speak of (warn_s 0): the event is announced as it opens.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: scrap_mult.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	match stage:
		EventSystem.Stage.START:
			es.scrap_mult_milli = roundi(def.param(&"scrap_mult", 2.0) * 1000.0)
			es.scrap_mult_ticks = def.duration_ticks
		EventSystem.Stage.FINISH:
			es.scrap_mult_milli = 1000
			es.scrap_mult_ticks = 0
