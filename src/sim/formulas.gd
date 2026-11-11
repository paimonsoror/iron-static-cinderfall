class_name Formulas
extends RefCounted
## Pure rule formulas (ARCH 6.5). Golden values are pinned in tests/unit/sim/test_formulas.gd.


static func ticks(seconds: float) -> int:
	return roundi(seconds * 60.0)


static func upgrade_cost(base_cost: int, growth: float, level: int) -> int:
	return floori(float(base_cost) * pow(growth, float(level)) + 0.5 + 1e-9)


static func effective_armor(armor: float, piercing_level: int, per_level: float, cap: float) -> float:
	return maxf(0.0, armor * (1.0 - minf(cap, per_level * float(piercing_level))))


static func hit_damage(base_damage: float, damage_level: int, per_level: float, eff_armor: float) -> float:
	return maxf(1.0, base_damage * (1.0 + per_level * float(damage_level)) - eff_armor)


static func sps_milli(base_sps_milli: int, fire_rate_level: int, per_level: float, mult_milli: int) -> int:
	return roundi(float(base_sps_milli) * (1.0 + per_level * float(fire_rate_level)) * float(mult_milli) / 1000.0)


## VICTORY: base + floor(core_hp / divisor). DEFEAT: per_wave * waves_completed. Otherwise 0.
static func data_reward(result: int, waves_completed: int, core_hp: float, m: MissionDef) -> int:
	if result == RunResult.Id.VICTORY:
		return m.reward_victory_base + floori(core_hp / float(m.reward_core_hp_divisor))
	if result == RunResult.Id.DEFEAT:
		return m.reward_defeat_per_wave * waves_completed
	return 0
