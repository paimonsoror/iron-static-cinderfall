extends GdUnitTestSuite
## V4-L: the rules every boss shares (VARIETY_SPEC 6): pools and the Node 9 variant come from the plan, one script at a
## time, no attack above 20% of the core, nothing on the legacy content, a neutral state when no boss lives.


func _hash(state: BossState) -> String:
	var h: StateHasher = StateHasher.new()
	state.hash_into(h)
	return h.finish()


func _plan_hash(plan: RunPlan) -> String:
	var h: StateHasher = StateHasher.new()
	plan.hash_into(h)
	return h.finish()


func test_the_plan_draws_each_act_boss_from_its_pool_and_one_of_three_variants() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	var seen: Dictionary[int, bool] = {}
	var variants: Dictionary[int, bool] = {}
	for run_seed: int in range(1, 41):
		var plan: RunPlan = RunPlanSystem.build_for(content, run_seed)
		assert_int(plan.boss_ids.size()).is_equal(3)
		assert_bool([Ids.EN_BROOD_CARRIER, Ids.EN_LANCE_PLATFORM].has(plan.boss_ids[0])).is_true()
		assert_bool([Ids.EN_AEGIS_ARRAY, Ids.EN_TREMOR_RIG].has(plan.boss_ids[1])).is_true()
		assert_int(plan.boss_ids[2]).is_equal(Ids.EN_HULK)
		assert_int(plan.boss_variant).is_between(0, 2)
		for boss_type: int in plan.boss_ids:
			seen[boss_type] = true
		variants[plan.boss_variant] = true
		assert_str(_plan_hash(RunPlanSystem.build_for(content, run_seed))).is_equal(_plan_hash(plan))
	assert_int(seen.size()).is_equal(5)  # both of act I, both of act II, Node 9
	assert_int(variants.size()).is_equal(3)


func test_the_boss_wave_spawns_the_boss_of_the_plan_and_its_script_adopts_it() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	var seen: Dictionary[int, bool] = {}
	for run_seed: int in range(1, 13):
		var w: SimWorld = VarietyLKit.world(run_seed, content)
		w.wave = 5
		VarietyLKit.begin_tick(w)
		SpawnSystem.begin_wave(w, 5)
		SpawnSystem.step(w)
		var spawned: Array[SimEvent] = VarietyLKit.events_of(w, SimEventKind.Id.BOSS_SPAWNED)
		assert_int(spawned.size()).is_equal(1)
		if spawned.is_empty():
			continue
		assert_int(spawned[0].b).is_equal(w.plan.boss_ids[0])
		assert_int(w.boss.boss_id).is_equal(spawned[0].a)
		assert_int(w.boss.boss_type).is_equal(w.plan.boss_ids[0])
		assert_int(w.boss.phase_count).is_equal(BossSystem.phase_count(w.plan.boss_ids[0]))
		assert_int(w.boss.variant).is_equal(BossState.NO_VARIANT)
		seen[w.boss.boss_type] = true
	assert_int(seen.size()).is_equal(2)


func test_the_node_9_of_the_last_act_takes_the_variant_of_the_plan() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	for run_seed: int in range(1, 7):
		var w: SimWorld = VarietyLKit.world(run_seed, content)
		w.phase_state.act = 3
		VarietyLKit.place(w, Ids.EN_HULK)
		assert_int(w.boss.variant).is_equal(w.plan.boss_variant)
		assert_str(String(BossSiegeHulk.variant_id(w))).is_equal(String(content.run.hulk_variants[w.plan.boss_variant]))


func test_no_boss_attack_removes_more_than_20_percent_of_the_core() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	var core_max: float = VarietyLKit.world(1, content).core_max_hp
	assert_float(core_max).is_equal(1000.0)
	for b: BossDef in content.bosses:
		var act: ActDef = content.run.act(b.pool_act)
		var hit: float = content.enemies[b.enemy_index].core_damage * act.core_dmg_mult
		assert_float(hit).override_failure_message("%s hits for %s" % [b.id, hit]).is_less_equal(0.2 * core_max)
	# The scripted attacks (hatch, stomp, breach, charge, redeploy) deal no core damage themselves: the timeline test
	# of each boss asserts that no CORE_HIT comes from them.


func test_phase_pips_per_boss_type() -> void:
	assert_int(BossSystem.phase_count(Ids.EN_HULK)).is_equal(2)
	assert_int(BossSystem.phase_count(Ids.EN_BROOD_CARRIER)).is_equal(2)
	assert_int(BossSystem.phase_count(Ids.EN_LANCE_PLATFORM)).is_equal(1)
	assert_int(BossSystem.phase_count(Ids.EN_AEGIS_ARRAY)).is_equal(4)
	assert_int(BossSystem.phase_count(Ids.EN_TREMOR_RIG)).is_equal(3)
	assert_int(BossSystem.phase_count(Ids.EN_SKITTER)).is_equal(1)


func test_the_legacy_content_has_no_boss_script() -> void:
	var w: SimWorld = TestContent.world()
	w.phase = GameState.Id.SPAWNING
	var neutral: String = _hash(BossState.new())
	var i: int = w.spawn_enemy(Ids.EN_HULK, 8.0, 3.0)
	w.enemies.hp[i] = 1.0
	for _n: int in 50:
		VarietyLKit.tick(w)
	assert_str(_hash(w.boss)).is_equal(neutral)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_PHASE).size()).is_equal(0)
	assert_float(BossSystem.armor_of(w, i, 12.0)).is_equal(12.0)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)


func test_one_boss_is_scripted_at_a_time_and_its_death_returns_the_state_to_neutral() -> void:
	var w: SimWorld = VarietyLKit.world()
	var neutral: String = _hash(w.boss)
	assert_str(neutral).is_equal(_hash(BossState.new()))
	var first: int = VarietyLKit.place(w, Ids.EN_TREMOR_RIG)
	var second: int = VarietyLKit.place(w, Ids.EN_BROOD_CARRIER, 6.0, 0.0)
	assert_int(w.boss.boss_id).is_equal(w.enemies.id[first])
	VarietyLKit.run_to(w, 520)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_STOMP)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal([])  # the second body has no script
	w.kill_enemy(first, DamageSource.Id.WARDEN)
	VarietyLKit.tick(w)
	assert_str(_hash(w.boss)).is_equal(neutral)
	assert_int(w.enemies.alive[second]).is_equal(1)
	VarietyLKit.run_to(w, 1300)
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)  # the announced stomp died with the rig


func test_the_script_holds_outside_combat() -> void:
	var w: SimWorld = VarietyLKit.world()
	VarietyLKit.place(w, Ids.EN_BROOD_CARRIER)
	VarietyLKit.run_to(w, 100)
	w.phase = GameState.Id.INTERMISSION
	VarietyLKit.run_to(w, 400)
	assert_int(w.boss.timers[BossBroodCarrier.T_CLOCK]).is_equal(100)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)


func test_every_boss_body_is_a_boss_and_never_pushed() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	for b: BossDef in content.bosses:
		var def: EnemyDef = content.enemies[b.enemy_index]
		assert_bool(def.is_boss).is_true()
		assert_float(def.separation_weight).is_equal(0.0)
		assert_bool(def.is_mini()).is_false()
