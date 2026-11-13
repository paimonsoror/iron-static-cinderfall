extends GdUnitTestSuite
## V2-A: the run plan built at tick 0 (VARIETY_SPEC 9.3, CONTENT 1): determinism, golden plans of seeds 1 to 3, the shape of
## every wave, the two options of a wave, and that nothing during the run can change what a later wave offers.


func _plan_hash(plan: RunPlan) -> String:
	var h: StateHasher = StateHasher.new()
	plan.hash_into(h)
	return h.finish()


func _wave_hash(pw: PlannedWave) -> String:
	var h: StateHasher = StateHasher.new()
	pw.hash_into(h)
	return h.finish()


func test_the_same_seed_gives_the_same_plan_and_another_seed_a_different_one() -> void:
	var c: ContentSet = VarietyAKit.content()
	assert_str(_plan_hash(RunPlanSystem.build_for(c, 5))).is_equal(_plan_hash(RunPlanSystem.build_for(VarietyAKit.content(), 5)))
	var seen: Dictionary[String, bool] = {}
	for s: int in range(1, 41):
		seen[_plan_hash(RunPlanSystem.build_for(c, s))] = true
	assert_int(seen.size()).is_equal(40)


func test_a_world_carries_the_plan_of_its_seed() -> void:
	var c: ContentSet = VarietyAKit.content()
	var w: SimWorld = VarietyAKit.world(7, c)
	assert_str(_plan_hash(w.plan)).is_equal(_plan_hash(RunPlanSystem.build_for(c, 7)))
	assert_int(w.plan.chosen.size()).is_equal(c.run.waves.size())
	assert_int(w.plan.wave_count()).is_equal(5)


func test_building_a_world_draws_nothing_from_the_world_streams() -> void:
	var w: SimWorld = VarietyAKit.world(9)
	var h: StateHasher = StateHasher.new()
	w.rng.hash_into(h)
	var fresh: StateHasher = StateHasher.new()
	SimRng.new(9).hash_into(fresh)
	assert_str(h.finish()).is_equal(fresh.finish())


func test_the_plan_streams_are_the_named_streams_of_the_spec() -> void:
	# PlanRng seeds exactly like SimRng, so `plan.route:3` is the same stream whichever object owns it.
	var rng: SimRng = SimRng.new(42)
	for stream_name: StringName in [&"plan.boss", &"plan.route:3", &"plan.wave:4:1", &"plan.elite:7", &"plan.hazard:2"]:
		assert_int(PlanRng.stream(42, stream_name).randi()).is_equal(rng.stream(stream_name).randi())
	assert_int(PlanRng.stream(42, &"plan.route:3").randi()).is_not_equal(PlanRng.stream(42, &"plan.route:4").randi())


func test_golden_plan_of_seeds_1_to_3() -> void:
	# [pack of A, reward of A, pack of B, reward of B] for waves 2, 3 and 4 (pack and reward indices of the variety fixture).
	var want: Dictionary[int, Array] = {
		1: [[2, 4, 1, 0], [0, 3, 2, 4], [0, 3, 1, 4]],
		2: [[2, 2, 1, 3], [1, 3, 0, 7], [2, 3, 0, 6]],
		3: [[0, 0, 2, 1], [0, 0, 2, 6], [0, 3, 1, 2]],
	}
	var variants: Dictionary[int, int] = {1: 0, 2: 2, 3: 0}
	var c: ContentSet = VarietyAKit.slice_content()  # 3 packs, 1 modifier: the content the numbers above were recorded on
	for s: int in [1, 2, 3]:
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		assert_array(Array(plan.boss_ids)).is_equal([Ids.EN_HULK, -1, -1])
		assert_int(plan.boss_variant).is_equal(variants[s])
		assert_int(plan.wave(1).options[0].pack_index).is_equal(0)
		for n: int in [0, 1, 2]:
			var pw: PlannedWave = plan.wave(n + 2)
			var got: Array = [pw.options[0].pack_index, pw.options[0].reward_index, pw.options[1].pack_index, pw.options[1].reward_index]
			assert_array(got).override_failure_message("seed %d wave %d" % [s, n + 2]).is_equal(want[s][n])


func test_golden_groups_of_seed_1_wave_2() -> void:
	var c: ContentSet = VarietyAKit.slice_content()
	var o: RouteOption = RunPlanSystem.build_for(c, 1).wave(2).options[0]
	var got: Array = []
	for g: SpawnGroupDef in o.groups:
		got.append([g.enemy_index, g.count, g.start_tick, g.interval_ticks, String(g.region_id)])
	assert_array(got).is_equal([
		[Ids.EN_BURSTER, 6, 234, 221, "right"], [Ids.EN_SKITTER, 16, 0, 78, "right"], [Ids.EN_MOTE, 17, 468, 32, "upper_right"],
	])


func test_the_opener_is_the_fixed_pack_with_no_modifier_reward_elite_or_event() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 30):
		var pw: PlannedWave = RunPlanSystem.build_for(c, s).wave(1)
		assert_int(pw.options.size()).is_equal(1)
		var o: RouteOption = pw.options[0]
		assert_int(o.pack_index).is_equal(c.run.pack_index(&"pack_tide"))
		assert_int(o.modifier_index).is_equal(-1)
		assert_int(o.reward_index).is_equal(-1)
		assert_bool(o.hot).is_false()
		assert_int(o.elites.size()).is_equal(0)
		assert_int(pw.events.size()).is_equal(0)


