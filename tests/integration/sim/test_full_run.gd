extends GdUnitTestSuite
## The LEGACY game: the five scripted waves end to end through the real tick order (TEST_PLAN "Integration"; acceptance
## A06, A07, A09, A14), on the frozen legacy fixture (tests/fixtures/data_baseline: the shop, four enemy types, no run
## plan). The shipped data is a generated run since the variety milestone; its whole-run suite is test_slice_run.gd.
## Three runs are played once in before(): the greedy bot, a bot that buys nothing, and the greedy bot with
## debug_damage_mult = 5.

var content: ContentSet
var greedy: HarnessTally
var idle: HarnessTally
var boosted: HarnessTally


func before() -> void:
	content = TestContent.baseline()
	greedy = HarnessTally.play(HarnessKit.config(content, 1), PolicyBot.Policy.GREEDY)
	idle = HarnessTally.play(HarnessKit.config(content, 1), PolicyBot.Policy.NONE)
	boosted = HarnessTally.play(HarnessKit.config(content, 1, 5.0), PolicyBot.Policy.GREEDY)


func test_the_greedy_bot_wins() -> void:
	assert_int(greedy.world.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(greedy.world.waves_completed).is_equal(5)
	assert_float(greedy.world.core_hp).is_greater(0.0)


func test_debug_damage_x5_reaches_victory() -> void:
	assert_int(boosted.world.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(boosted.world.waves_completed).is_equal(5)


func test_a_run_that_buys_nothing_is_defeated_in_wave_three_or_four() -> void:
	assert_int(idle.world.result()).is_equal(RunResult.Id.DEFEAT)
	assert_int(idle.world.wave).is_between(3, 4)
	assert_int(idle.world.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	assert_int(idle.world.command_log.entries.size()).is_equal(0)
	assert_float(idle.world.core_hp).is_equal(0.0)


func test_no_wave_completes_while_anything_is_alive_or_queued() -> void:
	for t: HarnessTally in [greedy, idle, boosted]:
		assert_str("\n".join(t.problems)).is_empty()


func test_the_cap_of_fifty_is_never_exceeded() -> void:
	for t: HarnessTally in [greedy, idle, boosted]:
		assert_int(t.max_alive).is_less_equal(content.mission.enemy_cap)
		assert_int(t.world.enemies.high_water).is_less_equal(t.world.enemies.capacity)


func test_every_scheduled_enemy_spawns_exactly_once() -> void:
	# Nothing is dropped: per completed wave, spawned == scheduled == the sum of the group counts.
	for wave_number: int in range(1, 6):
		var scheduled: int = content.waves[wave_number - 1].total_count()
		assert_int(greedy.scheduled_by_wave[wave_number]).is_equal(scheduled)
		assert_int(greedy.spawned_by_wave[wave_number]).is_equal(scheduled)
		assert_int(boosted.spawned_by_wave[wave_number]).is_equal(scheduled)
	assert_int(greedy.cleared_waves.size()).is_equal(5)
	assert_array(greedy.cleared_waves).is_equal(PackedInt32Array([1, 2, 3, 4, 5]))


func test_victory_needs_the_boss_and_every_escort_dead() -> void:
	for t: HarnessTally in [greedy, boosted]:
		assert_int(t.world.alive_count()).is_equal(0)
		assert_int(t.kills_by_type[Ids.EN_HULK]).is_equal(1)
		assert_int(t.boss_killed_tick).is_greater(0)
		assert_int(t.boss_killed_tick).is_less_equal(t.finished_tick)
		assert_int(t.world.boss_store_index()).is_equal(-1)
		for type_index: int in 4:
			assert_int(t.kills_by_type[type_index]).is_equal(t.spawned_by_type[type_index])
		assert_int(t.finished.size()).is_equal(1)
		assert_int(t.finished[0].a).is_equal(RunResult.Id.VICTORY)
		assert_int(t.finished[0].b).is_equal(5)


func test_scrap_earned_is_the_sum_of_kill_rewards() -> void:
	for t: HarnessTally in [greedy, idle, boosted]:
		var by_type: int = 0
		for type_index: int in 4:
			by_type += t.kills_by_type[type_index] * content.enemies[type_index].scrap
		assert_int(t.reward_sum).is_equal(by_type)
		assert_int(t.world.stats.scrap_earned).is_equal(by_type)
		assert_int(t.world.scrap).is_equal(by_type - t.world.stats.scrap_spent)
		for type_index: int in 4:
			assert_int(t.world.stats.kills_by_type[type_index]).is_equal(t.kills_by_type[type_index])


func test_no_purchase_is_lost() -> void:
	var t: HarnessTally = greedy
	var purchase_commands: int = 0
	for c: SimCommand in t.world.command_log.entries:
		if c.kind == SimCommand.Kind.PURCHASE:
			purchase_commands += 1
			assert_bool(t.resolved_by_command.has(c.command_id)).is_true()  # every purchase command was answered
	assert_int(t.resolved_by_command.size()).is_greater_equal(purchase_commands)
	assert_int(t.purchase_ok).is_greater(0)
	assert_int(t.level_events).is_equal(t.purchase_ok)
	var levels: int = 0
	for level: int in t.world.upgrade_levels:
		levels += level
	assert_int(levels).is_equal(t.purchase_ok)
	assert_int(t.world.stats.scrap_spent).is_equal(t.price_paid)
	# the greedy bot never asks for something it cannot have: every purchase it sent succeeded
	assert_int(t.purchase_ok).is_equal(purchase_commands)


func test_the_greedy_bot_buys_the_smg_and_both_turrets() -> void:
	assert_int(greedy.world.upgrade_levels[Ids.UP_SMG]).is_equal(1)
	assert_int(greedy.world.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(2)
	assert_int(greedy.world.warden.weapon_index).is_equal(1)


func test_the_reward_formula_follows_the_result() -> void:
	var win: RunSummary = greedy.world.summary("run_a")
	assert_int(win.result).is_equal(RunResult.Id.VICTORY)
	assert_int(win.data_reward).is_equal(100 + floori(greedy.world.core_hp / 20.0))
	assert_int(win.data_reward).is_between(100, 150)
	var loss: RunSummary = idle.world.summary("run_b")
	assert_int(loss.result).is_equal(RunResult.Id.DEFEAT)
	assert_int(loss.data_reward).is_equal(10 * idle.world.waves_completed)


func test_a_repeat_run_starts_clean() -> void:
	# No state survives between runs: the same seed after two other runs plays the identical game.
	var again: HarnessTally = HarnessTally.play(HarnessKit.config(content, 1), PolicyBot.Policy.GREEDY)
	assert_str(again.world.state_hash()).is_equal(greedy.world.state_hash())
	assert_int(again.world.events.event_hash).is_equal(greedy.world.events.event_hash)
	assert_int(again.world.tick).is_equal(greedy.world.tick)


func test_the_run_is_inside_the_time_limit() -> void:
	assert_int(greedy.world.tick).is_less(SimHarness.DEFAULT_MAX_TICKS)
	assert_int(idle.world.tick).is_less(SimHarness.DEFAULT_MAX_TICKS)
	assert_int(boosted.world.tick).is_less(greedy.world.tick)  # five times the damage is faster
