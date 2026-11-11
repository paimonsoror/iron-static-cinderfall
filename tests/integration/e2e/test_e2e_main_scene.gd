extends GdUnitTestSuite
## End to end through the real `scenes/main.tscn` and the real `Game` autoload (TEST_PLAN "Integration"): a fresh
## profile, `--autoplay=greedy --seed=1` on the tuned game data, VICTORY, the profile on disk updated exactly once, and a
## relaunch (a second Save manager reading the same file system) showing the same totals. The run is played once in
## before(); the tests read its outcome.

var _m: IntegrationMain
var _frames: int = 0


func before() -> void:
	_m = IntegrationMain.boot(self, PackedStringArray(["--autoplay=greedy", "--seed=1", "--mute", "--debug-perf"]))
	_frames = _m.play_to_the_end(60000)


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
	assert_object(_m.find_in("DebugRoot", &"PerfHud")).is_not_null()  # --debug-perf


func test_greedy_autoplay_through_the_main_scene_wins_and_shows_the_results() -> void:
	assert_int(_frames).is_greater(0)
	assert_int(Game.state()).is_equal(GameState.Id.VICTORY)
	assert_int(_m.rc().sim.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(_m.rc().sim.waves_completed).is_equal(5)
	assert_object(_m.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(Game.hud).is_null()  # the HUD would be drawn above the results
	var fraction: float = _m.rc().sim.core_hp / _m.rc().sim.core_max_hp
	assert_float(fraction).is_between(0.3, 0.8)  # GDD 8.4: the greedy bot wins with 30% to 80% of the core


func test_five_waves_and_the_boss_complete_every_hostile_dies_once_and_the_cap_holds() -> void:
	var content: ContentSet = Game.content
	var summary: RunSummary = Game.last_summary
	var scheduled: int = 0
	var scrap: int = 0
	for wave: WaveDef in content.waves:
		scheduled += wave.total_count()
	var kills: int = 0
	for type_index: int in Ids.ENEMIES.size():
		kills += summary.kills_by_type[type_index]
		scrap += summary.kills_by_type[type_index] * content.enemies[type_index].scrap
	assert_int(kills).is_equal(scheduled)  # A07: every scheduled hostile, the Hulk and its escorts included, died
	assert_int(summary.kills_by_type[Ids.EN_HULK]).is_equal(1)
	assert_int(summary.scrap_earned).is_equal(scrap)  # A09: Scrap came from kills only, once per kill
	assert_int(_m.events_log.count(&"boss_spawned")).is_equal(1)
	assert_int(_m.events_log.count(&"wave_started")).is_equal(5)
	assert_int(_m.events_log.count(&"wave_cleared")).is_equal(5)
	assert_int(_m.events_log.count(&"intermission_started")).is_equal(4)
	assert_int(_m.events_log.count(&"enemy_killed")).is_equal(scheduled)
	assert_int(_m.events_log.count(&"run_finished")).is_equal(1)
	assert_int(_m.peak_alive).is_between(45, content.mission.enemy_cap)  # A06: wave 5 fills the field, never past 50
	assert_int(_m.rc().sim.alive_count()).is_equal(0)
	assert_int(_m.rc().api.pending_spawn_count()).is_equal(0)  # nothing was left waiting behind the cap


func test_the_profile_on_disk_was_updated_once_with_the_run_reward() -> void:
	var summary: RunSummary = Game.last_summary
	assert_int(summary.data_reward).is_equal(100 + floori(float(summary.core_hp) / 20.0))  # GDD 8.2
	# one write per first-run hint that was shown (each marks the profile), and exactly one for the grant
	assert_int(_m.fs.main_replacements).is_equal(Save.profile.hints_seen.size() + 1)
	assert_int(_m.fs.tmp_writes).is_equal(_m.fs.main_replacements)
	assert_bool(GameRewards.flush_pending).is_false()
	var disk: Profile = _m.fs.stored_profile()
	assert_int(disk.data).is_equal(summary.data_reward)
	assert_int(disk.runs_played).is_equal(1)
	assert_int(disk.missions_completed).is_equal(1)
	assert_int(disk.best_core_hp).is_equal(summary.core_hp)
	assert_array(Array(disk.awarded_run_ids)).is_equal([_m.rc().run_id])
	assert_array(IntegrationKit.totals(disk)).is_equal(IntegrationKit.totals(Save.profile))


func test_a_relaunch_shows_the_same_totals() -> void:
	var launched: Node = IntegrationKit.relaunch(_m.fs)
	auto_free(launched)
	var again: Profile = IntegrationKit.profile_of(launched)
	assert_int(launched.get(&"last_load_status")).is_equal(Save.LoadStatus.OK)
	assert_array(IntegrationKit.totals(again)).is_equal(IntegrationKit.totals(Save.profile))
	assert_int(again.data).is_greater(100)
	assert_bool(again.awarded_run_ids.has(_m.rc().run_id)).is_true()