func test_boss_waves_have_one_option_that_starts_with_the_boss() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var plan: RunPlan = RunPlanSystem.build_for(c, 4)
	assert_array(Array(plan.boss_ids)).is_equal([Ids.EN_HULK, Ids.EN_AEGIS_ARRAY, Ids.EN_HULK])
	for n: int in [5, 10, 15]:
		var pw: PlannedWave = plan.wave(n)
		assert_bool(pw.is_boss).is_true()
		assert_int(pw.options.size()).is_equal(1)
		var first: SpawnGroupDef = pw.options[0].groups[0]
		assert_int(first.enemy_index).is_equal(plan.boss_ids[pw.act - 1])
		assert_int(first.count).is_equal(1)
		assert_int(first.start_tick).is_equal(0)
		assert_int(pw.options[0].elites.size()).is_equal(0)
		assert_int(pw.options[0].reward_index).is_equal(-1)


func test_every_other_wave_offers_two_options_and_never_the_same_pack() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 61):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			if pw.index == 1 or pw.is_boss:
				continue
			assert_int(pw.options.size()).is_equal(2)
			assert_int(pw.options[0].pack_index).is_not_equal(pw.options[1].pack_index)


func test_option_a_is_standard_and_option_b_is_hot_with_a_modifier() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 41):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			if pw.options.size() != 2:
				continue
			assert_bool(pw.options[1].hot).is_true()
			assert_int(pw.options[1].modifier_index).is_not_equal(-1)
			if pw.act == 1:
				assert_bool(pw.options[0].hot).is_false()  # "both hot" starts in act II
			var mod_a: int = pw.options[0].modifier_index
			if not pw.options[0].hot:  # a standard option has no modifier or a mild one
				assert_bool(mod_a == -1 or c.run.modifiers[mod_a].list == ModifierDef.List.MILD).is_true()
			else:
				assert_bool(mod_a >= 0 and c.run.modifiers[mod_a].list == ModifierDef.List.HOT).is_true()
			assert_int(c.run.modifiers[pw.options[1].modifier_index].list).is_equal(ModifierDef.List.HOT)


func test_both_hot_waves_start_in_act_two_and_happen_about_one_time_in_seven() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var both: int = 0
	var total: int = 0
	for s: int in range(1, 201):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			if pw.options.size() == 2 and pw.act >= 2:
				total += 1
				both += 1 if pw.options[0].hot else 0
	assert_float(float(both) / float(total)).is_between(0.09, 0.21)


func test_standard_options_never_draw_a_hot_only_reward() -> void:
	var c: ContentSet = VarietyAKit.content()
	var hot_only: Array[int] = [c.run.reward_index(&"rw_charge"), c.run.reward_index(&"rw_double_pick"), c.run.reward_index(&"rw_data")]
	var hot_seen: Dictionary[int, bool] = {}
	for s: int in range(1, 201):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for n: int in [2, 3, 4]:
			assert_bool(hot_only.has(plan.wave(n).options[0].reward_index)).is_false()
			hot_seen[plan.wave(n).options[1].reward_index] = true
	for r: int in hot_only:
		assert_bool(hot_seen.has(r)).override_failure_message("reward %d never offered to a hot option" % r).is_true()


func test_a_pick_at_wave_3_does_not_change_wave_7() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var a: SimWorld = VarietyAKit.world(13, c)
	var b: SimWorld = VarietyAKit.world(13, c)
	var before: String = _wave_hash(a.plan.wave(7))
	for w: SimWorld in [a, b]:
		VarietyAKit.run_to_route(w)  # wave 1 is cleared: the route of wave 2
		assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
		w.submit(SimCommand.pick_route(1, 0))
		w.step()
		VarietyAKit.run_to_route(w)  # wave 2 is cleared: the route of wave 3
		assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	a.submit(SimCommand.pick_route(2, 0))
	b.submit(SimCommand.pick_route(2, 1))
	a.step()
	b.step()
	assert_int(a.plan.chosen[2]).is_equal(0)
	assert_int(b.plan.chosen[2]).is_equal(1)
	assert_str(_wave_hash(a.plan.wave(7))).is_equal(before)
	assert_str(_wave_hash(b.plan.wave(7))).is_equal(before)
	for n: int in range(1, 16):
		assert_str(_wave_hash(a.plan.wave(n))).is_equal(_wave_hash(b.plan.wave(n)))


func test_the_plan_survives_a_json_round_trip() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var plan: RunPlan = RunPlanSystem.build_for(c, 21)
	plan.chosen[3] = 1
	var doc: Dictionary = JSON.parse_string(JSON.stringify(plan.to_dict()))
	assert_str(_plan_hash(RunPlan.from_dict(doc))).is_equal(_plan_hash(plan))


func test_drum_points_are_three_distinct_arena_points_per_act() -> void:
	var c: ContentSet = VarietyAKit.content()
	var points: int = c.arena.drum_points.size()
	for s: int in range(1, 31):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		assert_int(plan.drum_points.size()).is_equal(3 * c.run.acts.size())
		for act: int in c.run.acts.size():
			var seen: Dictionary[int, bool] = {}
			var last: int = -1
			for k: int in 3:
				var p: int = plan.drum_points[act * 3 + k]
				assert_int(p).is_between(0, points - 1)
				assert_bool(seen.has(p)).is_false()
				assert_int(p).is_greater(last)
				seen[p] = true
				last = p


func test_a_pack_is_offered_only_from_its_min_act() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var late: PackDef = VarietyAKit.pack_of(c, &"pack_late", PackedInt32Array([Ids.EN_SKITTER, Ids.EN_RUSHER]), 3)
	for s: int in range(1, 61):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			for o: RouteOption in pw.options:
				if o.pack_index == late.index:
					assert_int(pw.act).is_equal(3)
	var used: bool = false
	for s: int in range(1, 61):
		for pw: PlannedWave in RunPlanSystem.build_for(c, s).waves:
			for o: RouteOption in pw.options:
				used = used or o.pack_index == late.index
	assert_bool(used).is_true()
