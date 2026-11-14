extends GdUnitTestSuite
## V4-C: the 12 threat packs (CONTENT 1.3), the 10 wave modifiers (CONTENT 1.4) and the 8 route rewards (CONTENT 1.2) of
## data/run.json on the frozen variety fixture: the tables, what the wave builder makes of every pack in every act, and the
## exact effect of every modifier.

## id, min_act, budget_mult, extra_elites, then the groups as "enemy:share:region:start:tempo".
const PACKS: Array[Array] = [
	[&"pack_tide", 1, 1.0, 0, ["skitter:0.70:right:0.00:1.00", "mote:0.30:upper_right:0.20:0.50"]],
	[&"pack_column", 1, 1.0, 0, ["hollow_warden:0.55:upper_right:0.10:1.00", "skitter:0.45:right:0.00:1.00"]],
	[&"pack_powder", 1, 1.0, 0, ["burster:0.35:right:0.15:1.00", "skitter:0.45:right:0.00:0.80", "mote:0.20:upper_right:0.30:0.50"]],
	[&"pack_breach", 1, 1.0, 0, ["rusher:0.50:upper_right:0.25:0.80", "skitter:0.50:right:0.00:1.00"]],
	[&"pack_battery", 1, 1.0, 0, ["spitter:0.35:upper_right:0.20:1.00", "hollow_warden:0.25:right:0.10:1.00", "skitter:0.40:right:0.00:1.00"]],
	[&"pack_brood", 2, 1.0, 0, ["splitter:0.45:right:0.10:1.00", "mote:0.25:upper_right:0.00:0.50", "skitter:0.30:right:0.30:1.00"]],
	[&"pack_bulwark", 2, 1.0, 0, ["shieldbearer:0.30:right:0.10:1.00", "hollow_warden:0.30:right:0.15:1.00", "rusher:0.40:upper_right:0.40:0.80"]],
	[&"pack_repair", 2, 1.0, 0, ["reclaimer:0.15:upper_right:0.00:1.00", "hollow_warden:0.45:right:0.10:1.00", "rusher:0.40:upper_right:0.30:0.80"]],
	[&"pack_static", 2, 1.0, 0, ["jammer:0.20:upper_right:0.10:1.00", "rusher:0.35:right:0.30:0.80", "skitter:0.45:right:0.00:1.00"]],
	[&"pack_undermine", 2, 1.0, 0, ["borer:0.40:breach:0.30:0.60", "skitter:0.40:right:0.00:1.00", "burster:0.20:upper_right:0.20:1.00"]],
	[&"pack_everything", 3, 1.0, 0, [
		"skitter:0.25:right:0.00:1.00", "rusher:0.15:upper_right:0.05:1.00", "hollow_warden:0.15:right:0.10:1.00",
		"burster:0.15:right:0.15:1.00", "spitter:0.10:upper_right:0.20:1.00", "splitter:0.10:right:0.30:1.00",
		"mote:0.10:upper_right:0.40:1.00",
	]],
	[&"pack_hunt", 2, 0.7, 2, ["hollow_warden:0.50:right:0.00:1.00", "rusher:0.50:upper_right:0.20:1.00"]],
]
## id, list, then the ops: ["stat", "add" | "mul", value] or ["flag", name].
const MODIFIERS: Array[Array] = [
	[&"mod_volatile", &"hot", [["flag", "volatile_skitters"], ["volatile_radius", "add", 1.2], ["volatile_damage", "add", 20.0]]],
	[&"mod_plated", &"mild", [["enemy_armor_add", "add", 4.0]]],
	[&"mod_rush", &"mild", [["spawn_interval_mul", "mul", 0.6]]],
	[&"mod_twin_gate", &"mild", [["flag", "twin_gate"]]],
	[&"mod_bounty", &"mild", [["scrap_mul", "mul", 1.5], ["enemy_hp_mul", "mul", 1.2]]],
	[&"mod_squall", &"hot", [["range_mul", "mul", 0.7]]],
	[&"mod_static_air", &"hot", [["ability_cd_rate_mul", "mul", 0.5]]],
	[&"mod_low_power", &"hot", [["turret_offline_ticks", "add", 720.0]]],
	[&"mod_elite_pair", &"hot", [["extra_elites", "add", 2.0]]],
	[&"mod_no_breather", &"hot", [["flag", "no_breather"]]],
]

