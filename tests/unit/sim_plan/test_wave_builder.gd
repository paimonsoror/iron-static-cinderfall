extends GdUnitTestSuite
## V2-A: WaveBuilder and WaveRules (VARIETY_SPEC 5.3, CONTENT 1.3): the count and interval formulas, the five composition
## rules, the budget fit, boss waves and the plan-level modifiers.


func _stream(n: int = 1) -> RandomNumberGenerator:
	return PlanRng.stream(n, &"plan.wave:test")


func _types(groups: Array[SpawnGroupDef]) -> Array[int]:
	var out: Array[int] = []
	for g: SpawnGroupDef in groups:
		out.append(g.enemy_index)
	return out


func _fodder_share(c: ContentSet, groups: Array[SpawnGroupDef]) -> float:
	var fodder: float = 0.0
	for g: SpawnGroupDef in groups:
		if WaveRules.FODDER.has(g.enemy_index):
			fodder += float(g.count) * c.enemies[g.enemy_index].cost
	return fodder / VarietyAKit.spent(c, groups)


func test_the_count_formula_of_content_1_3() -> void:
	assert_int(WaveBuilder.formula_count(60.0, 0.7, 1.0, 0.5)).is_equal(42)
	assert_int(WaveBuilder.formula_count(60.0, 0.7, 1.0, 0.0)).is_equal(38)  # 42 * 0.9 = 37.8
	assert_int(WaveBuilder.formula_count(60.0, 0.7, 1.0, 1.0)).is_equal(46)  # 42 * 1.1 = 46.2
	assert_int(WaveBuilder.formula_count(34.0, 0.15, 5.0, 0.5)).is_equal(1)  # 1.02
	assert_int(WaveBuilder.formula_count(1.0, 0.01, 5.0, 0.0)).is_equal(1)  # never below one body


func test_the_interval_is_the_window_after_the_start_spread_over_the_count_and_clamped() -> void:
	var g: GroupDraft = GroupDraft.new()
	g.count = 10
	g.start_frac = 0.2
	g.tempo = 0.5
	assert_int(g.to_def(1800).interval_ticks).is_equal(72)  # 1800 * 0.8 * 0.5 / 10
	assert_int(g.to_def(1800).start_tick).is_equal(360)
	g.count = 5000
	assert_int(g.to_def(1800).interval_ticks).is_equal(GroupDraft.MIN_INTERVAL_TICKS)  # 0.08 s
	g.count = 1
	g.tempo = 1.0
	g.start_frac = 0.0
	assert_int(g.to_def(1800).interval_ticks).is_equal(GroupDraft.MAX_INTERVAL_TICKS)  # 4.0 s
	g.min_start_tick = 500
	assert_int(g.to_def(1800).start_tick).is_equal(500)


func test_the_builder_draws_one_number_per_pack_group_and_nothing_else() -> void:
	var c: ContentSet = VarietyAKit.content()
	var pack: PackDef = c.run.packs[c.run.pack_index(&"pack_powder")]
	var used: RandomNumberGenerator = _stream()
	WaveBuilder.build(c, VarietyAKit.slot(c, 3), pack.index, 1.0, used)
	var reference: RandomNumberGenerator = _stream()
	for _k: int in pack.group_count():
		reference.randf_range(0.0, 1.0)
	assert_int(used.randi()).is_equal(reference.randi())


func test_a_type_below_its_min_act_becomes_skitters_at_the_same_budget() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_split", PackedInt32Array([Ids.EN_SPLITTER, Ids.EN_SKITTER]))
	var act1: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, 3), pack.index, 1.0, _stream())
	assert_bool(_types(act1).has(Ids.EN_SPLITTER)).is_false()
	assert_float(VarietyAKit.spent(c, act1)).is_between(46.0 * 0.95, 46.0 * 1.05)
	var act2: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, 7), pack.index, 1.0, _stream())
	assert_bool(_types(act2).has(Ids.EN_SPLITTER)).is_true()


