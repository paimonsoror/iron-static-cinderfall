class_name VarietyValidator
extends RefCounted
## The validator rules of the variety content (VARIETY_SPEC 13.1), called by ContentValidator when `content.run` exists:
## ids that resolve and are unique, pack shares that sum to 1, a pack and a boss for every wave that needs one,
## alive caps, weights that are not all zero, ops that name real stats, kits and unlocks that reference real items,
## disjoint unlock grants, and a string for every name. The arena point rules are in VarietyArenaValidator.
## Every message reads "<file>: <JSON path>: <problem>".

const RUN: String = "run.json"
const WEAPONS: String = "weapons.json"
const ENEMIES: String = "enemies.json"
const DIRECTIVES: String = "directives.json"
const EVENTS: String = "events.json"
const UNLOCKS: String = "unlocks.json"
const STRINGS: String = "strings/variety_en.json"
const SHARE_EPSILON: float = 0.001


static func validate(e: PackedStringArray, c: ContentSet) -> void:
	_acts_and_waves(e, c)
	_packs(e, c)
	_rewards_and_modifiers(e, c)
	_numbers(e, c)
	_units(e, c)
	_directives(e, c)
	_events(e, c)
	_unlocks(e, c)
	_strings(e, c)


static func _bad(e: PackedStringArray, file: String, path: String, problem: String) -> void:
	e.append("%s: %s: %s" % [file, path, problem])


static func _all_zero(v: PackedFloat32Array) -> bool:
	for x: float in v:
		if x > 0.0:
			return false
	return true


static func _acts_and_waves(e: PackedStringArray, c: ContentSet) -> void:
	var run: RunDef = c.run
	if run.acts.is_empty():
		_bad(e, RUN, "$.acts", "at least one act is required")
	var seen: Dictionary[StringName, bool] = {}
	for a: ActDef in run.acts:
		var p: String = "$.acts[%d]" % a.index
		if seen.has(a.id):
			_bad(e, RUN, p + ".id", "duplicate id '%s'" % String(a.id))
		seen[a.id] = true
		if not a.hp_mult > 0.0 or not a.core_dmg_mult > 0.0:
			_bad(e, RUN, p, "hp_mult and core_dmg_mult must be > 0")
		if a.rarity_weights.size() != 3 or _all_zero(a.rarity_weights):
			_bad(e, RUN, p + ".rarity_weights", "needs 3 weights that are not all zero")
		if a.corrupted_chance < 0.0 or a.corrupted_chance > 1.0:
			_bad(e, RUN, p + ".corrupted_chance", "must be 0..1")
		if a.elites_min < 0 or a.elites_max < a.elites_min:
			_bad(e, RUN, p + ".elites_max", "must be >= elites_min >= 0")
		if a.affixes_min < 1 or a.affixes_max < a.affixes_min:
			_bad(e, RUN, p + ".affixes_max", "must be >= affixes_min >= 1")
	if run.waves.is_empty():
		_bad(e, RUN, "$.waves", "at least one wave is required")
	for i: int in run.waves.size():
		var w: WaveSlotDef = run.waves[i]
		var p: String = "$.waves[%d]" % i
		if w.index != i + 1:
			_bad(e, RUN, p + ".index", "waves must be listed in order 1..n (got %d at position %d)" % [w.index, i + 1])
		if w.act < 1 or w.act > run.acts.size():
			_bad(e, RUN, p + ".act", "unknown act %d" % w.act)
			continue
		if not w.budget > 0.0:
			_bad(e, RUN, p + ".budget", "must be > 0")
		if w.window_ticks < 1:
			_bad(e, RUN, p + ".window_s", "must be > 0")
		if w.peak_bodied < 0 or w.peak_minis < 0 or w.event_slots < 0:
			_bad(e, RUN, p, "peak_bodied, peak_minis and event_slots must be >= 0")
		if w.kind == WaveSlotDef.Kind.OPENER and w.fixed_pack_index < 0:
			_bad(e, RUN, p + ".fixed_pack", "an opener wave needs a fixed_pack")
		if w.kind == WaveSlotDef.Kind.BOSS:
			if not _has_boss(c, w.act):
				_bad(e, ENEMIES, "$.bosses", "no boss has pool_act %d (needed by wave %d)" % [w.act, w.index])
		elif not _has_pack(run, w.act):
			_bad(e, RUN, p, "no pack is available in act %d" % w.act)