var c: ContentSet


func before_test() -> void:
	c = VarietyAKit.long_content()


func _group_text(p: PackDef, g: int) -> String:
	return "%s:%.2f:%s:%.2f:%.2f" % [
		String(Ids.ENEMIES[p.group_enemy[g]]), p.group_share[g], String(p.group_region[g]), p.group_start[g], p.group_tempo[g]
	]


func _check_op(op: OpDef, want: Array, who: String) -> void:
	var head: String = want[0]
	if head == "flag":
		var flag_name: String = want[1]
		assert_int(op.kind).override_failure_message(who).is_equal(OpDef.Kind.FLAG)
		assert_str(String(op.target)).override_failure_message(who).is_equal(flag_name)
		return
	var how: String = want[1]
	var value: float = want[2]
	assert_str(String(op.target)).override_failure_message(who).is_equal(head)
	assert_int(op.kind).override_failure_message(who).is_equal(OpDef.Kind.ADD if how == "add" else OpDef.Kind.MUL)
	assert_float(op.value).override_failure_message(who).is_equal_approx(value, 0.00001)


func _world_with_modifier(id: StringName) -> SimWorld:
	var w: SimWorld = DirectiveKit.world()
	ModSystem.set_wave_modifier(w, w.content.run.modifier_index(id))
	return w


func test_the_twelve_packs_are_those_of_content_1_3() -> void:
	assert_int(c.run.packs.size()).is_equal(PACKS.size())
	for n: int in PACKS.size():
		var row: Array = PACKS[n]
		var want_id: StringName = row[0]
		var want_act: int = row[1]
		var want_mult: float = row[2]
		var want_elites: int = row[3]
		var groups: Array = row[4]
		var p: PackDef = c.run.packs[n]
		assert_str(String(p.id)).is_equal(String(want_id))
		assert_int(p.min_act).override_failure_message(String(p.id)).is_equal(want_act)
		assert_float(p.budget_mult).override_failure_message(String(p.id)).is_equal_approx(want_mult, 0.00001)
		assert_int(p.extra_elites).override_failure_message(String(p.id)).is_equal(want_elites)
		assert_int(p.group_count()).override_failure_message(String(p.id)).is_equal(groups.size())
		var shares: float = 0.0
		for g: int in groups.size():
			assert_str(_group_text(p, g)).override_failure_message(String(p.id)).is_equal(groups[g])
			shares += p.group_share[g]
		assert_float(shares).override_failure_message(String(p.id)).is_equal_approx(1.0, 0.0001)
		assert_str(p.name_key).is_equal("pack.%s.name" % String(p.id).trim_prefix("pack_"))


func test_the_three_slice_packs_keep_their_index_and_act_one_has_five_packs() -> void:
	assert_int(c.run.pack_index(&"pack_tide")).is_equal(0)
	assert_int(c.run.pack_index(&"pack_column")).is_equal(1)
	assert_int(c.run.pack_index(&"pack_powder")).is_equal(2)
	var act1: int = 0
	var act2: int = 0
	var act3: int = 0
	for p: PackDef in c.run.packs:
		act1 += 1 if p.min_act <= 1 else 0
		act2 += 1 if p.min_act <= 2 else 0
		act3 += 1 if p.min_act <= 3 else 0
	assert_array([act1, act2, act3]).is_equal([5, 11, 12])


func test_a_pack_never_brings_a_type_before_its_act() -> void:
	for slot_wave: int in [3, 7, 13]:  # one normal wave of each act
		var slot: WaveSlotDef = c.run.wave_slot(slot_wave)
		for p: PackDef in c.run.packs:
			if p.min_act > slot.act:
				continue
			var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, slot, p.index, 1.0, PlanRng.stream(4, &"plan.wave:packs"))
			for g: SpawnGroupDef in groups:
				var def: EnemyDef = c.enemies[g.enemy_index]
				assert_int(def.min_act).override_failure_message("%s in act %d: %s" % [String(p.id), slot.act, String(def.id)]).is_less_equal(slot.act)
				assert_int(g.count).is_greater_equal(1)


