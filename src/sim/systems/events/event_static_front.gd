class_name EventStaticFront
extends RefCounted
## STATIC FRONT (`static_front`; VARIETY_SPEC 7.1, 7.4, CONTENT 6): world, harmful, not boss-safe, with the longest warning
## (6 s). For `duration` (12 s) EMP, Shield and Overdrive cannot be activated (AbilitySystem answers LOCKED_BY_EVENT),
## their cooldowns do not run (EventRates.cooldown_ticks gives 0), and an ability that was already active keeps running
## to its end. Enemy wards, shieldbearer pools and jammer auras are down while EventState.ability_lock_ticks > 0
## (EventRates.lock_active; the jammer rates read it, StatusSystem reads it for the wards). Motes are stunned
## `mote_stun_s` when the front arrives. Turrets and the Warden's pad are not affected.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: mote_stun_s.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	match stage:
		EventSystem.Stage.START:
			es.ability_lock_ticks = def.duration_ticks
			_stun_motes(world, roundi(def.param(&"mote_stun_s") * 60.0))
		EventSystem.Stage.FINISH:
			es.ability_lock_ticks = 0


static func _stun_motes(world: SimWorld, ticks: int) -> void:
	var store: EnemyStore = world.enemies
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.type[i] != Ids.EN_MOTE or store.stun_ticks[i] >= ticks:
			continue
		store.stun_ticks[i] = ticks
		world.events.push(SimEventKind.Id.ENEMY_STUNNED, store.id[i], ticks)
