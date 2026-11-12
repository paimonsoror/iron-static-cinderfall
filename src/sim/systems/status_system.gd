class_name StatusSystem
extends RefCounted
## Per-enemy statuses (tick step 7): slow, burn, ward regeneration, auras, reclaimer tethers. Writes EnemyExtState.
## Burn damage goes through DamageResolver.hit_ex(F_BURN) with the source HAZARD. Called every tick of a live run.
##
## Burn: `burn_ticks` counts down every tick; a burning enemy takes a pulse of half a second of damage on every tick
## where (tick + enemy id) is a multiple of PULSE_TICKS, so a burn that is refreshed by every hit still deals its
## damage and a 3 s burn of 8 per second deals exactly 24. No float accumulates (VARIETY_SPEC 9.5 rule 4).
# TODO(V4-N): slow, wards, auras, tethers.

const PULSE_TICKS: int = 30
const DEFAULT_BURN_TICKS: int = 180


static func step(world: SimWorld) -> void:
	if world.content.run == null:
		return
	var store: EnemyStore = world.enemies
	var ext: EnemyExtState = world.ext
	var burning: PackedInt32Array = ext.burn_ticks  # a view for the scan; the writes below go to `ext`
	var alive: PackedByteArray = store.alive
	for i: int in store.high_water:
		if burning[i] <= 0 or alive[i] == 0:
			continue
		ext.burn_ticks[i] = burning[i] - 1
		if (world.tick + store.id[i]) % PULSE_TICKS != 0:
			continue
		var pulse: float = float(ext.burn_milli[i]) * float(PULSE_TICKS) / 60000.0
		DamageResolver.hit_ex(world, i, pulse, DamageResolver.F_BURN | DamageResolver.F_AREA, DamageSource.Id.HAZARD)


## Slows an enemy by `milli` / 1000 of its speed for `ticks` (the stronger slow wins, never stacks).
# TODO(V4-N)
static func apply_slow(_world: SimWorld, _enemy_index: int, _ticks: int, _milli: int) -> void:
	pass


## Ignites an enemy: `dps_milli` damage per second x 1000 for `ticks` (refreshes, does not stack).
static func apply_burn(world: SimWorld, enemy_index: int, ticks: int, dps_milli: int) -> void:
	if enemy_index < 0 or enemy_index >= world.ext.capacity or world.enemies.alive[enemy_index] == 0:
		return
	if ticks <= 0 or dps_milli <= 0:
		return
	world.ext.burn_ticks[enemy_index] = ticks
	world.ext.burn_milli[enemy_index] = dps_milli


## The burn of `incendiary_tips` (ModState.burn_dps > 0) on an enemy the Warden just hit.
static func ignite(world: SimWorld, enemy_index: int) -> void:
	var dps: float = world.mods.burn_dps
	if dps <= 0.0:
		return
	apply_burn(world, enemy_index, burn_ticks(world), roundi(dps * 1000.0))


## How long a burn lasts (data/events.json hazards.burn.seconds).
static func burn_ticks(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or not run.hazards.has(&"burn"):
		return DEFAULT_BURN_TICKS
	var burn: Dictionary = run.hazards[&"burn"]
	if not burn.has(&"seconds"):
		return DEFAULT_BURN_TICKS
	var seconds: float = burn[&"seconds"]
	return Formulas.ticks(seconds)
