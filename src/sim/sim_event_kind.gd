class_name SimEventKind
extends RefCounted
## Event kinds pushed by the sim (ARCH 6.3). Payload columns: SimEvent a, b, f, g.

enum Id {
	PHASE_CHANGED,
	WAVE_STARTED,
	WAVE_CLEARED,
	INTERMISSION_STARTED,
	ENEMY_SPAWNED,
	BOSS_SPAWNED,
	SHOT_FIRED,
	ENEMY_DAMAGED,
	ENEMY_KILLED,
	SCRAP_CHANGED,
	CORE_HIT,
	CORE_CHANGED,
	SHIELD_CHANGED,
	PURCHASE_RESOLVED,
	UPGRADE_LEVEL_CHANGED,
	WEAPON_CHANGED,
	TURRET_DEPLOYED,
	RELOAD_STARTED,
	RELOAD_FINISHED,
	ABILITY_ACTIVATED,
	ABILITY_ENDED,
	ABILITY_REJECTED,
	ENEMY_STUNNED,
	ENEMY_REACHED_SLOT,
	ENEMY_STUCK,
	SPAWN_QUEUED,
	RUN_FINISHED,
	# --- variety milestone (VARIETY_SPEC 13.2; append only). Payload: a, b, f, g ---
	ACT_STARTED,  ## a act
	DRAFT_OFFERED,  ## a offer ordinal, b slots (the ids are DraftState.offer)
	DIRECTIVE_PICKED,  ## a directive index, b stacks held now
	DRAFT_REROLLED,  ## a offer ordinal, b Scrap paid (the new ids are DraftState.offer)
	ROUTE_OFFERED,  ## a wave, b options
	ROUTE_PICKED,  ## a wave, b option
	BOSS_BRIEFED,  ## a wave, b boss enemy index
	AWAIT_CHANGED,  ## a new PhaseState.Await, b previous
	CRATE_DROPPED,  ## a crate ordinal, b 1 for a boss crate, f x, g z
	CRATE_SECURED,  ## a crate ordinal
	CRATE_LOST,  ## a crate ordinal
	SALVAGE_RESOLVED,  ## a command id, b Reason.Id, f the command arg
	WEAPON_SWAPPED,  ## a slot now active, b weapon index
	WEAPON_VENTED,  ## a slot, b vent ticks
	AREA_BLAST,  ## a HazardState.K_* kind, b radius in cm, f x, g z
	CHAIN_ARC,  ## a from enemy id (0 = the Warden), b to enemy id
	DELAYED_HIT_LAUNCHED,  ## a HazardState.K_* kind, b ticks until it lands, f x, g z
	POOL_STARTED,  ## a pool id, b radius in cm, f x, g z
	POOL_ENDED,  ## a pool id, f x, g z
	ELITE_SPAWNED,  ## a enemy id, b affix mask
	ENEMY_SPLIT,  ## a enemy id, b children, f x, g z
	WARD_CHANGED,  ## a enemy id, f ward now, g ward maximum
	WARD_BROKEN,  ## a enemy id
	ENEMY_HEALED,  ## a enemy id, b healer enemy id, f amount, g hp after
	EVENT_WARNED,  ## a event index, b ticks until it starts, f x, g z
	EVENT_STARTED,  ## a event index, b duration ticks, f x, g z
	EVENT_ENDED,  ## a event index
	EVENT_CANCELLED,  ## a event index, b Reason.Id (the mercy rule cancels with LOCKED_BY_EVENT)
	BOSS_TELEGRAPH,  ## a attack, b ticks until it lands
	BOSS_PHASE,  ## a phase, b phase count
	CORE_HEALED,  ## f amount, g core hp after
	CHARGES_CHANGED,  ## a event index, b charges held
	COMMAND_REJECTED,  ## a command id, b Reason.Id
}