func test_in_act_one_the_act_two_specialists_become_skitters() -> void:
	var slot: WaveSlotDef = c.run.wave_slot(3)
	for id: StringName in [&"pack_brood", &"pack_bulwark", &"pack_repair", &"pack_static", &"pack_undermine"]:
		var pack: int = c.run.pack_index(id)
		assert_int(c.run.packs[pack].min_act).is_equal(2)
		var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, slot, pack, 1.0, PlanRng.stream(4, &"plan.wave:packs"))
		for g: SpawnGroupDef in groups:
			var specialists: Array[int] = [Ids.EN_SPLITTER, Ids.EN_SHIELDBEARER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_BORER]
			assert_bool(specialists.has(g.enemy_index)).override_failure_message(String(id)).is_false()


func test_every_pack_spends_its_budget_within_ten_percent_in_every_act() -> void:
	for slot_wave: int in [3, 7, 13]:
		var slot: WaveSlotDef = c.run.wave_slot(slot_wave)
		for p: PackDef in c.run.packs:
			if p.min_act > slot.act:
				continue
			for s: int in range(1, 9):
				var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, slot, p.index, 1.0, PlanRng.stream(s, &"plan.wave:packs"))
				var target: float = slot.budget * p.budget_mult
				var off: float = absf(VarietyAKit.spent(c, groups) - target) / target
				assert_float(off).override_failure_message("%s wave %d seed %d: %.3f off" % [String(p.id), slot_wave, s, off]).is_less_equal(0.1)


func test_pack_hunt_is_a_smaller_wave_with_two_more_elites() -> void:
	var hunt: PackDef = c.run.packs[c.run.pack_index(&"pack_hunt")]
	var slot: WaveSlotDef = c.run.wave_slot(7)  # budget 92
	var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, slot, hunt.index, 1.0, PlanRng.stream(2, &"plan.wave:packs"))
	var spent: float = VarietyAKit.spent(c, groups)
	assert_float(spent).is_between(92.0 * 0.7 * 0.9, 92.0 * 0.7 * 1.1)
	var option: RouteOption = RouteOption.new()
	option.pack_index = hunt.index
	assert_int(RunPlanSystem._extra_elites(c, option)).is_equal(2)


func test_the_borer_group_of_pack_undermine_comes_from_a_breach_point() -> void:
	var pack: PackDef = c.run.packs[c.run.pack_index(&"pack_undermine")]
	assert_str(String(pack.group_region[0])).is_equal("breach")
	assert_int(pack.group_enemy[0]).is_equal(Ids.EN_BORER)


func test_the_ten_modifiers_are_those_of_content_1_4() -> void:
	assert_int(c.run.modifiers.size()).is_equal(MODIFIERS.size())
	var mild: int = 0
	var hot: int = 0
	for n: int in MODIFIERS.size():
		var row: Array = MODIFIERS[n]
		var want_id: StringName = row[0]
		var want_list: StringName = row[1]
		var ops: Array = row[2]
		var m: ModifierDef = c.run.modifiers[n]
		assert_str(String(m.id)).is_equal(String(want_id))
		assert_str(ModifierDef.LIST_NAMES[m.list]).override_failure_message(String(m.id)).is_equal(String(want_list))
		assert_int(m.ops.size()).override_failure_message(String(m.id)).is_equal(ops.size())
		for k: int in ops.size():
			var want_op: Array = ops[k]
			_check_op(m.ops[k], want_op, "%s op %d" % [String(m.id), k])
		mild += 1 if m.list == ModifierDef.List.MILD else 0
		hot += 1 if m.list == ModifierDef.List.HOT else 0
	assert_array([mild, hot]).is_equal([4, 6])


