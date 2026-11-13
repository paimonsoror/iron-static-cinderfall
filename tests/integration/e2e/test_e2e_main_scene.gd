extends GdUnitTestSuite
## End to end through the real `scenes/main.tscn` and the real `Game` autoload (TEST_PLAN "Integration"; WORK_PLAN card
## V5-A): a fresh profile, the 15-wave game on the shipped data played by `--autoplay=balanced --seed=1` on the debug
## build of the card (`--unlock=all` and debug_damage_mult x4: a fast and certain victory, whatever the balance of the
## day is), every intermission choice answered by the bot, VICTORY, the profile on disk updated exactly once, and a
## relaunch (a second Save manager reading the same file system) showing the same totals. The run is played once in
## before(); the tests read its outcome.

const WAVES: int = 15

var _m: IntegrationMain
var _frames: int = 0


func before() -> void:
	Game.sim_config_hook = IntegrationKit.boost_x4  # before the scene boots: --autoplay deploys at once
	_m = IntegrationMain.boot(self, PackedStringArray(["--autoplay=balanced", "--seed=1", "--unlock=all", "--mute", "--debug-perf"]))
	_frames = _m.play_to_the_end(SimHarness.VARIETY_MAX_TICKS)


func after() -> void:
	if _m != null:
		_m.shutdown()
		_m = null


func test_main_scene_boots_the_game_and_builds_the_runtime_tree() -> void:
	for node_name: String in ["World", "RunHost", "MobileShell", "UI"]:
		assert_object(_m.main.get_node_or_null(node_name)).is_not_null()
	for layer: String in ["ScreenRoot", "HudRoot", "OverlayRoot", "DebugRoot"]:
		assert_object(_m.main.get_node_or_null("UI/" + layer)).is_not_null()
	assert_object(_m.main.get_node_or_null("World/BattleView")).is_not_null()
	assert_object(_m.main.get_node_or_null("RunHost/RunController")).is_not_null()
	assert_object(_m.main.get_node_or_null("RunHost/RunController/" + GameRunFlow.OVERLAYS_NAME)).is_not_null()
	assert_object(_m.find_in("DebugRoot", &"PerfHud")).is_not_null()  # --debug-perf


func test_the_run_was_launched_with_every_unlock_and_the_damage_boost() -> void:
	var config: SimConfig = _m.rc().sim.config
	assert_int(config.unlocked.size()).is_equal(Game.content.unlocks.size())  # --unlock=all
	assert_float(config.debug_damage_mult).is_equal(4.0)
	assert_bool(config.is_debug()).is_true()
	assert_bool(config.daily).is_false()
	assert_int(_m.rc().sim.arsenal.slot_count).is_equal(ArsenalState.MAX_SLOTS)  # the third sling is one of the unlocks


