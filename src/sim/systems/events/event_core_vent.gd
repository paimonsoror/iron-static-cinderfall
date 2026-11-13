class_name EventCoreVent
extends RefCounted
## CORE VENT (`core_vent`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered, once per wave (one charge, refilled when a wave
## starts), blocked while the core is at or below `block_core_frac` of its maximum. The call costs `core_cost_frac` of the
## core maximum at once (the player pays: this is the one event that touches the core, and the block keeps it above 2%);
## `warn_ticks` later `damage` lands on every enemy within `radius_m` of the core (armor ignored), the survivors are thrown
## back `knockback_m` and the attackers' attack timers start anew (EventPush). The blast is a K_VENT hit of HazardSystem.
## Rules of every event: no damage from the event itself to the core, the Warden or a turret; a warning before the effect.
## params: core_cost_frac, block_core_frac, damage, radius_m, knockback_m, start_charges, charges_per_wave, charge_cap.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage != EventSystem.Stage.WARN:
		return
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var arena: ArenaDef = world.content.arena
	es.a_x[slot] = arena.core_x
	es.a_z[slot] = arena.core_z
	if not world.config.debug_invulnerable_core:
		world.set_core_hp(world.core_hp - def.param(&"core_cost_frac") * world.core_max_hp)
	var _seq: int = HazardSystem.queue_hit(
		world, world.tick + def.warn_ticks, HazardState.K_VENT, arena.core_x, arena.core_z, def.param(&"radius_m"),
		def.param(&"damage"), 1.0, DamageResolver.F_AREA | DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.CORE
	)


## The vent blast has landed (HazardSystem): the survivors within `radius` of (x, z) are thrown back.
static func land(world: SimWorld, x: float, z: float, radius: float) -> void:
	var def: EventDef = world.content.event_def(&"core_vent")
	if def == null:
		return
	var knock: float = def.param(&"knockback_m")
	var near: PackedInt32Array = PackedInt32Array()
	var _n: int = AreaDamage.query(world, x, z, radius, near)
	for i: int in near:
		var _moved: bool = EventPush.away(world, i, x, z, knock)