func test_at_least_forty_percent_of_every_wave_is_basic_fodder() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_heavy", PackedInt32Array([Ids.EN_SPITTER, Ids.EN_HOLLOW, Ids.EN_SKITTER]))
	pack.group_share = PackedFloat32Array([0.45, 0.4, 0.15])
	for s: int in range(1, 31):
		var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, 7), pack.index, 1.0, _stream(s))
		assert_float(_fodder_share(c, groups)).is_greater_equal(0.4)


func test_a_pack_without_fodder_gets_a_skitter_group() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_none", PackedInt32Array([Ids.EN_HOLLOW, Ids.EN_BURSTER]))
	var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, 7), pack.index, 1.0, _stream())
	assert_bool(_types(groups).has(Ids.EN_SKITTER)).is_true()
	assert_float(_fodder_share(c, groups)).is_greater_equal(0.4)


func _specialist_types(c: ContentSet, wave_number: int, pack: PackDef) -> int:
	var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, wave_number), pack.index, 1.0, _stream())
	var specialists: Dictionary[int, bool] = {}
	for g: SpawnGroupDef in groups:
		if WaveRules.SPECIALISTS.has(g.enemy_index):
			specialists[g.enemy_index] = true
	return specialists.size()


func test_specialist_types_per_wave_are_capped_at_two_in_act_two_and_three_in_act_three() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var all: PackedInt32Array = PackedInt32Array([
		Ids.EN_SPITTER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_SHIELDBEARER, Ids.EN_SKITTER, Ids.EN_RUSHER,
	])
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_specs", all)
	assert_int(_specialist_types(c, 7, pack)).is_equal(2)
	assert_int(_specialist_types(c, 12, pack)).is_equal(3)


func test_a_reclaimer_group_never_starts_in_the_first_fifth_of_the_window() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_mast", PackedInt32Array([Ids.EN_RECLAIMER, Ids.EN_SKITTER]))
	var slot: WaveSlotDef = VarietyAKit.slot(c, 12)
	var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, slot, pack.index, 1.0, _stream())
	for g: SpawnGroupDef in groups:
		if g.enemy_index == Ids.EN_RECLAIMER:
			assert_int(g.start_tick).is_greater_equal(ceili(0.2 * float(slot.window_ticks)))


func test_bursters_are_never_the_first_three_bodies_of_a_wave() -> void:
	var c: ContentSet = VarietyAKit.content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_early", PackedInt32Array([Ids.EN_BURSTER, Ids.EN_SKITTER]))
	for s: int in range(1, 41):
		var w: SimWorld = VarietyAKit.world(s)
		var groups: Array[SpawnGroupDef] = WaveBuilder.build(c, VarietyAKit.slot(c, 3), pack.index, 1.0, _stream(s))
		w.plan.waves[0].options[0].groups = groups
		SpawnSystem.begin_wave(w, 1)
		for k: int in 3:
			assert_int(w.nav.sched_type[k]).is_not_equal(Ids.EN_BURSTER)
		var bursters: int = 0
		for k: int in w.nav.sched_type.size():
			bursters += 1 if w.nav.sched_type[k] == Ids.EN_BURSTER else 0
		assert_int(bursters).is_greater(0)  # delayed, not dropped


func test_boss_waves_schedule_nothing_for_four_seconds_after_the_boss() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 21):
		for n: int in [5, 10, 15]:
			var plan: RunPlan = RunPlanSystem.build_for(c, s)
			var groups: Array[SpawnGroupDef] = plan.wave(n).options[0].groups
			assert_int(groups[0].start_tick).is_equal(0)
			assert_int(groups[0].count).is_equal(1)
			assert_int(groups.size()).is_greater(1)
			for k: int in range(1, groups.size()):
				assert_int(groups[k].start_tick).is_greater_equal(WaveBuilder.BOSS_QUIET_TICKS)


func test_a_boss_escort_pack_replaces_the_share_list() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	c.bosses[0].escort_pack = &"pack_powder"
	var plan: RunPlan = RunPlanSystem.build_for(c, 2)
	var types: Array[int] = _types(plan.wave(5).options[0].groups)
	assert_bool(types.has(Ids.EN_BURSTER)).is_true()
	assert_bool(types.has(Ids.EN_SKITTER)).is_true()
	for g: SpawnGroupDef in VarietyAKit.tail(plan.wave(5).options[0].groups):
		assert_int(g.start_tick).is_greater_equal(WaveBuilder.BOSS_QUIET_TICKS)


