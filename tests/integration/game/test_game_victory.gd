extends GdUnitTestSuite
## One full five-wave run through Game with boosted damage and an invulnerable core, no purchases and no bot: it
## still wins, the Data is granted exactly once and saved before anything announces the end (A14, A15). The run is
## played once in before(); the tests only read its outcome. The greedy-bot run waits for W2-D.

var _h: GameHarness


func before() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=3"]))
	_h.game.set(&"sim_config_hook", _boost)
	_h.boot()
	_h.frames_until_over(60000)


func after() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func _boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true


func test_a_boosted_autoplay_run_reaches_victory_with_the_results_screen() -> void:
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_int(_h.rc().sim.result()).is_equal(RunResult.Id.VICTORY)
	assert_int(_h.rc().sim.waves_completed).is_equal(_h.content.waves.size())
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(_h.hud()).is_null()  # the HUD would be drawn above the results
	assert_int(_h.summary().result).is_equal(RunResult.Id.VICTORY)


func test_the_victory_reward_is_100_plus_core_hp_over_20_and_granted_once() -> void:
	var m: MissionDef = _h.content.mission
	var core: float = _h.rc().sim.core_hp
	var expected: int = m.reward_victory_base + floori(core / float(m.reward_core_hp_divisor))
	assert_int(expected).is_equal(100 + floori(core / 20.0))  # the baseline numbers of GDD 8.2
	assert_int(Save.profile.data).is_equal(expected)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(1)
	assert_int(Save.profile.best_core_hp).is_equal(floori(core))
	assert_bool(_h.rc().reward_granted).is_true()
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	# the grant path again (a replayed results screen, a second finish): nothing more
	assert_bool(GameRewards.grant(_h.summary())).is_false()
	assert_bool(_h.rc().finalize()).is_true()  # idempotent: reports the first outcome
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	assert_int(Save.profile.data).is_equal(expected)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(1)


func test_the_data_is_on_disk_before_run_finished_is_announced() -> void:
	var granted_at: int = _h.events_log.index_of(&"profile_changed")
	var finished_at: int = _h.events_log.index_of(&"run_finished")
	assert_int(granted_at).is_greater_equal(0)
	assert_int(finished_at).is_greater(granted_at)
	var saved: Profile = ProfileCodec.decode(_h.fs.read(Save.PATH_MAIN)).profile
	assert_int(saved.data).is_equal(Save.profile.data)
	assert_bool(saved.awarded_run_ids.has(_h.rc().run_id)).is_true()
	assert_bool(GameRewards.flush_pending).is_false()


func test_the_results_screen_gets_the_summary_and_the_grant_flag() -> void:
	var summary: RunSummary = _h.summary()
	assert_int(summary.data_reward).is_equal(Save.profile.data)
	assert_int(summary.waves_completed).is_equal(_h.content.waves.size())
	assert_str(summary.run_id).is_equal(_h.rc().run_id)
	assert_int(summary.run_seed).is_equal(3)
	assert_int(summary.kills_by_type.size()).is_equal(Ids.ENEMIES.size())


func test_the_run_log_shows_no_purchase_and_no_ability() -> void:
	for cmd: SimCommand in _h.rc().sim.command_log.entries:
		assert_int(cmd.kind).is_equal(SimCommand.Kind.SKIP_INTERMISSION)  # only the CONTINUE taps of the harness

