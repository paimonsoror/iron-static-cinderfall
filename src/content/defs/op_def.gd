class_name OpDef
extends RefCounted
## One entry of the `ops[]` grammar shared by directives, modifiers, kits, affixes and route rewards (VARIETY_SPEC 13.1):
##   { "stat": "<ModState field>", "add": n }   { "stat": "<ModState field>", "mul": n }
##   { "flag": "<name>" }                       { "grant": "<kind>", "n": n, "id": "<optional id>", "per_act": n }
## ModSystem (V2-B) interprets it. The name lists below ARE the contract: the validator rejects any other name, and
## ModState (src/sim/stores/mod_state.gd) has one float field per STATS entry and one flag per FLAGS entry (a
## contract test compares them). A `*_mul` stat starts at 1.0, every other stat at 0.0; `add` adds, `mul` multiplies.

enum Kind { ADD, MUL, FLAG, GRANT }

## Run-wide stats (directives, kits, wave modifiers, route rewards).
const STATS: PackedStringArray = [
	"lvl_damage", "lvl_fire_rate", "lvl_armor_piercing",
	"w_dmg_mul", "w_rate_mul", "w_mag_mul", "w_heat_cap_mul", "w_reload_mul", "w_full_hp_mul", "w_low_hp_mul",
	"w_low_hp_threshold", "swap_ticks_add", "area_mul", "burn_dps",
	"turrets", "t_rate_mul", "t_dmg_mul", "t_inherit",
	"core_max_add", "core_max_mul", "core_regen_wave", "enemy_attack_period_mul",
	"emp_cd_mul", "shield_cd_mul", "od_cd_mul", "ability_cd_mul", "emp_stun_add", "shield_absorb_add", "shield_dur_add",
	"od_dur_add", "stunned_dmg_mul", "strike_per_act", "freight_per_act",
	"scrap_mul", "reroll_cost_mul", "crate_choices", "crate_time_mul", "data_per_wave", "draft_slots",
	"enemy_armor_add", "enemy_hp_mul", "spawn_interval_mul", "range_mul", "ability_cd_rate_mul", "turret_offline_ticks",
	"extra_elites", "volatile_radius", "volatile_damage",
]
const FLAGS: PackedStringArray = [
	"od_turrets", "od_free_ammo", "crate_never_lost", "volatile_skitters", "twin_gate", "no_breather", "last_stand",
	"scrap_rounds", "next_draft_rare", "next_draft_double", "no_turret_pity", "pads_disabled",
]
const GRANTS: PackedStringArray = [
	"scrap", "core_repair", "core_repair_frac", "free_reroll", "crate", "event_charge", "data", "weapon", "turret",
	"directive", "directive_random",
]
## Per-enemy stats and flags of elite affixes (EliteSystem, V4-N).
const AFFIX_STATS: PackedStringArray = ["armor_add", "hp_mul", "speed_mul"]
const AFFIX_FLAGS: PackedStringArray = ["volatile", "regen", "warded", "magnetic", "overclock", "anchored", "leech", "shroud"]

var kind: int = Kind.ADD
var target: StringName  ## the stat, flag or grant kind
var value: float = 0.0  ## add amount, mul factor, or grant count
var per_act: float = 0.0  ## GRANT only: added to `value` per act after the first
var arg: StringName = &""  ## GRANT only: the granted id (a weapon, directive, event id or a rarity name), or empty


## The grant amount in act `act_number` (1-based).
func amount(act_number: int) -> float:
	return value + per_act * float(maxi(0, act_number - 1))


func to_dict() -> Dictionary:
	return {"kind": kind, "target": String(target), "value": value, "per_act": per_act, "arg": String(arg)}