static func _has_boss(c: ContentSet, act: int) -> bool:
	for b: BossDef in c.bosses:
		if b.pool_act == act:
			return true
	return false


static func _has_pack(run: RunDef, act: int) -> bool:
	for pack: PackDef in run.packs:
		if pack.min_act <= act:
			return true
	return false


static func _packs(e: PackedStringArray, c: ContentSet) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for pack: PackDef in c.run.packs:
		var p: String = "$.packs[%d]" % pack.index
		if seen.has(pack.id):
			_bad(e, RUN, p + ".id", "duplicate id '%s'" % String(pack.id))
		seen[pack.id] = true
		if pack.group_count() == 0:
			_bad(e, RUN, p + ".groups", "must have at least one group")
			continue
		var total: float = 0.0
		for g: int in pack.group_count():
			total += pack.group_share[g]
			if not pack.group_share[g] > 0.0:
				_bad(e, RUN, "%s.groups[%d].share" % [p, g], "must be > 0")
			if pack.group_start[g] < 0.0 or pack.group_start[g] >= 1.0:
				_bad(e, RUN, "%s.groups[%d].start" % [p, g], "must be 0 <= start < 1")
			if not pack.group_tempo[g] > 0.0:
				_bad(e, RUN, "%s.groups[%d].tempo" % [p, g], "must be > 0")
			var enemy_index: int = pack.group_enemy[g]
			if enemy_index >= 0 and enemy_index < c.enemies.size() and not c.enemies[enemy_index].cost > 0.0:
				_bad(e, RUN, "%s.groups[%d].enemy" % [p, g], "'%s' has no threat cost" % String(c.enemies[enemy_index].id))
		if absf(total - 1.0) > SHARE_EPSILON:
			_bad(e, RUN, p + ".groups", "shares must sum to 1 (got %s)" % snappedf(total, 0.0001))
		if not pack.budget_mult > 0.0 or pack.min_act < 1 or pack.extra_elites < 0:
			_bad(e, RUN, p, "budget_mult must be > 0, min_act >= 1, extra_elites >= 0")


static func _rewards_and_modifiers(e: PackedStringArray, c: ContentSet) -> void:
	var run: RunDef = c.run
	var standard: float = 0.0
	var hot: float = 0.0
	var seen: Dictionary[StringName, bool] = {}
	for w: RewardDef in run.route_rewards:
		var p: String = "$.route_rewards[%d]" % w.index
		if seen.has(w.id):
			_bad(e, RUN, p + ".id", "duplicate id '%s'" % String(w.id))
		seen[w.id] = true
		if w.weight_standard < 0.0 or w.weight_hot < 0.0:
			_bad(e, RUN, p, "weights must be >= 0")
		standard += w.weight_standard
		hot += w.weight_hot
		check_ops(e, c, RUN, p, w.ops, false)
	if not standard > 0.0:
		_bad(e, RUN, "$.route_rewards", "weight_standard is zero for every reward")
	if not hot > 0.0:
		_bad(e, RUN, "$.route_rewards", "weight_hot is zero for every reward")
	seen.clear()
	for m: ModifierDef in run.modifiers:
		var p: String = "$.modifiers[%d]" % m.index
		if seen.has(m.id):
			_bad(e, RUN, p + ".id", "duplicate id '%s'" % String(m.id))
		seen[m.id] = true
		check_ops(e, c, RUN, p, m.ops, false)


