extends GdUnitTestSuite
## The 15-wave game end to end on the SHIPPED data through the real tick order (V5-A; VARIETY_SPEC 2.1, CONTENT 1.1 and
## 10): three acts of five waves with a boss at 5, 10 and 15, every intermission choice answered by a bot (salvage,
## draft, route, boss briefing). Three runs are played once in before():
##  - `boosted`: the balanced bot on the debug build of the card (every unlock, debug_damage_mult x4): a certain, fast
##    victory, whatever the balance of the day is (V5-C tunes the numbers; this suite pins the structure);
##  - `idle`: the bot that does nothing: a certain defeat in act I;
##  - `plain`: the balanced bot on a new profile, no boost: it must end clean; whether it wins is the balance task's
##    business (tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20 plays the same run for seed 1).
## The legacy five scripted waves keep their suite in test_full_run.gd.

const SEED: int = 1
const BOOST: float = 4.0
const WAVES: int = 15
const BOSS_WAVES: Array[int] = [5, 10, 15]
## Types that only the plan sends (no boss script, split or event adds one): their kills are exactly the plan's counts.
const PLAN_ONLY: Array[int] = [
	Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER, Ids.EN_BURSTER, Ids.EN_SPITTER, Ids.EN_SPLITTER, Ids.EN_SHIELDBEARER,
	Ids.EN_JAMMER,
]

var content: ContentSet
var boosted: HarnessReport
var idle: HarnessReport
var plain: HarnessReport


func before() -> void:
	content = HarnessKit.shipped()
	boosted = SimHarness.run(HarnessKit.debug_config(content, SEED, BOOST), PolicyBot.Policy.BALANCED, 0)
	idle = SimHarness.run(HarnessKit.config(content, SEED), PolicyBot.Policy.NONE, 0)
	plain = SimHarness.run(HarnessKit.config(content, SEED), PolicyBot.Policy.BALANCED, 0)
	for r: HarnessReport in [boosted, idle, plain]:
		print("CAMPAIGN %s seed=%d result=%s waves=%d/%d ticks=%d combat_s=%.1f core=%d/%d data=%d death_wave=%d" % [
			PolicyBot.NAMES[r.policy], r.run_seed, r.result_name(), r.waves_completed, r.wave_total, r.ticks,
			float(r.combat_ticks) / float(SimWorld.TICK_RATE), floori(r.core_hp), floori(r.core_max_hp), r.data, r.death_wave])


func _kinds(r: HarnessReport) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	for c: SimCommand in r.log.entries:
		var n: int = out.get(c.kind, 0)
		out[c.kind] = n + 1
	return out


func test_the_shipped_run_is_three_acts_of_five_waves_with_a_boss_at_the_end_of_each() -> void:
	var plan: RunPlan = boosted.world.plan
	assert_object(plan).is_not_null()
	assert_int(plan.wave_count()).is_equal(WAVES)
	assert_int(PhaseSystem.wave_count(boosted.world)).is_equal(WAVES)
	assert_int(content.run.acts.size()).is_equal(3)
	for wave_number: int in range(1, WAVES + 1):
		var pw: PlannedWave = plan.wave(wave_number)
		assert_int(pw.act).is_equal(1 + floori(float(wave_number - 1) / 5.0))
		assert_bool(pw.is_boss).is_equal(BOSS_WAVES.has(wave_number))
		var options: int = 1 if wave_number == 1 or pw.is_boss else 2  # the opener and the boss waves have no route choice
		assert_int(pw.options.size()).is_equal(options)
	assert_bool(plan.boss_ids[0] == Ids.EN_BROOD_CARRIER or plan.boss_ids[0] == Ids.EN_LANCE_PLATFORM).is_true()
	assert_bool(plan.boss_ids[1] == Ids.EN_AEGIS_ARRAY or plan.boss_ids[1] == Ids.EN_TREMOR_RIG).is_true()
	assert_int(plan.boss_ids[2]).is_equal(Ids.EN_HULK)
	assert_int(plan.boss_variant).is_between(0, content.run.hulk_variants.size() - 1)
	assert_bool(content.mission.shop_enabled).is_false()
	assert_int(boosted.world.purchase_block_reason(Ids.UP_DAMAGE)).is_equal(Reason.Id.SHOP_CLOSED)


func test_the_debug_build_wins_all_fifteen_waves() -> void:
	assert_int(boosted.result).is_equal(RunResult.Id.VICTORY)
	assert_int(boosted.waves_completed).is_equal(WAVES)
	assert_float(boosted.core_hp).is_greater(0.0)
	assert_bool(boosted.stalled).is_false()
	assert_int(boosted.death_wave).is_equal(0)
	assert_int(boosted.world.stats.act_reached).is_equal(3)
	assert_array(Array(boosted.world.stats.boss_ids)).is_equal(Array(boosted.world.plan.boss_ids))  # one boss per act, the plan's
	for boss_index: int in boosted.world.plan.boss_ids:
		assert_int(boosted.world.stats.kills_by_type[boss_index]).is_greater_equal(1)
	for act: int in 3:
		assert_float(boosted.act_end_core[act]).is_between(0.0, 1.0)  # every act was cleared
	for wave_number: int in range(1, WAVES + 1):
		assert_float(boosted.wave_seconds(wave_number)).is_greater(0.0)