func test_the_eight_route_rewards_and_their_weights() -> void:
	var standard: Array[float] = []
	var hot: Array[float] = []
	var ids: Array[StringName] = []
	for r: RewardDef in c.run.route_rewards:
		ids.append(r.id)
		standard.append(r.weight_standard)
		hot.append(r.weight_hot)
	assert_array(ids).is_equal([&"rw_scrap", &"rw_patch", &"rw_reroll", &"rw_crate", &"rw_rare_draft", &"rw_charge", &"rw_double_pick", &"rw_data"])
	assert_array(standard).is_equal([30.0, 20.0, 20.0, 20.0, 10.0, 0.0, 0.0, 0.0])
	assert_array(hot).is_equal([10.0, 10.0, 5.0, 25.0, 20.0, 10.0, 12.0, 8.0])


func test_a_modifier_changes_exactly_the_stats_it_names() -> void:
	for m: ModifierDef in c.run.modifiers:
		var w: SimWorld = DirectiveKit.world()
		ModSystem.set_wave_modifier(w, m.index)
		var named: Dictionary[String, bool] = {}
		for op: OpDef in m.ops:
			if op.kind == OpDef.Kind.ADD or op.kind == OpDef.Kind.MUL:
				named[String(op.target)] = true
		for stat_name: String in OpDef.STATS:
			var changed: bool = w.mods.stat(StringName(stat_name)) != ModState.default_of(stat_name)
			assert_bool(changed).override_failure_message("%s: %s" % [String(m.id), stat_name]).is_equal(named.has(stat_name))
		ModSystem.set_wave_modifier(w, -1)  # leaving the wave restores the neutral state
		for stat_name: String in OpDef.STATS:
			assert_float(w.mods.stat(StringName(stat_name))).is_equal(ModState.default_of(stat_name))


func test_mod_plated_adds_4_armor_to_every_enemy() -> void:
	var w: SimWorld = _world_with_modifier(&"mod_plated")
	assert_float(w.mods.enemy_armor_add).is_equal(4.0)
	var hollow: int = DirectiveKit.place(w, Ids.EN_HOLLOW, 0.0, 0.0)  # armor 8
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, 0, DamageSource.Id.WARDEN)).is_equal(18.0)  # 30 - 12
	var skitter: int = DirectiveKit.place(w, Ids.EN_SKITTER, 1.0, 0.0)
	assert_float(DamageResolver.hit_ex(w, skitter, 30.0, 0, DamageSource.Id.WARDEN)).is_equal(26.0)  # 30 - 4


func test_mod_rush_scales_every_interval_by_0_6() -> void:
	var groups: Array[SpawnGroupDef] = [
		VarietyAKit.group(Ids.EN_SKITTER, 10, 0, 100, &"right"), VarietyAKit.group(Ids.EN_RUSHER, 4, 30, 1, &"right"),
	]
	WaveBuilder.apply_modifier(c, groups, c.run.modifier_index(&"mod_rush"))
	assert_int(groups[0].interval_ticks).is_equal(60)
	assert_int(groups[1].interval_ticks).is_equal(1)  # never below one tick


func test_mod_twin_gate_splits_the_right_edge_groups_over_two_edges() -> void:
	var groups: Array[SpawnGroupDef] = [
		VarietyAKit.group(Ids.EN_SKITTER, 5, 10, 40, &"right"), VarietyAKit.group(Ids.EN_MOTE, 4, 0, 20, &"upper_right"),
	]
	WaveBuilder.apply_modifier(c, groups, c.run.modifier_index(&"mod_twin_gate"))
	assert_int(groups.size()).is_equal(3)
	assert_array([groups[0].count, groups[0].interval_ticks, String(groups[0].region_id)]).is_equal([3, 80, "right"])
	assert_array([groups[1].count, groups[1].interval_ticks, String(groups[1].region_id), groups[1].start_tick]).is_equal([2, 80, "upper_right", 10])
	assert_array([groups[2].count, groups[2].interval_ticks]).is_equal([4, 20])  # the upper-right group stays


func test_mod_bounty_multiplies_scrap_and_hp_after_the_directives() -> void:
	var w: SimWorld = DirectiveKit.world()
	DirectiveKit.give(w, &"scavenger_protocol")
	ModSystem.set_wave_modifier(w, w.content.run.modifier_index(&"mod_bounty"))
	assert_float(w.mods.scrap_mul).is_equal_approx(1.875, 0.00001)  # (1 + 0.25) x 1.5
	assert_float(w.mods.enemy_hp_mul).is_equal_approx(1.2, 0.00001)
	var skitter: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(9)  # 5 x 1.875 = 9.375


