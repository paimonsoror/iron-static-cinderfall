class_name EventDeadfallStrike
extends RefCounted
## DEADFALL STRIKE (`deadfall_strike`; VARIETY_SPEC 7.1, CONTENT 6): player-triggered. After warn_ticks, `damage` lands
## within `radius_m` of the densest cluster at the moment of the call (it does not track; 50% at the edge; bosses take
## half; armor is ignored). Charges: start_charges at run start, charges_per_act at each act start, cap charge_cap.
## The first user of HazardSystem.queue_hit(K_STRIKE): the hit is queued when the warning starts and lands on the
## tick the event starts. Rules of every event: no direct damage to the core, the Warden or a turret; a warning
## before the effect.
##
## The `sys_*` functions are the entry points V2-C wrote before EventSystem was filled; they now delegate to
## EventSlots (charges and the slot clock) and EventSystem (the call and its refusals), which is where the code lives.

const FAR_M: float = 1000.0  ## the whole arena is in reach of a strike


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage != EventSystem.Stage.WARN:
		return
	var es: EventState = world.events_state
	var def: EventDef = world.content.events[es.a_event[slot]]
	var radius: float = def.param(&"radius_m") * world.mods.area_mul
	var at: Vector2 = AreaDamage.densest_cluster(world, world.warden.x, world.warden.z, 0.0, FAR_M, radius)
	es.a_x[slot] = at.x
	es.a_z[slot] = at.y
	var flags: int = DamageResolver.F_AREA | DamageResolver.F_IGNORE_ARMOR
	if def.param(&"boss_mult", 1.0) < 1.0:
		flags |= DamageResolver.F_BOSS_HALF
	var _seq: int = HazardSystem.queue_hit(
		world, world.tick + def.warn_ticks, HazardState.K_STRIKE, es.a_x[slot], es.a_z[slot], radius,
		def.param(&"damage"), def.param(&"edge_frac", 1.0), flags, DamageSource.Id.STRIKE
	)


## EventSystem.init_world: every player-triggered event starts with `start_charges` (added to what a kit gave, once).
static func sys_init(world: SimWorld) -> void:
	EventSlots.init_charges(world)


## Adds `n` charges of a player-triggered event up to its `charge_cap` (act starts, route rewards). Pushes
## CHARGES_CHANGED when the count changed.
static func sys_grant(world: SimWorld, event_index: int, n: int) -> void:
	EventSlots.grant(world, event_index, n)


## EventSystem.block_reason: OK when the player may call the event now.
static func sys_block_reason(world: SimWorld, event_index: int) -> int:
	return EventSystem.block_reason(world, event_index)


## EventSystem.call_event: spends a charge, opens the slot in the warning phase and pushes EVENT_WARNED. A refusal
## changes nothing. Commands are applied before EventSystem.step of the same tick, so the event starts exactly
## warn_ticks ticks after the call.
static func sys_call(world: SimWorld, command_id: int, event_index: int) -> int:
	return EventSystem.call_event(world, command_id, event_index)


## The slot clock of EventSystem.step (EventSlots.step).
static func sys_step(world: SimWorld) -> void:
	EventSlots.step(world)
