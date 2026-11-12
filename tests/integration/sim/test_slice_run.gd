extends GdUnitTestSuite
## The generated slice run end to end on the SHIPPED data through the real tick order (VARIETY_SPEC 15.2; V3-I): four
## generated waves and the boss wave, with every intermission choice answered by a bot (salvage, draft, route, boss
## briefing). Three runs are played once in before(): the balanced bot on a seed it wins, the bot that does nothing, and
## the balanced bot with debug_damage_mult = 5. The legacy five scripted waves keep their suite in test_full_run.gd.

const WIN_SEED: int = 1  ## `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20`: seed 1 is a victory on the slice data

var content: ContentSet
var balanced: HarnessReport
var idle: HarnessReport
var boosted: HarnessReport


func before() -> void:
	content = HarnessKit.shipped()
	balanced = SimHarness.run(HarnessKit.config(content, WIN_SEED), PolicyBot.Policy.BALANCED, 0)
	idle = SimHarness.run(HarnessKit.config(content, WIN_SEED), PolicyBot.Policy.NONE, 0)
	boosted = SimHarness.run(HarnessKit.config(content, WIN_SEED, 5.0), PolicyBot.Policy.BALANCED, 0)


func _kinds(r: HarnessReport) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	for c: SimCommand in r.log.entries:
		var n: int = out.get(c.kind, 0)
		out[c.kind] = n + 1
	return out


func test_the_shipped_run_is_generated_four_waves_and_a_boss_wave_with_the_shop_closed() -> void:
	var plan: RunPlan = balanced.world.plan
	assert_object(plan).is_not_null()
	assert_int(plan.wave_count()).is_equal(5)
	assert_int(PhaseSystem.wave_count(balanced.world)).is_equal(5)
	for wave_number: int in range(1, 5):
		assert_bool(plan.wave(wave_number).is_boss).is_false()
	assert_bool(plan.wave(5).is_boss).is_true()
	assert_int(plan.wave(1).options.size()).is_equal(1)  # the opener has no route choice
	for wave_number: int in range(2, 5):
		assert_int(plan.wave(wave_number).options.size()).is_equal(2)
	assert_int(plan.boss_ids[0]).is_equal(Ids.EN_HULK)  # the Siege Hulk stands in as the act boss
	assert_bool(content.mission.shop_enabled).is_false()
	assert_int(balanced.world.purchase_block_reason(Ids.UP_DAMAGE)).is_equal(Reason.Id.SHOP_CLOSED)


func test_the_balanced_bot_wins_the_slice() -> void:
	assert_int(balanced.result).is_equal(RunResult.Id.VICTORY)
	assert_int(balanced.waves_completed).is_equal(5)
	assert_float(balanced.core_hp).is_greater(0.0)
	assert_bool(balanced.stalled).is_false()
	assert_int(balanced.boss_kill_tick).is_greater(balanced.boss_spawn_tick)


func test_debug_damage_x5_reaches_victory_faster() -> void:
	assert_int(boosted.result).is_equal(RunResult.Id.VICTORY)
	assert_int(boosted.waves_completed).is_equal(5)
	assert_int(boosted.ticks).is_less(balanced.ticks)


func test_a_run_that_drafts_nothing_is_defeated_before_the_boss_dies() -> void:
	assert_int(idle.result).is_equal(RunResult.Id.DEFEAT)
	assert_float(idle.core_hp).is_equal(0.0)
	assert_int(idle.death_wave).is_between(2, 5)
	assert_int(idle.waves_completed).is_less(5)
	for stacks: int in idle.world.draft.stacks:
		assert_int(stacks).is_equal(0)  # it skipped every draft
	assert_int(idle.world.arsenal.slot_weapon[1]).is_equal(-1)  # and scrapped every crate
	var kinds: Dictionary[int, int] = _kinds(idle)
	assert_bool(kinds.has(SimCommand.Kind.PICK_DIRECTIVE)).is_false()
	assert_bool(kinds.has(SimCommand.Kind.ABILITY)).is_false()
	assert_bool(kinds.has(SimCommand.Kind.PURCHASE)).is_false()
	assert_int(kinds.get(SimCommand.Kind.SKIP_DRAFT, 0)).is_equal(idle.waves_completed)