func test_mod_volatile_skitters_blast_on_death() -> void:
	var w: SimWorld = _world_with_modifier(&"mod_volatile")
	assert_bool(w.mods.has_flag(&"volatile_skitters")).is_true()
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(w.hazards.queued()).is_equal(1)
	assert_float(w.hazards.q_radius[0]).is_equal_approx(1.2, 0.00001)
	assert_float(w.hazards.q_damage[0]).is_equal(20.0)


func test_mod_squall_shortens_the_range_and_mod_static_air_halves_the_cooldown_rate() -> void:
	var squall: SimWorld = _world_with_modifier(&"mod_squall")
	assert_float(ArsenalSystem.range_of(squall, squall.content.weapons[Ids.WP_PISTOL])).is_equal_approx(17.5, 0.00001)  # 25 x 0.7
	var air: SimWorld = _world_with_modifier(&"mod_static_air")
	assert_float(air.mods.ability_cd_rate_mul).is_equal_approx(0.5, 0.00001)


func test_mod_low_power_takes_the_turrets_offline_for_12_seconds_at_the_wave_start() -> void:
	var w: SimWorld = _world_with_modifier(&"mod_low_power")
	assert_float(w.mods.turret_offline_ticks).is_equal(720.0)
	assert_int(w.events_state.turret_offline_ticks).is_equal(720)
	w.events_state.turret_offline_ticks = 1000  # a longer brownout is never shortened
	ModSystem.set_wave_modifier(w, w.content.run.modifier_index(&"mod_low_power"))
	assert_int(w.events_state.turret_offline_ticks).is_equal(1000)
	ModSystem.set_wave_modifier(w, -1)
	assert_float(w.mods.turret_offline_ticks).is_equal(0.0)


func test_mod_elite_pair_adds_two_elites_to_its_option() -> void:
	var w: SimWorld = _world_with_modifier(&"mod_elite_pair")
	assert_float(w.mods.extra_elites).is_equal(2.0)
	var option: RouteOption = RouteOption.new()
	option.modifier_index = c.run.modifier_index(&"mod_elite_pair")
	assert_int(RunPlanSystem._extra_elites(c, option)).is_equal(2)


func test_mod_no_breather_locks_the_reroll_and_the_patch_of_the_next_draft() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(TestContent.variety())
	ModSystem.set_wave_modifier(w, w.content.run.modifier_index(&"mod_no_breather"))
	assert_bool(w.mods.has_flag(&"no_breather")).is_true()
	VarietyBKit.open_draft(w)
	assert_bool(w.draft.reroll_locked).is_true()
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(DraftSystem.patch_core(w, 2)).is_equal(Reason.Id.LOCKED_BY_EVENT)


## Pinned from the first run on the full fixture: [pack, modifier, reward of A, pack, modifier, reward of B] for waves 2 to 4.
func test_golden_plan_of_seeds_1_to_3_on_the_full_pool() -> void:
	var got: Array = []
	for s: int in [1, 2, 3]:
		var plan: RunPlan = RunPlanSystem.build_for(TestContent.variety(), s)
		for n: int in [2, 3, 4]:
			var pw: PlannedWave = plan.wave(n)
			var a: RouteOption = pw.options[0]
			var b: RouteOption = pw.options[1]
			got.append([a.pack_index, a.modifier_index, a.reward_index, b.pack_index, b.modifier_index, b.reward_index])
	assert_array(got).is_equal([
		[0, 2, 4, 2, 9, 0], [2, -1, 3, 1, 9, 4], [2, -1, 3, 0, 7, 4],
		[4, -1, 2, 1, 9, 3], [3, -1, 3, 2, 5, 7], [4, -1, 3, 0, 6, 6],
		[1, -1, 0, 4, 9, 1], [4, -1, 0, 3, 7, 6], [1, -1, 3, 0, 6, 2],  # V5-A: wave 2 skips mod_elite_pair (8)
	])