func test_a_run_that_drafts_nothing_is_defeated_in_act_one() -> void:
	assert_int(idle.result).is_equal(RunResult.Id.DEFEAT)
	assert_float(idle.core_hp).is_equal(0.0)
	assert_int(idle.death_wave).is_between(2, 5)  # scorecard S6: `none` always falls in act I
	assert_int(idle.death_act).is_equal(1)
	assert_int(idle.waves_completed).is_less(5)
	for stacks: int in idle.world.draft.stacks:
		assert_int(stacks).is_equal(0)  # it skipped every draft
	assert_int(idle.world.arsenal.slot_weapon[1]).is_equal(-1)  # and scrapped every crate
	var kinds: Dictionary[int, int] = _kinds(idle)
	assert_bool(kinds.has(SimCommand.Kind.PICK_DIRECTIVE)).is_false()
	assert_bool(kinds.has(SimCommand.Kind.ABILITY)).is_false()
	assert_bool(kinds.has(SimCommand.Kind.PURCHASE)).is_false()
	assert_int(kinds.get(SimCommand.Kind.SKIP_DRAFT, 0)).is_equal(idle.waves_completed)


func test_the_plain_balanced_run_ends_clean_whatever_its_result() -> void:
	assert_bool(plain.result == RunResult.Id.VICTORY or plain.result == RunResult.Id.DEFEAT).is_true()
	assert_bool(plain.stalled).is_false()
	assert_bool(plain.timed_out).is_false()
	assert_str("; ".join(plain.violations)).is_empty()
	if plain.is_victory():
		assert_int(plain.waves_completed).is_equal(WAVES)
	else:
		assert_int(plain.death_wave).is_equal(plain.waves_completed + 1)
		assert_int(plain.death_wave).is_greater_equal(3)  # scorecard S8: the reference player is never beaten before wave 3


func test_every_intermission_choice_was_answered() -> void:
	var kinds: Dictionary[int, int] = _kinds(boosted)
	assert_int(kinds.get(SimCommand.Kind.PICK_ROUTE, 0)).is_equal(11)  # before waves 2 to 4, 6 to 9 and 11 to 14
	assert_int(kinds.get(SimCommand.Kind.SKIP_INTERMISSION, 0)).is_greater_equal(3)  # CONTINUE on the three boss briefings
	assert_int(kinds.get(SimCommand.Kind.PICK_DIRECTIVE, 0)).is_greater_equal(14)  # one draft after each of waves 1 to 14
	assert_int(kinds.get(SimCommand.Kind.SALVAGE, 0)).is_greater_equal(3)  # the guaranteed crate and the two boss crates
	var choices: Array = Array(boosted.world.stats.route_choices)
	for wave_number: int in range(2, WAVES):
		if not BOSS_WAVES.has(wave_number):
			assert_int(choices[wave_number]).is_between(0, 1)
	for wave_number: int in BOSS_WAVES:
		assert_int(choices[wave_number]).is_equal(-1)  # no route into a boss wave
	assert_int(boosted.world.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	var held: int = 0
	for stacks: int in boosted.world.draft.stacks:
		held += stacks
	assert_int(held).is_greater_equal(14)


func test_the_crates_bring_a_second_weapon() -> void:
	# the guaranteed crate after wave 2 (CONTENT 7.1): every run has a second weapon by wave 3, also on a new profile
	for r: HarnessReport in [boosted, plain]:
		assert_int(r.world.arsenal.slot_weapon[0]).is_greater_equal(0)
		if r.waves_completed >= 2:
			assert_int(r.world.arsenal.slot_weapon[1]).is_greater(0)
			assert_int(r.world.stats.crates_secured).is_greater_equal(1)
			assert_int(r.world.stats.weapons.size()).is_greater_equal(2)
	assert_int(boosted.world.stats.crates_secured).is_greater_equal(3)  # and the boss crates of acts I and II
	# a new profile's crates never hold a weapon the Archive gates
	for weapon_index: int in plain.world.stats.weapons:
		var def: WeaponDef = content.weapons[weapon_index]
		assert_bool(weapon_index == Ids.WP_PISTOL or SalvageSystem.in_pool(plain.world, def)).is_true()
	assert_bool(plain.world.stats.weapons.has(Ids.WP_ARC_PROJECTOR)).is_false()


func test_no_run_breaks_an_invariant_and_the_caps_hold() -> void:
	for r: HarnessReport in [boosted, idle, plain]:
		assert_str("; ".join(r.violations)).is_empty()
		assert_bool(r.timed_out).is_false()
		assert_int(r.ticks).is_less(SimHarness.VARIETY_MAX_TICKS)
		for wave_peak: int in r.world.stats.peak_alive_by_wave:
			assert_int(wave_peak).is_less_equal(content.mission.enemy_cap + 8 + content.mission.swarm_cap)
		for n: int in r.peak_minis:
			assert_int(n).is_less_equal(content.mission.swarm_cap)
		assert_int(r.max_blasts).is_less_equal(content.run.max_blasts_per_tick + 8)  # landed hits plus the blasts of weapons
		assert_int(r.world.enemies.high_water).is_less_equal(r.world.enemies.capacity)


func test_what_the_chosen_routes_showed_is_what_spawned_and_died() -> void:
	# A victory killed everything. Per type, the kills are at least the group counts of the option chosen for each wave;
	# for the types that only the plan sends they are exactly that (bosses, splits and events add motes, shards, pylons,
	# borers and reclaimers on top).
	var w: SimWorld = boosted.world
	var planned: PackedInt32Array = PackedInt32Array()
	planned.resize(content.enemies.size())
	for wave_number: int in range(1, w.plan.wave_count() + 1):
		for g: SpawnGroupDef in w.plan.option(wave_number).groups:
			planned[g.enemy_index] += g.count
	for type_index: int in content.enemies.size():
		assert_int(w.stats.kills_by_type[type_index]).is_greater_equal(planned[type_index])
	for type_index: int in PLAN_ONLY:
		assert_int(w.stats.kills_by_type[type_index]).override_failure_message(
			"%s: killed %d, planned %d" % [content.enemies[type_index].id, w.stats.kills_by_type[type_index], planned[type_index]]
		).is_equal(planned[type_index])
	assert_int(w.stats.kills_by_type[Ids.EN_MOTE]).is_greater(0)  # minis were in the run
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.boss_store_index()).is_equal(-1)
	assert_int(boosted.spawned).is_equal(w.next_enemy_id - 1)


