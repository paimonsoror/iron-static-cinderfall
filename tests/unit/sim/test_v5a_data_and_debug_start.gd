extends GdUnitTestSuite
## V5-A: the Recovered Data table of CONTENT 10 counted by the sim (RunStats.data, SimWorld.data_reward), the field
## options a run starts with (free reroll, third sling), the boss ids of the run, and the debug starts of ARCH 11
## (DebugStart: a later wave with a scripted build, a chosen boss). Hand-made states on TestContent.variety().


func _world(run_seed: int = 1) -> SimWorld:
	return TestContent.variety_world(run_seed)


func _config(run_seed: int = 1) -> SimConfig:
	return SimConfig.create(TestContent.variety(), run_seed)


## Clears waves (every enemy dies, the schedule counts as spawned) and answers every choice until `waves` are cleared.
func _clear_waves(w: SimWorld, waves: int) -> void:
	var command_id: int = 0
	for _n: int in 400:
		if w.is_over() or w.waves_completed >= waves:
			return
		if not VarietyAKit.run_to_await(w):
			return
		if w.waves_completed >= waves:
			return
		command_id += 1
		VarietyAKit.answer(w, command_id)


# --- the Data table ---


func test_a_cleared_wave_banks_six_data_and_data_siphon_adds_two_per_stack() -> void:
	var w: SimWorld = _world()
	assert_int(w.stats.data).is_equal(0)
	assert_int(w.data_reward()).is_equal(0)
	_clear_waves(w, 1)
	assert_int(w.waves_completed).is_equal(1)
	assert_int(w.stats.data).is_equal(6)
	w.mods.data_per_wave = 4.0  # two stacks of data_siphon
	PhaseAwaits.bank_wave_data(w)
	assert_int(w.stats.data).is_equal(6 + 6 + 4)
	assert_int(w.data_reward()).is_equal(16)  # an unfinished run is worth what it banked


func test_the_act_bosses_bank_30_and_45_and_the_last_boss_nothing() -> void:
	var w: SimWorld = _world()
	w.phase = GameState.Id.SPAWNING
	var expected: Array[int] = [30, 45, 0]
	var bosses: Array[int] = [Ids.EN_BROOD_CARRIER, Ids.EN_TREMOR_RIG, Ids.EN_HULK]
	for act: int in 3:
		w.phase_state.act = act + 1
		var before: int = w.stats.data
		var i: int = w.spawn_enemy(bosses[act], 10.0, 0.0)
		w.kill_enemy(i, DamageSource.Id.WARDEN)
		assert_int(w.stats.data - before).is_equal(expected[act])
	# a boss part that removes itself, and any plain enemy, bank nothing
	w.phase_state.act = 1
	var before_self: int = w.stats.data
	var lance: int = w.spawn_enemy(Ids.EN_LANCE_PLATFORM, 10.0, 0.0)
	w.kill_enemy(lance, DeathHooks.SOURCE_SELF)
	var skitter: int = w.spawn_enemy(Ids.EN_SKITTER, 10.0, 0.0)
	w.kill_enemy(skitter, DamageSource.Id.WARDEN)
	assert_int(w.stats.data).is_equal(before_self)
	assert_array(Array(w.stats.boss_ids)).is_equal([Ids.EN_BROOD_CARRIER, Ids.EN_TREMOR_RIG, Ids.EN_HULK, Ids.EN_LANCE_PLATFORM])


func test_rw_data_banks_twenty_five_when_its_wave_is_cleared() -> void:
	var w: SimWorld = _world()
	var reward: RewardDef = w.content.run.route_rewards[w.content.run.reward_index(&"rw_data")]
	ModSystem.grant(w, reward.ops)
	assert_int(w.stats.data).is_equal(25)
	# through the flow: a route whose reward is rw_data pays at the wave clear, before the first await
	var flow: SimWorld = _world(3)
	_clear_waves(flow, 1)
	flow.plan.wave(2).options[0].reward_index = flow.content.run.reward_index(&"rw_data")
	_clear_waves(flow, 2)
	assert_int(flow.stats.data).is_equal(6 + 6 + 25)


