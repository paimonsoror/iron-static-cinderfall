extends GdUnitTestSuite
## V2-B: the one-time GRANT ops (kits at tick 0, directives, route rewards) and the kit of the run.


func _kit_content(ops: Array[OpDef]) -> ContentSet:
	var c: ContentSet = TestContent.variety()
	var kit: KitDef = KitDef.new()
	kit.id = &"k_test"
	kit.index = c.kits.size()
	kit.ops = ops
	c.kits.append(kit)
	return c


func _kit_world(ops: Array[OpDef], run_seed: int = 1) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(_kit_content(ops), run_seed)
	cfg.kit_index = 1
	return SimWorld.new(cfg)


func _slice_world() -> SimWorld:
	return VarietyBKit.world_after(TestContent.variety(), 3)


func _hash_of_rng(rng: SimRng) -> String:
	var h: StateHasher = StateHasher.new()
	rng.hash_into(h)
	return h.finish()


func test_the_standard_kit_changes_nothing_and_draws_nothing() -> void:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 3))
	assert_int(w.scrap).is_equal(0)
	assert_float(w.core_max_hp).is_equal(1000.0)
	assert_int(w.events.peek().size()).is_equal(0)
	assert_str(_hash_of_rng(w.rng)).is_equal(_hash_of_rng(SimRng.new(3)))


func test_a_kit_applies_its_stats_flags_and_grants_at_tick_zero() -> void:
	var ops: Array[OpDef] = [
		VarietyBKit.op_add(&"core_max_mul", -0.15), VarietyBKit.op_add(&"w_dmg_mul", 0.25),
		VarietyBKit.op_flag(&"no_turret_pity"), VarietyBKit.op_grant(&"scrap", 400.0),
		VarietyBKit.op_grant(&"free_reroll", 2.0), VarietyBKit.op_grant(&"turret", 1.0),
	]
	var w: SimWorld = _kit_world(ops)
	assert_float(w.core_max_hp).is_equal(850.0)
	assert_float(w.core_hp).is_equal(850.0)  # a full core stays full
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.25, 0.00001)
	assert_bool(w.mods.has_flag(&"no_turret_pity")).is_true()
	assert_int(w.scrap).is_equal(400)
	assert_int(w.draft.free_rerolls).is_equal(2)
	assert_int(w.turrets.active_count()).is_equal(1)
	assert_int(w.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(1)


func test_the_kit_stats_survive_later_recomputes_and_its_grants_are_not_repeated() -> void:
	var ops: Array[OpDef] = [
		VarietyBKit.op_add(&"core_max_mul", -0.15), VarietyBKit.op_grant(&"scrap", 400.0), VarietyBKit.op_grant(&"turret", 1.0),
	]
	var w: SimWorld = _kit_world(ops)
	assert_bool(DraftSystem.grant_stack(w, w.content.directive_index(&"hot_loads"))).is_true()
	ModSystem.recompute(w)
	assert_float(w.core_max_hp).is_equal(850.0)
	assert_int(w.scrap).is_equal(400)
	assert_int(w.turrets.active_count()).is_equal(1)
	assert_bool(DraftSystem.grant_stack(w, w.content.directive_index(&"turret_deploy"))).is_true()
	assert_int(w.turrets.active_count()).is_equal(2)  # the kit turret and the directive turret are two turrets


func test_a_random_corrupted_directive_comes_from_the_kit_stream_alone() -> void:
	var ops: Array[OpDef] = [VarietyBKit.op_grant(&"directive_random", 1.0, &"corrupted")]
	var w: SimWorld = _kit_world(ops, 6)
	var glass: int = w.content.directive_index(&"glass_cannon")
	assert_int(w.draft.stacks_of(glass)).is_equal(1)  # the only corrupted directive of the slice
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.8, 0.00001)
	assert_float(w.core_max_hp).is_equal(700.0)
	var reference: SimRng = SimRng.new(6)
	var _roll: float = reference.stream(&"kit").randf()  # exactly one draw, from the stream named `kit`
	assert_str(_hash_of_rng(w.rng)).is_equal(_hash_of_rng(reference))


func test_a_random_grant_without_a_candidate_draws_nothing() -> void:
	var ops: Array[OpDef] = [VarietyBKit.op_grant(&"directive_random", 1.0, &"prototype")]
	var w: SimWorld = _kit_world(ops, 6)
	assert_str(_hash_of_rng(w.rng)).is_equal(_hash_of_rng(SimRng.new(6)))
	for stack: int in w.draft.stacks:
		assert_int(stack).is_equal(0)


func test_the_same_kit_seed_grants_the_same_directive() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var kit: KitDef = KitDef.new()
	kit.id = &"k_gambler"
	kit.index = 1
	var kit_ops: Array[OpDef] = [
		VarietyBKit.op_grant(&"directive_random", 1.0, &"corrupted"),
		VarietyBKit.op_grant(&"directive_random", 1.0, &"prototype"),
	]
	kit.ops = kit_ops
	c.kits.append(kit)
	var picks: Array[Array] = []
	for run_seed: int in [4, 4, 5]:
		var cfg: SimConfig = SimConfig.create(c, run_seed)
		cfg.kit_index = 1
		var w: SimWorld = SimWorld.new(cfg)
		picks.append(Array(w.draft.stacks))
	assert_array(picks[0]).is_equal(picks[1])
	assert_bool(picks[0] == picks[2]).is_false()