func test_every_option_spends_its_budget_within_ten_percent() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var worst: float = 0.0
	for s: int in range(1, 101):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			var slot: WaveSlotDef = c.run.wave_slot(pw.index)
			for o: RouteOption in pw.options:
				if pw.is_boss:
					continue  # a boss body is not bought from the budget
				var target: float = slot.budget * c.run.packs[o.pack_index].budget_mult * (1.25 if o.hot else 1.0)
				var off: float = absf(VarietyAKit.spent(c, o.groups) - target) / target
				worst = maxf(worst, off)
				assert_float(off).override_failure_message("seed %d wave %d: %.3f off" % [s, pw.index, off]).is_less_equal(0.1)
	assert_float(worst).is_less_equal(0.1)


func test_boss_escorts_spend_the_wave_budget_within_ten_percent() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 41):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for n: int in [5, 10, 15]:
			var groups: Array[SpawnGroupDef] = VarietyAKit.tail(plan.wave(n).options[0].groups)
			var target: float = VarietyAKit.slot(c, n).budget
			assert_float(absf(VarietyAKit.spent(c, groups) - target) / target).is_less_equal(0.1)


func test_a_hot_option_spends_one_and_a_quarter_times_the_act_budget() -> void:
	var c: ContentSet = VarietyAKit.content()
	var pack: PackDef = c.run.packs[c.run.pack_index(&"pack_column")]
	var standard: float = VarietyAKit.spent(c, WaveBuilder.build(c, VarietyAKit.slot(c, 4), pack.index, 1.0, _stream()))
	var hot: float = VarietyAKit.spent(c, WaveBuilder.build(c, VarietyAKit.slot(c, 4), pack.index, RunPlanSystem.HOT_BUDGET_MULT, _stream()))
	assert_float(hot / standard).is_between(1.15, 1.35)


func test_twin_gate_splits_the_right_edge_groups_and_keeps_the_wave_length() -> void:
	var c: ContentSet = VarietyAKit.content()
	var mod: ModifierDef = ModifierDef.new()
	mod.id = &"mod_twin"
	mod.index = c.run.modifiers.size()
	mod.list = ModifierDef.List.MILD
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.FLAG
	op.target = &"twin_gate"
	mod.ops.append(op)
	c.run.modifiers.append(mod)
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = Ids.EN_SKITTER
	g.count = 11
	g.start_tick = 30
	g.interval_ticks = 40
	g.region_id = &"right"
	var groups: Array[SpawnGroupDef] = [g]
	WaveBuilder.apply_modifier(c, groups, mod.index)
	assert_int(groups.size()).is_equal(2)
	assert_int(groups[0].count + groups[1].count).is_equal(11)
	assert_str(String(groups[0].region_id)).is_equal("right")
	assert_str(String(groups[1].region_id)).is_equal("upper_right")
	assert_int(groups[0].interval_ticks).is_equal(80)
	assert_int(groups[1].interval_ticks).is_equal(80)
	assert_int(groups[1].start_tick).is_equal(30)


func test_the_rush_modifier_scales_every_interval_and_a_runtime_modifier_changes_nothing() -> void:
	var c: ContentSet = VarietyAKit.content()
	var rush: ModifierDef = ModifierDef.new()
	rush.index = c.run.modifiers.size()
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.MUL
	op.target = &"spawn_interval_mul"
	op.value = 0.6
	rush.ops.append(op)
	c.run.modifiers.append(rush)
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.count = 10
	g.interval_ticks = 100
	g.region_id = &"upper_right"
	var groups: Array[SpawnGroupDef] = [g]
	WaveBuilder.apply_modifier(c, groups, rush.index)
	assert_int(groups[0].interval_ticks).is_equal(60)
	assert_int(groups[0].count).is_equal(10)
	WaveBuilder.apply_modifier(c, groups, c.run.modifier_index(&"mod_volatile"))  # a runtime effect: no plan change
	assert_int(groups[0].interval_ticks).is_equal(60)
	WaveBuilder.apply_modifier(c, groups, -1)
	assert_int(groups.size()).is_equal(1)