func test_a_victory_adds_100_and_up_to_50_for_the_core() -> void:
	var w: SimWorld = _world()
	w.stats.data = 165
	w.phase = GameState.Id.VICTORY
	w.core_hp = 600.0
	assert_int(w.data_reward()).is_equal(165 + 100 + 30)  # CONTENT 10: "victory at 60% core: 90 + 75 + 130 = 295"
	assert_int(w.summary("r").data_reward).is_equal(295)
	w.core_hp = w.core_max_hp
	assert_int(w.data_reward()).is_equal(165 + 150)
	w.phase = GameState.Id.DEFEAT
	w.core_hp = 0.0
	assert_int(w.data_reward()).is_equal(165)  # a defeat keeps what was banked


func test_a_whole_run_banks_the_table() -> void:
	var w: SimWorld = _world(2)
	_clear_waves(w, 15)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	var rw_data: int = w.content.run.reward_index(&"rw_data")
	var extra: int = 0
	for wave_number: int in range(2, 15):
		var option: RouteOption = w.plan.option(wave_number)
		extra += 25 if option != null and option.reward_index == rw_data else 0
	assert_int(w.stats.data).is_equal(15 * 6 + 30 + 45 + extra)
	assert_int(w.data_reward()).is_equal(w.stats.data + 150)  # the core was never hit


func test_the_snapshot_carries_the_banked_data_and_the_hash_does_not() -> void:
	var w: SimWorld = _world()
	var before: String = w.state_hash()
	w.stats.add_data(21)
	assert_str(w.state_hash()).is_equal(before)  # Data changes no outcome
	var back: SimWorld = _world()
	assert_bool(WorldSnapshot.restore(back, WorldSnapshot.capture(w))).is_true()
	assert_int(back.stats.data).is_equal(21)
	w.stats.add_data(-100)
	assert_int(w.stats.data).is_equal(0)  # never negative


func test_the_legacy_content_keeps_its_reward_formula() -> void:
	var w: SimWorld = TestContent.world()
	w.phase = GameState.Id.DEFEAT
	w.waves_completed = 3
	assert_int(w.data_reward()).is_equal(Formulas.data_reward(RunResult.Id.DEFEAT, 3, 0.0, w.content.mission))
	assert_int(w.stats.data).is_equal(0)


# --- the field options of the Archive ---


func test_a_new_profile_starts_with_two_slots_and_no_free_reroll() -> void:
	var w: SimWorld = _world()
	assert_int(w.arsenal.slot_count).is_equal(2)
	assert_int(w.draft.free_rerolls).is_equal(0)


func test_the_third_sling_and_the_spare_reroll_are_there_at_tick_zero() -> void:
	var cfg: SimConfig = _config()
	cfg.unlocked = PackedStringArray(["u_f_reroll", "u_f_third_sling"])
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.arsenal.slot_count).is_equal(3)
	assert_int(w.draft.free_rerolls).is_equal(1)
	ArsenalSystem.give_weapon(w, 2, Ids.WP_SMG)  # the third slot takes a weapon and can be swapped to
	assert_int(ArsenalSystem.swap(w, 1, 2)).is_equal(Reason.Id.OK)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)
	var daily: SimConfig = _config()
	daily.daily = true  # the Daily Run has every unlock
	var d: SimWorld = SimWorld.new(daily)
	assert_int(d.arsenal.slot_count).is_equal(3)
	assert_int(d.draft.free_rerolls).is_equal(1)
	ArsenalSystem.open_slots(d, 1)
	assert_int(d.arsenal.slot_count).is_equal(3)  # never fewer


# --- the debug starts ---


func test_a_normal_run_is_not_a_debug_run_and_starts_at_wave_one() -> void:
	var cfg: SimConfig = _config()
	assert_bool(cfg.is_debug()).is_false()
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.wave).is_equal(0)
	assert_int(w.waves_completed).is_equal(0)
	for stacks: int in w.draft.stacks:
		assert_int(stacks).is_equal(0)