static func _numbers(e: PackedStringArray, c: ContentSet) -> void:
	var run: RunDef = c.run
	if run.draft_offer_size < 1 or run.rare_pity < 0:
		_bad(e, RUN, "$.draft", "offer_size must be >= 1 and rare_pity >= 0")
	for v: int in [run.draft_skip_scrap, run.reroll_base, run.reroll_step, run.buyout_base, run.buyout_step, run.patch_base, run.patch_step]:
		if v < 0:
			_bad(e, RUN, "$.draft", "prices must be >= 0")
			break
	if run.patch_frac < 0.0 or run.patch_frac > 1.0 or not run.tag_lean > 0.0 or not run.weapon_lean > 0.0 or not run.repeat_penalty > 0.0:
		_bad(e, RUN, "$.draft", "patch_frac must be 0..1; tag_lean, weapon_lean and repeat_penalty must be > 0")
	if run.salvage_secure_ticks < 1 or run.salvage_lifetime_ticks < 1 or not run.salvage_contest_radius_m > 0.0 or run.salvage_bank_max < 1:
		_bad(e, RUN, "$.salvage", "secure_s, lifetime_s and contest_radius_m must be > 0 and bank_max >= 1")
	if run.salvage_dupe_bias < 0.0 or run.salvage_dupe_bias > 1.0:
		_bad(e, RUN, "$.salvage.dupe_bias", "must be 0..1")
	if run.salvage_tier_weights.size() == 12:
		for row: int in 3:
			if _all_zero(run.salvage_tier_weights.slice(row * 4, row * 4 + 4)):
				_bad(e, RUN, "$.salvage.tier_weights[%d]" % row, "weights are all zero")
	else:
		_bad(e, RUN, "$.salvage.tier_weights", "expected 3 rows of 4 weights")
	if run.swarm_cap < 0 or run.max_elites_alive < 0 or run.max_blasts_per_tick < 1:
		_bad(e, RUN, "$.caps", "swarm_cap and max_elites_alive must be >= 0 and max_blasts_per_tick >= 1")
	if run.reward_per_wave < 0 or run.reward_victory_base < 0 or run.reward_victory_core_bonus < 0:
		_bad(e, RUN, "$.reward", "rewards must be >= 0")
	if c.mission.breather_ticks < 0:
		_bad(e, RUN, "$.mission.breather_seconds", "must be >= 0")
	if run.swap_ticks < 0 or run.holster_reload_mult < 0.0:
		_bad(e, WEAPONS, "$", "swap_seconds and holster_reload_mult must be >= 0")
	if not run.elite_hp_mult > 0.0 or not run.elite_scale > 0.0 or run.elite_scrap_mult < 0.0:
		_bad(e, ENEMIES, "$.elite", "hp_mult and scale must be > 0 and scrap_mult >= 0")
	if run.event_window_min < 0.0 or run.event_window_max > 1.0 or run.event_window_max < run.event_window_min:
		_bad(e, EVENTS, "$.rules", "need 0 <= window_min <= window_max <= 1")
	if run.mercy_core_frac < 0.0 or run.mercy_core_frac > 1.0:
		_bad(e, EVENTS, "$.rules.mercy_core_frac", "must be 0..1")


## alive caps, classes and the weapon additions. The legacy rules of ContentValidator already ran on every entry.
static func _units(e: PackedStringArray, c: ContentSet) -> void:
	for d: EnemyDef in c.enemies:
		var legacy: bool = d.index < Ids.LEGACY_ENEMY_COUNT
		var p: String = ("$.overrides." if legacy else "$.enemies.") + String(d.id)
		if d.alive_cap < 1:
			_bad(e, ENEMIES, p + ".alive_cap", "must be >= 1 (got %d)" % d.alive_cap)
		if d.cost < 0.0:
			_bad(e, ENEMIES, p + ".cost", "must be >= 0")
		if d.min_act < 1 or d.min_act > maxi(1, c.run.acts.size()):
			_bad(e, ENEMIES, p + ".min_act", "unknown act %d" % d.min_act)
		if d.is_mini() and c.run.swarm_cap < 1:
			_bad(e, RUN, "$.caps.swarm_cap", "must be >= 1 when a mini enemy ('%s') exists" % String(d.id))
	for w: WeaponDef in c.weapons:
		var p: String = "$.weapons." + String(w.id)
		if w.tier < 1 or w.tier > 5:
			_bad(e, WEAPONS, p + ".tier", "must be 1..5 (got %d)" % w.tier)
		if w.level_mult.size() != 3:
			_bad(e, WEAPONS, p + ".level_mult", "expected 3 numbers")
		if w.is_heat() and (w.heat_per_shot < 1 or w.cool_per_s < 0 or w.vent_ticks < 1):
			_bad(e, WEAPONS, p, "a heat weapon needs heat_per_shot >= 1, cool_per_s >= 0 and vent_s > 0")
		if w.armor_ignore < 0.0 or w.armor_ignore > 1.0 or w.stray_chance < 0.0 or w.stray_chance > 1.0:
			_bad(e, WEAPONS, p, "armor_ignore and stray_chance must be 0..1")
		if w.min_range_m < 0.0 or w.min_range_m >= w.range_m:
			_bad(e, WEAPONS, p + ".min_range_m", "must be 0 <= min_range_m < range_m")
	var seen: Dictionary[StringName, bool] = {}
	for a: AffixDef in c.affixes:
		var p: String = "$.affixes[%d]" % a.index
		if seen.has(a.id):
			_bad(e, ENEMIES, p + ".id", "duplicate id '%s'" % String(a.id))
		seen[a.id] = true
		check_ops(e, c, ENEMIES, p, a.ops, true)
	for b: BossDef in c.bosses:
		var p: String = "$.bosses." + String(b.id)
		if b.enemy_index >= 0 and b.enemy_index < c.enemies.size() and not c.enemies[b.enemy_index].is_boss:
			_bad(e, ENEMIES, p, "'%s' is not a boss enemy (is_boss is false)" % String(b.id))
		if not b.hp > 0.0:
			_bad(e, ENEMIES, p + ".hp", "must be > 0")
		if b.pool_act < 1 or b.pool_act > maxi(1, c.run.acts.size()):
			_bad(e, ENEMIES, p + ".pool_act", "unknown act %d" % b.pool_act)
		var total: float = 0.0
		for share: float in b.escort_share:
			total += share
		if b.escort_pack == &"" and absf(total - 1.0) > SHARE_EPSILON:
			_bad(e, ENEMIES, p + ".escorts", "shares must sum to 1 (got %s)" % snappedf(total, 0.0001))