func test_scrap_balances_without_the_shop() -> void:
	for r: HarnessReport in [boosted, idle, plain]:
		assert_int(r.purchases).is_equal(0)
		assert_int(r.world.scrap).is_equal(r.scrap_earned - r.scrap_spent)


func test_the_reward_is_the_data_table_of_content_10() -> void:
	var run: RunDef = content.run
	var win: RunSummary = boosted.world.summary("run_a")
	assert_int(win.result).is_equal(RunResult.Id.VICTORY)
	assert_int(win.act_reached).is_equal(3)
	var banked: int = boosted.world.stats.data
	var base: int = WAVES * run.reward_per_wave + run.reward_boss_by_act[0] + run.reward_boss_by_act[1]
	assert_int(base).is_equal(165)  # 15 x 6 + 30 + 45
	assert_int(banked).is_greater_equal(base)  # plus 15 for every `rw_data` route it cleared and the data_siphon it held
	assert_int((banked - base) % 1).is_equal(0)
	var victory_part: int = run.reward_victory_base + floori(float(run.reward_victory_core_bonus) * boosted.core_hp / boosted.core_max_hp)
	assert_int(victory_part).is_between(100, 150)
	assert_int(win.data_reward).is_equal(banked + victory_part)
	assert_int(boosted.data).is_equal(win.data_reward)  # what the harness and the scorecard read
	var loss: RunSummary = idle.world.summary("run_b")
	assert_int(loss.result).is_equal(RunResult.Id.DEFEAT)
	assert_int(loss.data_reward).is_equal(run.reward_per_wave * idle.waves_completed)  # route A pays no Data and nothing was drafted
	assert_int(loss.data_reward).is_equal(idle.world.stats.data)
	assert_int(loss.act_reached).is_equal(1)


func test_a_repeat_run_starts_clean() -> void:
	# No state survives between runs: the same seed after three other runs plays the identical game.
	var again: HarnessReport = SimHarness.run(HarnessKit.config(content, SEED), PolicyBot.Policy.NONE, 0)
	assert_str(again.state_hash).is_equal(idle.state_hash)
	assert_int(again.event_hash).is_equal(idle.event_hash)
	assert_int(again.ticks).is_equal(idle.ticks)


func test_the_boost_makes_the_run_shorter_than_the_design_length() -> void:
	# The design length of a win is 780 to 1,020 s of combat (scorecard S16); the boosted run only has to be a full run
	# that is faster than that, so the suite stays quick. The real lengths are measured by tools\sim_run.ps1.
	assert_int(boosted.combat_ticks).is_less(1020 * SimWorld.TICK_RATE)
	assert_int(boosted.combat_ticks).is_greater(WAVES * 5 * SimWorld.TICK_RATE)
	assert_int(boosted.ticks).is_greater(boosted.combat_ticks)
