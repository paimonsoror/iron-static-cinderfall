class_name PolicyValue
extends RefCounted
## What a directive is worth to a player who wants to live (V4-T): the points of its effects, read from the `ops[]` of the
## data and never from an id. The unit is "a +20% damage level is 2 points" (hot_loads); a stat is a weight per unit of
## change, a flag or a grant a flat number, and a directive whose behaviour lives in a sim hook (no ops of its own) is
## worth its category's default. The spec score of CONTENT 13 (tags, gaps, rarity) is added to this by PolicyScoring; this
## part is what keeps a bot from taking a card that does nothing for it (a Scrap card in a run that has no shop).
## Pure functions of the world; no random stream.

## Points per unit of change of a stat (ModState names, OpDef.STATS). A `*_mul` stat is read as the change from 1.0.
const STAT_WEIGHT: Dictionary[StringName, float] = {
	&"lvl_damage": 2.0, &"lvl_fire_rate": 1.5, &"lvl_armor_piercing": 1.0,
	&"w_dmg_mul": 10.0, &"w_rate_mul": 10.0, &"w_mag_mul": 2.0, &"w_heat_cap_mul": 2.0, &"w_reload_mul": -5.0,
	&"w_full_hp_mul": 3.0, &"w_low_hp_mul": 1.7, &"area_mul": 5.0, &"burn_dps": 0.25, &"range_mul": 5.0,
	&"t_rate_mul": 10.0, &"t_dmg_mul": 10.0, &"t_inherit": 4.0, &"turrets": 4.0,
	&"core_max_mul": 10.0, &"core_regen_wave": 10.0, &"enemy_attack_period_mul": 8.0,
	&"emp_cd_mul": -3.0, &"shield_cd_mul": -3.0, &"od_cd_mul": -3.0, &"ability_cd_mul": -3.0, &"emp_stun_add": 0.3,
	&"shield_absorb_add": 0.01, &"shield_dur_add": 0.2, &"od_dur_add": 0.2, &"stunned_dmg_mul": 4.0,
	&"strike_per_act": 1.0, &"freight_per_act": 0.5, &"scrap_mul": 3.0, &"reroll_cost_mul": -1.0, &"crate_choices": 0.5,
	&"crate_time_mul": -0.4, &"data_per_wave": 0.1, &"draft_slots": 2.0, &"enemy_armor_add": -0.2, &"enemy_hp_mul": -8.0,
	&"spawn_interval_mul": 3.0, &"extra_elites": -1.0,
}
## Stats of the turrets: worth little until a turret stands.
const TURRET_STATS: Array[StringName] = [&"t_rate_mul", &"t_dmg_mul", &"t_inherit"]
const NO_TURRET_FACTOR: float = 0.25
## Flags of OpDef.FLAGS and what they are worth.
const FLAG_VALUE: Dictionary[StringName, float] = {
	&"od_turrets": 0.5, &"od_free_ammo": 1.0, &"crate_never_lost": 0.3, &"last_stand": 1.5, &"scrap_rounds": 1.0,
	&"pads_disabled": -2.0,
}
## Points of a grant (per unit `n`); the repairs are priced by the part of the core they restore.
const GRANT_VALUE: Dictionary[StringName, float] = {
	&"scrap": 0.005, &"free_reroll": 0.4, &"crate": 1.5, &"event_charge": 1.0, &"data": 0.01, &"weapon": 3.0, &"turret": 4.0,
	&"directive": 2.0, &"directive_random": 3.0,
}
## A hook directive (no ops) is worth this much by category (DirectiveDef.Category order: weapon, turret, core, ability,
## economy, corrupted).
const HOOK_DEFAULT: Array[float] = [2.0, 1.5, 1.5, 1.0, 0.5, 0.0]
## Each stack already held is worth this fraction of the one before.
const STACK_DECAY: float = 0.85
const MIN_VALUE: float = -6.0
const MAX_VALUE: float = 10.0


## The points of picking directive `d` now.
static func of(world: SimWorld, d: DirectiveDef) -> float:
	var total: float = 0.0
	if d.ops.is_empty():
		total = HOOK_DEFAULT[clampi(d.category, 0, HOOK_DEFAULT.size() - 1)]
	for op: OpDef in d.ops:
		total += op_value(world, op)
	var held: int = PolicySenses.stacks_of(world, d)
	total *= pow(STACK_DECAY, float(held))
	return clampf(total, MIN_VALUE, MAX_VALUE)


## The points of one op.
static func op_value(world: SimWorld, op: OpDef) -> float:
	match op.kind:
		OpDef.Kind.ADD:
			return stat_value(world, op.target, op.value)
		OpDef.Kind.MUL:
			return stat_value(world, op.target, op.value - 1.0)
		OpDef.Kind.FLAG:
			var flag_points: float = FLAG_VALUE.get(op.target, 0.0)
			return flag_points
		_:
			return grant_value(world, op)


## `delta` of the stat `stat_name` in points. core_max_add is worth its share of the core.
static func stat_value(world: SimWorld, stat_name: StringName, delta: float) -> float:
	if stat_name == &"core_max_add":
		return 10.0 * delta / maxf(world.core_max_hp, 1.0)
	var weight: float = STAT_WEIGHT.get(stat_name, 0.0)
	var points: float = weight * delta
	if TURRET_STATS.has(stat_name) and not turret_stands(world):
		points *= NO_TURRET_FACTOR
	return points


static func grant_value(world: SimWorld, op: OpDef) -> float:
	var n: float = op.amount(clampi(world.phase_state.act, 1, 3))
	var wounded: float = clampf(2.0 * (1.0 - PolicySenses.core_fraction(world)) + 0.3, 0.0, 1.0)
	match op.target:
		&"core_repair":
			return 10.0 * minf(n, world.core_max_hp - world.core_hp) / maxf(world.core_max_hp, 1.0) * wounded
		&"core_repair_frac":
			return 10.0 * n * wounded
		_:
			var per_unit: float = GRANT_VALUE.get(op.target, 0.0)
			return per_unit * n


## A turret is deployed or on its way (a directive or a kit granted one).
static func turret_stands(world: SimWorld) -> bool:
	return world.turrets.active_count() > 0 or world.mods.turrets > 0.0
