class_name ModState
extends RefCounted
## Run-wide modifiers (VARIETY_SPEC 13.2): a flat set of typed fields that ModSystem recomputes whenever a directive,
## the kit or the wave modifier changes. One float per OpDef.STATS entry (a `*_mul` field starts at 1.0, the others at
## 0.0) and one byte per OpDef.FLAGS entry. Written by ModSystem only; everything is hashed.
## ModSystem.recompute rebuilds it from the kit, the held directives and the wave modifier; the route rewards that arm
## a flag of the next draft (next_draft_rare, next_draft_double) set the bit until the next recompute and arm DraftState.

var lvl_damage: float = 0.0
var lvl_fire_rate: float = 0.0
var lvl_armor_piercing: float = 0.0
var w_dmg_mul: float = 1.0
var w_rate_mul: float = 1.0
var w_mag_mul: float = 1.0
var w_heat_cap_mul: float = 1.0
var w_reload_mul: float = 1.0
var w_full_hp_mul: float = 1.0
var w_low_hp_mul: float = 1.0
var w_low_hp_threshold: float = 0.0
var swap_ticks_add: float = 0.0
var area_mul: float = 1.0
var burn_dps: float = 0.0
var turrets: float = 0.0
var t_rate_mul: float = 1.0
var t_dmg_mul: float = 1.0
var t_inherit: float = 0.0
var core_max_add: float = 0.0
var core_max_mul: float = 1.0
var core_regen_wave: float = 0.0
var enemy_attack_period_mul: float = 1.0
var emp_cd_mul: float = 1.0
var shield_cd_mul: float = 1.0
var od_cd_mul: float = 1.0
var ability_cd_mul: float = 1.0
var emp_stun_add: float = 0.0
var shield_absorb_add: float = 0.0
var shield_dur_add: float = 0.0
var od_dur_add: float = 0.0
var stunned_dmg_mul: float = 1.0
var strike_per_act: float = 0.0
var freight_per_act: float = 0.0
var scrap_mul: float = 1.0
var reroll_cost_mul: float = 1.0
var crate_choices: float = 0.0
var crate_time_mul: float = 1.0
var data_per_wave: float = 0.0
var draft_slots: float = 0.0
var enemy_armor_add: float = 0.0
var enemy_hp_mul: float = 1.0
var spawn_interval_mul: float = 1.0
var range_mul: float = 1.0
var ability_cd_rate_mul: float = 1.0
var turret_offline_ticks: float = 0.0
var extra_elites: float = 0.0
var volatile_radius: float = 0.0
var volatile_damage: float = 0.0
var flags: PackedByteArray = PackedByteArray()  ## indexed like OpDef.FLAGS
var wave_modifier: int = -1  ## the ModifierDef index of the current wave, or -1


func _init() -> void:
	flags.resize(OpDef.FLAGS.size())
	reset()


## Every stat back to its neutral value, every flag off. ModSystem.recompute starts from here.
func reset() -> void:
	for stat_name: String in OpDef.STATS:
		set(stat_name, default_of(stat_name))
	flags.fill(0)


static func default_of(stat_name: String) -> float:
	return 1.0 if stat_name.ends_with("_mul") else 0.0


func stat(stat_name: StringName) -> float:
	var v: float = get(stat_name)
	return v


func has_flag(flag_name: StringName) -> bool:
	var i: int = OpDef.FLAGS.find(String(flag_name))
	return i >= 0 and flags[i] != 0


func set_flag(flag_name: StringName, on: bool) -> void:
	var i: int = OpDef.FLAGS.find(String(flag_name))
	if i >= 0:
		flags[i] = 1 if on else 0


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, OpDef.STATS)
	h.put_bytes(flags)
	h.put_int(wave_modifier)


func to_dict() -> Dictionary:
	var d: Dictionary = SnapUtil.to_dict(self, OpDef.STATS)
	d["flags"] = Array(flags)
	d["wave_modifier"] = wave_modifier
	return d


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, OpDef.STATS, d)
	SnapUtil.from_dict(self, PackedStringArray(["flags", "wave_modifier"]), d)
	flags.resize(OpDef.FLAGS.size())
