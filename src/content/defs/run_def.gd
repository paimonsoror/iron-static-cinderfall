class_name RunDef
extends RefCounted
## The generated-run rules (data/run.json plus the run-wide parts of weapons, enemies, events and unlocks .json;
## VARIETY_SPEC 13.1, CONTENT 1, 3.7, 7, 10). Null in the legacy 5-wave content.

var acts: Array[ActDef] = []
var waves: Array[WaveSlotDef] = []  ## index 0 = wave 1
var packs: Array[PackDef] = []
var modifiers: Array[ModifierDef] = []
var route_rewards: Array[RewardDef] = []
# draft {}
var draft_offer_size: int = 3
var draft_skip_scrap: int = 0
var reroll_base: int = 0
var reroll_step: int = 0
var buyout_base: int = 0
var buyout_step: int = 0
var patch_frac: float = 0.0
var patch_base: int = 0
var patch_step: int = 0
var tag_lean: float = 1.0
var weapon_lean: float = 1.0
var repeat_penalty: float = 1.0
var rare_pity: int = 0
# salvage {}
var salvage_secure_ticks: int = 0
var salvage_contest_radius_m: float = 0.0
var salvage_lifetime_ticks: int = 0
var salvage_bank_max: int = 0
var salvage_scrap_by_act: PackedInt32Array = PackedInt32Array()
var salvage_tier_weights: PackedFloat32Array = PackedFloat32Array()  ## 3 rows (act) x 4 columns (tier 2..5), row-major
var salvage_dupe_bias: float = 0.0
# caps {}
var swarm_cap: int = 0
var max_elites_alive: int = 0
var max_blasts_per_tick: int = 8
# reward {}
var reward_per_wave: int = 0
var reward_boss_by_act: PackedInt32Array = PackedInt32Array()
var reward_victory_base: int = 0
var reward_victory_core_bonus: int = 0
# weapons.json top level
var swap_ticks: int = 0
var holster_reload_mult: float = 1.0
# enemies.json: elite {}, affix_rules {}, hulk_variants []
var elite_hp_mult: float = 1.0
var elite_scale: float = 1.0
var elite_scrap_mult: float = 1.0
var forbid_a: PackedInt32Array = PackedInt32Array()  ## affix index pairs that may not combine
var forbid_b: PackedInt32Array = PackedInt32Array()
var forbid_until_act: PackedInt32Array = PackedInt32Array()  ## 0 = always forbidden, else forbidden while act < value
var forbid_enemy: PackedInt32Array = PackedInt32Array()  ## -1 = on any enemy, else only on this enemy index
var affix_two_chance: PackedFloat32Array = PackedFloat32Array()  ## per act: the chance of a second affix
var hulk_variants: Array[StringName] = []
# events.json: rules {}, hazards {}
var event_window_min: float = 0.0  ## fraction of the wave window
var event_window_max: float = 1.0
var mercy_core_frac: float = 0.0
var hazards: Dictionary[StringName, Dictionary] = {}  ## hazard id -> { field: number }
# unlocks.json: tier_gates [], milestones []
var tier_gates: PackedInt32Array = PackedInt32Array()  ## unlocks needed to open tier 2, tier 3, ...
var milestones: Dictionary[StringName, int] = {}  ## milestone id -> Recovered Data


func act(act_number: int) -> ActDef:
	if act_number < 1 or act_number > acts.size():
		return null
	return acts[act_number - 1]


## The slot of wave `wave_number` (1-based), or null.
func wave_slot(wave_number: int) -> WaveSlotDef:
	if wave_number < 1 or wave_number > waves.size():
		return null
	return waves[wave_number - 1]


func pack_index(id: StringName) -> int:
	for d: PackDef in packs:
		if d.id == id:
			return d.index
	return -1


func modifier_index(id: StringName) -> int:
	for d: ModifierDef in modifiers:
		if d.id == id:
			return d.index
	return -1


func reward_index(id: StringName) -> int:
	for d: RewardDef in route_rewards:
		if d.id == id:
			return d.index
	return -1


## Weight of weapon tier `tier` (2..5) in crates of act `act_number` (1..3); 0 outside the table.
func tier_weight(act_number: int, tier: int) -> float:
	var i: int = (act_number - 1) * 4 + (tier - 2)
	if act_number < 1 or tier < 2 or tier > 5 or i >= salvage_tier_weights.size():
		return 0.0
	return salvage_tier_weights[i]
