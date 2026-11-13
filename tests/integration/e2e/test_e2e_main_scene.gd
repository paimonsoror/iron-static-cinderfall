extends GdUnitTestSuite
## End to end through the real `scenes/main.tscn` and the real `Game` autoload (TEST_PLAN "Integration"): a fresh
## profile, `--autoplay=balanced --seed=1` on the shipped game data (the generated slice run: four waves and the boss
## wave, every intermission choice answered by the bot), VICTORY, the profile on disk updated exactly once, and a
## relaunch (a second Save manager reading the same file system) showing the same totals. The run is played once in
## before(); the tests read its outcome.

var _m: IntegrationMain
var _frames: int = 0


func before() -> void:
	_m = IntegrationMain.boot(self, PackedStringArray(["--autoplay=balanced", "--seed=1", "--mute", "--debug-perf"]))
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


func test_balanced_autoplay_through_the_main_scene_wins_and_shows_the_results() -> void:
	assert_int(_frames).is_greater(0)
	assert_int(Game.state()).is_equal(GameState.Id.VICTORY)
	assert_int(_m.rc().sim.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(_m.rc().sim.waves_completed).is_equal(5)
	assert_int(_m.rc().api.wave_count()).is_equal(5)
	assert_object(_m.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(Game.hud).is_null()  # the HUD would be drawn above the results
	assert_int(_m.main.get_node("UI/HudRoot").get_child_count()).is_equal(0)  # and no choice overlay is left
	assert_float(_m.rc().sim.core_hp).is_greater(0.0)


func test_five_waves_and_the_boss_complete_every_hostile_dies_once_and_the_caps_hold() -> void:
	var content: ContentSet = Game.content
	var summary: RunSummary = Game.last_summary
	var sim: SimWorld = _m.rc().sim
	var scheduled: int = 0
	for wave_number: int in range(1, sim.plan.wave_count() + 1):
		scheduled += sim.plan.option(wave_number).total_count()
	var kills: int = 0
	for n: int in summary.kills_by_type:
		kills += n
	assert_int(kills).is_equal(scheduled)  # A07: every hostile of the chosen routes, the Hulk and its escorts included, died
	assert_int(summary.kills_by_type[Ids.EN_HULK]).is_equal(1)
	assert_int(_m.events_log.count(&"boss_spawned")).is_equal(1)
	assert_int(_m.events_log.count(&"wave_started")).is_equal(5)
	assert_int(_m.events_log.count(&"wave_cleared")).is_equal(5)
	assert_int(_m.events_log.count(&"intermission_started")).is_equal(4)
	assert_int(_m.events_log.count(&"enemy_spawned")).is_equal(scheduled)
	assert_int(_m.events_log.count(&"enemy_killed")).is_equal(scheduled)
	assert_int(_m.events_log.count(&"run_finished")).is_equal(1)
	assert_int(_m.events_log.count(&"act_started")).is_equal(1)
	assert_int(_m.events_log.count(&"route_picked")).is_equal(3)  # before waves 2, 3 and 4
	assert_int(_m.events_log.count(&"directive_picked")).is_greater_equal(4)
	assert_int(_m.events_log.count(&"salvage_offered")).is_greater_equal(1)  # the guaranteed crate after wave 2
	assert_int(_m.peak_alive).is_less_equal(content.mission.enemy_cap + content.mission.swarm_cap)  # A06
	assert_int(_m.peak_alive).is_greater(10)
	assert_int(sim.alive_count()).is_equal(0)
	assert_int(_m.rc().api.pending_spawn_count()).is_equal(0)  # nothing was left waiting behind the caps
	assert_int(_m.rc().api.awaiting()).is_equal(RunApi.AWAIT_NONE)


func test_the_profile_on_disk_was_updated_once_with_the_run_reward() -> void:
	var summary: RunSummary = Game.last_summary
	assert_int(summary.data_reward).is_equal(Formulas.data_reward(RunResult.Id.VICTORY, 5, float(summary.core_hp), Game.content.mission))
	# one write per first-run hint that was shown (each marks the profile), and exactly one for the grant
	assert_int(_m.fs.main_replacements).is_equal(Save.profile.hints_seen.size() + 1)
	assert_int(_m.fs.tmp_writes).is_equal(_m.fs.main_replacements)
	assert_bool(GameRewards.flush_pending).is_false()
	var disk: Profile = _m.fs.stored_profile()
	# a first victory also pays the one-time milestones of the Archive (V4-M RewardLedger): the run's Data plus that total
	var milestone_data: int = Save.last_reward.get("milestone_data", 0)
	assert_int(disk.data).is_equal(summary.data_reward + milestone_data)
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
	assert_int(again.data).is_greater(100)
	assert_bool(again.awarded_run_ids.has(_m.rc().run_id)).is_true()