func test_every_intermission_choice_was_answered() -> void:
	var kinds: Dictionary[int, int] = _kinds(balanced)
	assert_int(kinds.get(SimCommand.Kind.PICK_DIRECTIVE, 0)).is_greater_equal(4)  # one draft after each of waves 1 to 4
	assert_int(kinds.get(SimCommand.Kind.PICK_ROUTE, 0)).is_equal(3)  # before waves 2, 3 and 4
	assert_int(kinds.get(SimCommand.Kind.SALVAGE, 0)).is_greater_equal(1)  # the guaranteed crate after wave 2
	assert_int(kinds.get(SimCommand.Kind.SKIP_INTERMISSION, 0)).is_greater_equal(1)  # CONTINUE on the boss briefing
	assert_array(Array(balanced.world.stats.route_choices).slice(2, 5)).not_contains([-1])
	assert_int(balanced.world.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	var held: int = 0
	for stacks: int in balanced.world.draft.stacks:
		held += stacks
	assert_int(held).is_greater_equal(4)


func test_the_guaranteed_crate_brings_the_arc_projector_into_slot_two() -> void:
	assert_int(balanced.world.arsenal.slot_weapon[0]).is_equal(Ids.WP_PISTOL)
	assert_int(balanced.world.arsenal.slot_weapon[1]).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(balanced.world.stats.crates_secured).is_greater_equal(1)
	assert_bool(balanced.world.stats.weapons.has(Ids.WP_ARC_PROJECTOR)).is_true()


func test_no_run_breaks_an_invariant_and_the_caps_hold() -> void:
	for r: HarnessReport in [balanced, idle, boosted]:
		assert_str("; ".join(r.violations)).is_empty()
		assert_bool(r.timed_out).is_false()
		for wave_peak: int in r.world.stats.peak_alive_by_wave:
			assert_int(wave_peak).is_less_equal(content.mission.enemy_cap + content.mission.swarm_cap)
		assert_int(r.world.enemies.high_water).is_less_equal(r.world.enemies.capacity)


func test_what_the_chosen_routes_showed_is_what_spawned_and_died() -> void:
	# A victory killed everything: per type, the kills are the group counts of the option chosen for each wave.
	for r: HarnessReport in [balanced, boosted]:
		var w: SimWorld = r.world
		var planned: PackedInt32Array = PackedInt32Array()
		planned.resize(content.enemies.size())
		for wave_number: int in range(1, w.plan.wave_count() + 1):
			for g: SpawnGroupDef in w.plan.option(wave_number).groups:
				planned[g.enemy_index] += g.count
		assert_array(Array(w.stats.kills_by_type)).is_equal(Array(planned))
		assert_int(w.stats.kills_by_type[Ids.EN_HULK]).is_equal(1)
		assert_int(w.stats.kills_by_type[Ids.EN_MOTE]).is_greater(0)  # minis were in every run
		assert_int(w.alive_count()).is_equal(0)
		assert_int(w.boss_store_index()).is_equal(-1)


func test_scrap_balances_without_the_shop() -> void:
	for r: HarnessReport in [balanced, idle, boosted]:
		assert_int(r.purchases).is_equal(0)
		assert_int(r.world.scrap).is_equal(r.scrap_earned - r.scrap_spent)


func test_the_reward_formula_follows_the_result() -> void:
	var win: RunSummary = balanced.world.summary("run_a")
	assert_int(win.result).is_equal(RunResult.Id.VICTORY)
	assert_int(win.data_reward).is_equal(Formulas.data_reward(RunResult.Id.VICTORY, 5, balanced.core_hp, content.mission))
	assert_int(win.data_reward).is_greater(0)
	assert_int(win.act_reached).is_equal(1)
	var loss: RunSummary = idle.world.summary("run_b")
	assert_int(loss.result).is_equal(RunResult.Id.DEFEAT)
	assert_int(loss.data_reward).is_equal(Formulas.data_reward(RunResult.Id.DEFEAT, idle.waves_completed, 0.0, content.mission))


func test_a_repeat_run_starts_clean() -> void:
	# No state survives between runs: the same seed after three other runs plays the identical game.
	var again: HarnessReport = SimHarness.run(HarnessKit.config(content, WIN_SEED), PolicyBot.Policy.BALANCED, 0)
	assert_str(again.state_hash).is_equal(balanced.state_hash)
	assert_int(again.event_hash).is_equal(balanced.event_hash)
	assert_int(again.ticks).is_equal(balanced.ticks)


func test_the_runs_are_inside_the_time_limit() -> void:
	for r: HarnessReport in [balanced, idle, boosted]:
		assert_int(r.ticks).is_less(SimHarness.VARIETY_MAX_TICKS)