static func _directives(e: PackedStringArray, c: ContentSet) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for d: DirectiveDef in c.directives:
		var p: String = "$.directives[%d]" % d.index
		if seen.has(d.id):
			_bad(e, DIRECTIVES, p + ".id", "duplicate id '%s'" % String(d.id))
		seen[d.id] = true
		if d.max_stacks < 1:
			_bad(e, DIRECTIVES, p + ".max", "must be >= 1 (got %d)" % d.max_stacks)
		if (d.rarity == DirectiveDef.Rarity.CORRUPTED) != (d.category == DirectiveDef.Category.CORRUPTED):
			_bad(e, DIRECTIVES, p, "category and rarity must both be corrupted, or neither")
		if d.pool != &"base" and c.unlock(d.pool) == null:
			_bad(e, DIRECTIVES, p + ".pool", "unknown unlock id '%s'" % String(d.pool))
		check_ops(e, c, DIRECTIVES, p, d.ops, false)
	if c.directives.is_empty():
		_bad(e, DIRECTIVES, "$.directives", "at least one directive is required")


static func _events(e: PackedStringArray, c: ContentSet) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for d: EventDef in c.events:
		var p: String = "$.events[%d]" % d.index
		if seen.has(d.id):
			_bad(e, EVENTS, p + ".id", "duplicate id '%s'" % String(d.id))
		seen[d.id] = true
		if d.warn_ticks < 0 or d.duration_ticks < 0:
			_bad(e, EVENTS, p, "warn_s and duration_s must be >= 0")
		if d.weights.size() != 3:
			_bad(e, EVENTS, p + ".weights", "expected 3 weights (one per act)")
		elif d.who == EventDef.Who.WORLD and _all_zero(d.weights):
			_bad(e, EVENTS, p + ".weights", "a world event needs a weight above zero in at least one act")