func test_a_directive_grant_adds_stacks_up_to_the_maximum() -> void:
	var w: SimWorld = _slice_world()
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"directive", 2.0, &"hot_loads")))
	assert_int(w.draft.stacks_of(w.content.directive_index(&"hot_loads"))).is_equal(2)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(2)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"directive", 9.0, &"glass_cannon")))
	assert_int(w.draft.stacks_of(w.content.directive_index(&"glass_cannon"))).is_equal(1)  # max 1
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"directive", 1.0, &"no_such")))


func test_scrap_grants_scale_per_act() -> void:
	var w: SimWorld = _slice_world()
	var ops: Array[OpDef] = [VarietyBKit.op_grant(&"scrap", 120.0, &"", 80.0)]
	ModSystem.grant(w, ops)
	assert_int(w.scrap).is_equal(120)
	w.phase_state.act = 3
	ModSystem.grant(w, ops)
	assert_int(w.scrap).is_equal(120 + 280)


func test_core_repairs_are_capped_and_reported() -> void:
	var w: SimWorld = _slice_world()
	w.set_core_hp(500.0)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"core_repair", 100.0)))
	assert_float(w.core_hp).is_equal(600.0)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"core_repair_frac", 0.08)))
	assert_float(w.core_hp).is_equal_approx(680.0, 0.001)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"core_repair", 9999.0)))
	assert_float(w.core_hp).is_equal(1000.0)
	var before: int = VarietyBKit.events_of(w, SimEventKind.Id.CORE_HEALED).size()
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"core_repair", 50.0)))
	assert_int(VarietyBKit.events_of(w, SimEventKind.Id.CORE_HEALED).size()).is_equal(before)  # nothing to repair


func test_event_charges_stop_at_the_cap_of_the_event() -> void:
	var w: SimWorld = _slice_world()
	var strike: int = w.content.event_index(&"deadfall_strike")
	w.events_state.charges[strike] = 2
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"event_charge", 5.0, &"deadfall_strike")))
	assert_int(w.events_state.charges[strike]).is_equal(3)  # charge_cap 3
	var changed: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.CHARGES_CHANGED)
	assert_int(changed.size()).is_equal(1)
	assert_int(changed[0].a).is_equal(strike)
	assert_int(changed[0].b).is_equal(3)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"event_charge", 1.0, &"deadfall_strike")))
	assert_int(VarietyBKit.events_of(w, SimEventKind.Id.CHARGES_CHANGED).size()).is_equal(1)
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"event_charge", 1.0, &"no_such_event")))


func test_a_weapon_grant_never_overwrites_a_full_slot() -> void:
	var w: SimWorld = _slice_world()
	w.arsenal.slot_weapon[1] = Ids.WP_SCATTERGUN
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"weapon", 1.0, &"lmg")))
	assert_array(Array(w.arsenal.slot_weapon)).is_equal([Ids.WP_PISTOL, Ids.WP_SCATTERGUN, -1])
	ModSystem.grant(w, VarietyBKit.ops_of(VarietyBKit.op_grant(&"weapon", 1.0, &"no_such_weapon")))
	assert_array(Array(w.arsenal.slot_weapon)).is_equal([Ids.WP_PISTOL, Ids.WP_SCATTERGUN, -1])


func test_the_slice_rewards_do_what_their_ops_say() -> void:
	var w: SimWorld = _slice_world()
	var run: RunDef = w.content.run
	w.set_core_hp(500.0)
	ModSystem.apply_reward(w, run.reward_index(&"rw_scrap"))
	assert_int(w.scrap).is_equal(120)
	w.phase_state.act = 2
	ModSystem.apply_reward(w, run.reward_index(&"rw_scrap"))
	assert_int(w.scrap).is_equal(120 + 200)
	ModSystem.apply_reward(w, run.reward_index(&"rw_patch"))
	assert_float(w.core_hp).is_equal_approx(580.0, 0.001)  # +8% of 1000
	ModSystem.apply_reward(w, run.reward_index(&"rw_reroll"))
	assert_int(w.draft.free_rerolls).is_equal(1)
	ModSystem.apply_reward(w, run.reward_index(&"rw_charge"))
	assert_int(w.events_state.charges[w.content.event_index(&"deadfall_strike")]).is_equal(2)  # start_charges 1 + the reward
	assert_bool(w.draft.next_rare).is_false()
	ModSystem.apply_reward(w, run.reward_index(&"rw_rare_draft"))
	assert_bool(w.draft.next_rare).is_true()
	assert_bool(w.draft.next_double).is_false()
	ModSystem.apply_reward(w, run.reward_index(&"rw_double_pick"))
	assert_bool(w.draft.next_double).is_true()


func test_rewards_without_a_sim_effect_here_and_bad_indices_are_harmless() -> void:
	var w: SimWorld = _slice_world()
	var run: RunDef = w.content.run
	var before: String = w.state_hash()
	ModSystem.apply_reward(w, run.reward_index(&"rw_crate"))  # SalvageSystem's
	ModSystem.apply_reward(w, run.reward_index(&"rw_data"))  # the profile's
	ModSystem.apply_reward(w, -1)
	ModSystem.apply_reward(w, 99)
	assert_str(w.state_hash()).is_equal(before)


func test_a_double_pick_reward_reaches_the_next_draft() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(TestContent.variety())
	ModSystem.apply_reward(w, w.content.run.reward_index(&"rw_double_pick"))
	VarietyBKit.open_draft(w)
	assert_int(w.draft.picks_left).is_equal(2)