func test_balanced_autoplay_through_the_main_scene_wins_the_fifteen_waves_and_shows_the_results() -> void:
	assert_int(_frames).is_greater(0)
	assert_int(Game.state()).is_equal(GameState.Id.VICTORY)
	assert_int(_m.rc().sim.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(_m.rc().sim.waves_completed).is_equal(WAVES)
	assert_int(_m.rc().api.wave_count()).is_equal(WAVES)
	assert_int(_m.rc().api.act()).is_equal(3)
	assert_object(_m.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(Game.hud).is_null()  # the HUD would be drawn above the results
	assert_int(_m.main.get_node("UI/HudRoot").get_child_count()).is_equal(0)  # and no choice overlay is left
	assert_float(_m.rc().sim.core_hp).is_greater(0.0)


func test_three_acts_complete_every_hostile_dies_once_and_the_caps_hold() -> void:
	var content: ContentSet = Game.content
	var summary: RunSummary = Game.last_summary
	var sim: SimWorld = _m.rc().sim
	var scheduled: int = 0
	for wave_number: int in range(1, sim.plan.wave_count() + 1):
		scheduled += sim.plan.option(wave_number).total_count()
	var kills: int = 0
	for n: int in summary.kills_by_type:
		kills += n
	var spawned: int = _m.events_log.count(&"enemy_spawned")
	assert_int(spawned).is_greater_equal(scheduled)  # the chosen routes, plus what bosses, splits and events sent
	assert_int(spawned).is_equal(sim.next_enemy_id - 1)
	assert_int(kills).is_equal(spawned)  # A07: every hostile died, once
	assert_int(_m.events_log.count(&"enemy_killed")).is_equal(spawned)
	for boss_index: int in sim.plan.boss_ids:
		assert_int(summary.kills_by_type[boss_index]).is_greater_equal(1)
	assert_int(_m.events_log.count(&"boss_spawned")).is_greater_equal(3)  # one per act
	assert_int(_m.events_log.count(&"wave_started")).is_equal(WAVES)
	assert_int(_m.events_log.count(&"wave_cleared")).is_equal(WAVES)
	assert_int(_m.events_log.count(&"intermission_started")).is_equal(WAVES - 1)
	assert_int(_m.events_log.count(&"run_finished")).is_equal(1)
	assert_int(_m.events_log.count(&"act_started")).is_equal(3)
	assert_int(_m.events_log.count(&"route_picked")).is_equal(11)  # before waves 2 to 4, 6 to 9 and 11 to 14
	assert_int(_m.events_log.count(&"directive_picked")).is_greater_equal(WAVES - 1)
	assert_int(_m.events_log.count(&"salvage_offered")).is_greater_equal(3)  # the guaranteed crate and two boss crates
	assert_int(_m.peak_alive).is_less_equal(content.mission.enemy_cap + 8 + content.mission.swarm_cap)  # A06
	assert_int(_m.peak_alive).is_greater(10)
	assert_int(sim.alive_count()).is_equal(0)
	assert_int(_m.rc().api.pending_spawn_count()).is_equal(0)  # nothing was left waiting behind the caps
	assert_int(_m.rc().api.awaiting()).is_equal(RunApi.AWAIT_NONE)


func test_the_profile_on_disk_was_updated_once_with_the_data_table_of_the_run() -> void:
	var summary: RunSummary = Game.last_summary
	var sim: SimWorld = _m.rc().sim
	var run: RunDef = Game.content.run
	assert_int(summary.data_reward).is_equal(sim.data_reward())
	var victory_part: int = run.reward_victory_base + floori(float(run.reward_victory_core_bonus) * sim.core_hp / sim.core_max_hp)
	assert_int(summary.data_reward).is_equal(sim.stats.data + victory_part)  # CONTENT 10
	assert_int(sim.stats.data).is_greater_equal(WAVES * run.reward_per_wave + run.reward_boss_by_act[0] + run.reward_boss_by_act[1])
	# one write per first-run hint that was shown (each marks the profile), and exactly one for the grant
	assert_int(_m.fs.main_replacements).is_equal(Save.profile.hints_seen.size() + 1)
	assert_int(_m.fs.tmp_writes).is_equal(_m.fs.main_replacements)
	assert_bool(GameRewards.flush_pending).is_false()
	var disk: Profile = _m.fs.stored_profile()
	# a debug run (the damage boost) is paid its Data and leaves no trace in the Archive: no milestone, no boss kill
	var milestone_data: int = Save.last_reward.get("milestone_data", -1)
	assert_int(milestone_data).is_equal(0)
	assert_int(disk.data).is_equal(summary.data_reward)
	assert_bool(disk.boss_kills.is_empty()).is_true()
	assert_int(disk.claimed.size()).is_equal(0)
	assert_int(disk.runs_played).is_equal(1)
	assert_int(disk.missions_completed).is_equal(1)
	assert_int(disk.best_core_hp).is_equal(summary.core_hp)
	assert_array(Array(disk.awarded_run_ids)).is_equal([_m.rc().run_id])
	assert_array(IntegrationKit.totals(disk)).is_equal(IntegrationKit.totals(Save.profile))
	assert_bool(RunStore.exists(_m.fs)).is_false()  # the run ended: the run file was deleted


func test_a_relaunch_shows_the_same_totals() -> void:
	var launched: Node = IntegrationKit.relaunch(_m.fs)
	auto_free(launched)
	var again: Profile = IntegrationKit.profile_of(launched)
	assert_int(launched.get(&"last_load_status")).is_equal(Save.LoadStatus.OK)
	assert_array(IntegrationKit.totals(again)).is_equal(IntegrationKit.totals(Save.profile))
	assert_int(again.data).is_greater(265)  # 165 banked on the way and at least 100 for the victory
	assert_bool(again.awarded_run_ids.has(_m.rc().run_id)).is_true()