static func _unlocks(e: PackedStringArray, c: ContentSet) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var granted: Dictionary[StringName, StringName] = {}
	for u: UnlockDef in c.unlocks:
		var p: String = "$.unlocks[%d]" % u.index
		if seen.has(u.id):
			_bad(e, UNLOCKS, p + ".id", "duplicate id '%s'" % String(u.id))
		seen[u.id] = true
		if u.cost < 0 or u.tier < 1 or u.tier > c.run.tier_gates.size() + 1:
			_bad(e, UNLOCKS, p, "cost must be >= 0 and tier 1..%d" % (c.run.tier_gates.size() + 1))
		if u.grants.is_empty():
			_bad(e, UNLOCKS, p + ".grants", "must grant at least one item")
		for g: StringName in u.grants:
			if granted.has(g):
				_bad(e, UNLOCKS, p + ".grants", "'%s' is already granted by '%s'" % [String(g), String(granted[g])])
			granted[g] = u.id
			var known: bool = true
			match u.branch:
				UnlockDef.Branch.ARMORY:
					known = c.weapon(g) != null
				UnlockDef.Branch.DIRECTIVES:
					known = c.directive(g) != null
				UnlockDef.Branch.KITS:
					known = c.kit(g) != null
			if not known:
				_bad(e, UNLOCKS, p + ".grants", "unknown item '%s' for branch %s" % [String(g), UnlockDef.BRANCH_NAMES[u.branch]])
	if c.kits.is_empty() or c.kits[0].cost != 0:
		_bad(e, UNLOCKS, "$.kits", "kit 0 must exist and cost 0 (the standard kit)")
	seen.clear()
	for k: KitDef in c.kits:
		var p: String = "$.kits[%d]" % k.index
		if seen.has(k.id):
			_bad(e, UNLOCKS, p + ".id", "duplicate id '%s'" % String(k.id))
		seen[k.id] = true
		if k.cost < 0:
			_bad(e, UNLOCKS, p + ".cost", "must be >= 0")
		check_ops(e, c, UNLOCKS, p, k.ops, false)
	for i: int in c.run.tier_gates.size():
		if c.run.tier_gates[i] < 0 or (i > 0 and c.run.tier_gates[i] < c.run.tier_gates[i - 1]):
			_bad(e, UNLOCKS, "$.tier_gates", "gates must be >= 0 and not decrease")
			break
	for id: StringName in c.run.milestones:
		if c.run.milestones[id] < 0:
			_bad(e, UNLOCKS, "$.milestones", "'%s' must pay >= 0" % String(id))


## Every op names a real stat, flag or grant, and a grant id resolves. `affix` selects the per-enemy name lists.
static func check_ops(e: PackedStringArray, c: ContentSet, file: String, path: String, ops: Array[OpDef], affix: bool) -> void:
	var stats: PackedStringArray = OpDef.AFFIX_STATS if affix else OpDef.STATS
	var flags: PackedStringArray = OpDef.AFFIX_FLAGS if affix else OpDef.FLAGS
	for i: int in ops.size():
		var op: OpDef = ops[i]
		var p: String = "%s.ops[%d]" % [path, i]
		var target: String = String(op.target)
		match op.kind:
			OpDef.Kind.ADD, OpDef.Kind.MUL:
				if not stats.has(target):
					_bad(e, file, p + ".stat", "unknown stat '%s'" % target)
				if not is_finite(op.value):
					_bad(e, file, p, "not a finite number")
			OpDef.Kind.FLAG:
				if not flags.has(target):
					_bad(e, file, p + ".flag", "unknown flag '%s'" % target)
			OpDef.Kind.GRANT:
				if affix or not OpDef.GRANTS.has(target):
					_bad(e, file, p + ".grant", "unknown grant '%s'" % target)
					continue
				var known: bool = true
				match target:
					"weapon":
						known = c.weapon(op.arg) != null
					"event_charge":
						known = c.event_def(op.arg) != null
					"directive":
						known = c.directive(op.arg) != null
					"directive_random":
						known = DirectiveDef.RARITY_NAMES.has(String(op.arg))
				if not known:
					_bad(e, file, p + ".id", "unknown id '%s' for grant '%s'" % [String(op.arg), target])


## Every name the UI shows must resolve through Strings.t.
static func _strings(e: PackedStringArray, c: ContentSet) -> void:
	var needs: Dictionary[String, String] = {}
	for a: ActDef in c.run.acts:
		needs[a.name_key] = "$.acts[%d]" % a.index
	for pack: PackDef in c.run.packs:
		needs[pack.name_key] = "$.packs[%d]" % pack.index
	for m: ModifierDef in c.run.modifiers:
		needs[m.name_key] = "$.modifiers[%d]" % m.index
	for w: RewardDef in c.run.route_rewards:
		needs[w.name_key] = "$.route_rewards[%d]" % w.index
	for d: DirectiveDef in c.directives:
		needs[d.name_key] = "$.directives[%d]" % d.index
		needs[d.desc_key] = "$.directives[%d]" % d.index
	for d: EventDef in c.events:
		needs[d.name_key] = "$.events[%d]" % d.index
	for a: AffixDef in c.affixes:
		needs[a.name_key] = "$.affixes[%d]" % a.index
	for b: BossDef in c.bosses:
		needs[b.name_key] = "$.bosses." + String(b.id)
	for k: KitDef in c.kits:
		needs[k.name_key] = "$.kits[%d]" % k.index
	for key: String in needs:
		if not c.strings.has(key):
			_bad(e, STRINGS, "$." + key, "missing string (needed by %s)" % needs[key])
