class_name VarietyRunLoader
extends RefCounted
## data/run.json to RunDef (acts, wave slots, packs, modifiers, route rewards, draft, salvage, caps, reward) and the
## three MissionDef additions (swarm_cap, breather_ticks, shop_enabled). VARIETY_SPEC 13.1, CONTENT 1, 3.7, 7, 10.


static func run(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	var run_def: RunDef = cs.run
	_acts(r, d, run_def)
	_packs(r, d, run_def, cs)
	_waves(r, d, run_def)
	for row: Dictionary in OpReader.rows(r, d, "modifiers", "$"):
		var p: String = "$.modifiers[%d]" % run_def.modifiers.size()
		r.check_keys(row, PackedStringArray(["id", "name_key", "list", "ops"]), p)
		var m: ModifierDef = ModifierDef.new()
		m.id = StringName(r.text(row, "id", p))
		m.index = run_def.modifiers.size()
		m.name_key = r.text(row, "name_key", p)
		m.list = OpReader.enum_index(r, row, "list", p, ModifierDef.LIST_NAMES)
		m.ops = OpReader.ops(r, row, "ops", p)
		run_def.modifiers.append(m)
	for row: Dictionary in OpReader.rows(r, d, "route_rewards", "$"):
		var p: String = "$.route_rewards[%d]" % run_def.route_rewards.size()
		r.check_keys(row, PackedStringArray(["id", "name_key", "weight_standard", "weight_hot", "ops"]), p)
		var w: RewardDef = RewardDef.new()
		w.id = StringName(r.text(row, "id", p))
		w.index = run_def.route_rewards.size()
		w.name_key = r.text(row, "name_key", p)
		w.weight_standard = r.num(row, "weight_standard", p)
		w.weight_hot = r.num(row, "weight_hot", p)
		w.ops = OpReader.ops(r, row, "ops", p)
		run_def.route_rewards.append(w)
	_draft(r, r.dict(d, "draft", "$"), run_def)
	_salvage(r, r.dict(d, "salvage", "$"), run_def)
	var caps: Dictionary = r.dict(d, "caps", "$")
	r.check_keys(caps, PackedStringArray(["swarm_cap", "max_elites_alive", "max_blasts_per_tick"]), "$.caps")
	run_def.swarm_cap = r.integer(caps, "swarm_cap", "$.caps")
	run_def.max_elites_alive = r.integer(caps, "max_elites_alive", "$.caps")
	run_def.max_blasts_per_tick = r.integer(caps, "max_blasts_per_tick", "$.caps")
	var reward: Dictionary = r.dict(d, "reward", "$")
	r.check_keys(reward, PackedStringArray(["per_wave", "boss_by_act", "victory_base", "victory_core_bonus"]), "$.reward")
	run_def.reward_per_wave = r.integer(reward, "per_wave", "$.reward")
	run_def.reward_boss_by_act = OpReader.ints(r, reward, "boss_by_act", "$.reward", -1)
	run_def.reward_victory_base = r.integer(reward, "victory_base", "$.reward")
	run_def.reward_victory_core_bonus = r.integer(reward, "victory_core_bonus", "$.reward")
	var mission: Dictionary = r.dict(d, "mission", "$")
	r.check_keys(mission, PackedStringArray(["shop_enabled", "breather_seconds"]), "$.mission")
	cs.mission.shop_enabled = r.flag(mission, "shop_enabled", "$.mission")
	cs.mission.breather_ticks = OpReader.ticks(r.num(mission, "breather_seconds", "$.mission"))
	cs.mission.swarm_cap = run_def.swarm_cap


static func _acts(r: JsonRead, d: Dictionary, run_def: RunDef) -> void:
	for row: Dictionary in OpReader.rows(r, d, "acts", "$"):
		var p: String = "$.acts[%d]" % run_def.acts.size()
		r.check_keys(row, PackedStringArray([
			"id", "name_key", "hp_mult", "core_dmg_mult", "rarity_weights", "corrupted_chance", "elites_min", "elites_max",
			"affixes_min", "affixes_max",
		]), p)
		var a: ActDef = ActDef.new()
		a.id = StringName(r.text(row, "id", p))
		a.index = run_def.acts.size()
		a.name_key = r.text(row, "name_key", p)
		a.hp_mult = r.num(row, "hp_mult", p)
		a.core_dmg_mult = r.num(row, "core_dmg_mult", p)
		a.rarity_weights = OpReader.floats(r, row, "rarity_weights", p, 3)
		a.corrupted_chance = r.num(row, "corrupted_chance", p)
		a.elites_min = r.integer(row, "elites_min", p)
		a.elites_max = r.integer(row, "elites_max", p)
		a.affixes_min = r.integer(row, "affixes_min", p)
		a.affixes_max = r.integer(row, "affixes_max", p)
		run_def.acts.append(a)


static func _packs(r: JsonRead, d: Dictionary, run_def: RunDef, cs: ContentSet) -> void:
	for row: Dictionary in OpReader.rows(r, d, "packs", "$"):
		var p: String = "$.packs[%d]" % run_def.packs.size()
		r.check_keys(row, PackedStringArray(["id", "name_key", "min_act", "budget_mult", "extra_elites", "groups"]), p)
		var pack: PackDef = PackDef.new()
		pack.id = StringName(r.text(row, "id", p))
		pack.index = run_def.packs.size()
		pack.name_key = r.text(row, "name_key", p)
		pack.min_act = r.integer(row, "min_act", p)
		pack.budget_mult = r.num(row, "budget_mult", p)
		pack.extra_elites = r.integer(row, "extra_elites", p)
		var groups: Array[Dictionary] = OpReader.rows(r, row, "groups", p)
		for g: int in groups.size():
			var pg: String = "%s.groups[%d]" % [p, g]
			r.check_keys(groups[g], ["enemy", "share", "region", "start", "tempo"], pg)
			pack.group_enemy.append(OpReader.enemy(r, groups[g], "enemy", pg))
			pack.group_share.append(r.num(groups[g], "share", pg))
			var region: StringName = StringName(r.text(groups[g], "region", pg))
			if region != &"breach" and cs.arena != null and cs.arena.region(region) == null:
				r.fail(pg + ".region", "unknown spawn region '%s'" % String(region))
			pack.group_region.append(region)
			pack.group_start.append(r.num(groups[g], "start", pg))
			pack.group_tempo.append(r.num(groups[g], "tempo", pg))
		run_def.packs.append(pack)


static func _waves(r: JsonRead, d: Dictionary, run_def: RunDef) -> void:
	for row: Dictionary in OpReader.rows(r, d, "waves", "$"):
		var p: String = "$.waves[%d]" % run_def.waves.size()
		r.check_keys(row, PackedStringArray([
			"index", "act", "kind", "budget", "window_s", "peak_bodied", "peak_minis", "event_slots", "fixed_pack",
		]), p)
		var w: WaveSlotDef = WaveSlotDef.new()
		w.index = r.integer(row, "index", p)
		w.act = r.integer(row, "act", p)
		w.kind = OpReader.enum_index(r, row, "kind", p, WaveSlotDef.KIND_NAMES)
		w.budget = r.num(row, "budget", p)
		w.window_ticks = OpReader.ticks(r.num(row, "window_s", p))
		w.peak_bodied = r.integer(row, "peak_bodied", p)
		w.peak_minis = r.integer(row, "peak_minis", p)
		w.event_slots = r.integer(row, "event_slots", p)
		w.fixed_pack = StringName(r.text_or(row, "fixed_pack", p, ""))
		if w.fixed_pack != &"":
			w.fixed_pack_index = run_def.pack_index(w.fixed_pack)
			if w.fixed_pack_index < 0:
				r.fail(p + ".fixed_pack", "unknown pack id '%s'" % String(w.fixed_pack))
		run_def.waves.append(w)


static func _draft(r: JsonRead, dd: Dictionary, run_def: RunDef) -> void:
	var p: String = "$.draft"
	r.check_keys(dd, PackedStringArray([
		"offer_size", "skip_scrap", "reroll_base", "reroll_step", "buyout_base", "buyout_step", "patch_frac", "patch_base",
		"patch_step", "tag_lean", "weapon_lean", "repeat_penalty", "rare_pity",
	]), p)
	run_def.draft_offer_size = r.integer(dd, "offer_size", p)
	run_def.draft_skip_scrap = r.integer(dd, "skip_scrap", p)
	run_def.reroll_base = r.integer(dd, "reroll_base", p)
	run_def.reroll_step = r.integer(dd, "reroll_step", p)
	run_def.buyout_base = r.integer(dd, "buyout_base", p)
	run_def.buyout_step = r.integer(dd, "buyout_step", p)
	run_def.patch_frac = r.num(dd, "patch_frac", p)
	run_def.patch_base = r.integer(dd, "patch_base", p)
	run_def.patch_step = r.integer(dd, "patch_step", p)
	run_def.tag_lean = r.num(dd, "tag_lean", p)
	run_def.weapon_lean = r.num(dd, "weapon_lean", p)
	run_def.repeat_penalty = r.num(dd, "repeat_penalty", p)
	run_def.rare_pity = r.integer(dd, "rare_pity", p)


static func _salvage(r: JsonRead, sd: Dictionary, run_def: RunDef) -> void:
	var p: String = "$.salvage"
	r.check_keys(sd, PackedStringArray([
		"secure_s", "contest_radius_m", "lifetime_s", "bank_max", "scrap_by_act", "tier_weights", "dupe_bias",
	]), p)
	run_def.salvage_secure_ticks = OpReader.ticks(r.num(sd, "secure_s", p))
	run_def.salvage_contest_radius_m = r.num(sd, "contest_radius_m", p)
	run_def.salvage_lifetime_ticks = OpReader.ticks(r.num(sd, "lifetime_s", p))
	run_def.salvage_bank_max = r.integer(sd, "bank_max", p)
	run_def.salvage_scrap_by_act = OpReader.ints(r, sd, "scrap_by_act", p, 3)
	run_def.salvage_dupe_bias = r.num(sd, "dupe_bias", p)
	var table: Array = r.list(sd, "tier_weights", p)
	if table.size() != 3 and sd.has("tier_weights"):
		r.fail(p + ".tier_weights", "expected 3 rows (one per act), got %d" % table.size())
	for row_i: int in table.size():
		var pr: String = "%s.tier_weights[%d]" % [p, row_i]
		if typeof(table[row_i]) != TYPE_ARRAY:
			r.fail(pr, "not an array")
			continue
		var row: Array = table[row_i]
		if row.size() != 4:
			r.fail(pr, "expected 4 numbers (tier 2 to 5), got %d" % row.size())
			continue
		for col: int in 4:
			run_def.salvage_tier_weights.append(r.as_num(row[col], "%s[%d]" % [pr, col]))