func test_a_debug_start_at_wave_seven_plays_wave_seven_first_with_a_scripted_build() -> void:
	var cfg: SimConfig = _config(4)
	cfg.debug_start_wave = 7
	assert_bool(cfg.is_debug()).is_true()
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.waves_completed).is_equal(6)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	var held: int = 0
	for stacks: int in w.draft.stacks:
		held += stacks
	assert_int(held).is_equal(6)  # one directive per skipped wave
	assert_int(w.draft.stacks_of(w.content.directive_index(&"hot_loads"))).is_equal(1)
	assert_int(w.draft.stacks_of(w.content.directive_index(&"turret_deploy"))).is_equal(2)
	assert_int(w.turrets.active_count()).is_equal(2)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_ASSAULT_RIFLE)  # act II: the later second weapon
	for _n: int in w.content.mission.prepare_ticks:
		w.step()
	assert_int(w.wave).is_equal(7)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.phase_state.act).is_equal(2)
	var acts: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.ACT_STARTED)
	assert_int(acts.size()).is_equal(1)
	assert_int(acts[0].a).is_equal(2)
	var started: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
	assert_int(started[0].a).is_equal(7)
	# the same config gives the same world (a resumed debug run is rebuilt from it)
	var again: SimWorld = SimWorld.new(cfg)
	for _n: int in w.content.mission.prepare_ticks:
		again.step()
	assert_str(again.state_hash()).is_equal(w.state_hash())


func test_a_debug_start_in_act_one_gives_the_smg_from_wave_three_and_is_clamped_to_the_run() -> void:
	var cfg: SimConfig = _config()
	cfg.debug_start_wave = 3
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_SMG)
	cfg.debug_start_wave = 2
	assert_int(SimWorld.new(cfg).arsenal.slot_weapon[1]).is_equal(-1)
	cfg.debug_start_wave = 99
	assert_int(SimWorld.new(cfg).waves_completed).is_equal(14)  # the last wave is still played


func test_a_debug_boss_takes_its_act_and_starts_at_its_boss_wave() -> void:
	for id: StringName in [&"lance_platform", &"brood_carrier", &"aegis_array", &"tremor_rig", &"siege_hulk"]:
		var cfg: SimConfig = _config(6)
		cfg.debug_boss = id
		var w: SimWorld = SimWorld.new(cfg)
		var boss: BossDef = w.content.boss(id)
		var wave: int = boss.pool_act * 5
		assert_int(w.waves_completed).is_equal(wave - 1)
		assert_int(w.plan.boss_ids[boss.pool_act - 1]).is_equal(boss.enemy_index)
		var groups: Array[SpawnGroupDef] = w.plan.option(wave).groups
		assert_int(groups[0].enemy_index).is_equal(boss.enemy_index)
		assert_int(groups[0].count).is_equal(1)
		assert_int(groups.size()).is_greater(1)  # with its escorts


func test_a_node_nine_variant_is_a_debug_boss_too_and_an_unknown_id_changes_nothing() -> void:
	var cfg: SimConfig = _config(6)
	cfg.debug_boss = &"hulk_fed"
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.waves_completed).is_equal(14)
	assert_str(String(w.content.run.hulk_variants[w.plan.boss_variant])).is_equal("hulk_fed")
	cfg.debug_boss = &"hulk_overclocked"
	var o: SimWorld = SimWorld.new(cfg)
	assert_str(String(o.content.run.hulk_variants[o.plan.boss_variant])).is_equal("hulk_overclocked")
	cfg.debug_boss = &"no_such_boss"
	var plain: SimWorld = SimWorld.new(cfg)
	assert_int(plain.waves_completed).is_equal(0)
	assert_int(DebugStart.force_boss(plain, &"no_such_boss")).is_equal(0)
	DebugStart.apply(TestContent.world())  # the legacy content has no plan: nothing happens
