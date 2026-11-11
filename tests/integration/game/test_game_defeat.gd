extends GdUnitTestSuite
## A run that buys nothing and has no bot (--autoplay=none behaviour) is lost, and the loss pays 10 per cleared wave.

var _h: GameHarness


func before_test() -> void:
	GameRunKit.fresh_save()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null
	GameRunKit.reset_save()


func _fragile_core(c: ContentSet) -> void:
	c.mission.core_max_hp = 50.0


func test_a_run_with_no_purchases_and_no_bot_is_lost_and_pays_10_per_cleared_wave() -> void:
	var sig_log: GameSignalLog = GameSignalLog.new()
	sig_log.attach()
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(1))
	assert_int(GameRunKit.run_to_end(rc, 90000)).is_greater(0)
	sig_log.detach()
	assert_int(rc.sim.result()).is_equal(RunResult.Id.DEFEAT)
	var waves: int = rc.sim.waves_completed
	assert_int(waves).is_less(rc.sim.content.waves.size())
	assert_int(rc.sim.command_log.entries.size()).is_equal(0)  # it really bought and used nothing
	assert_int(Save.profile.data).is_equal(10 * waves)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(0)
	assert_int(Save.profile.best_core_hp).is_equal(0)
	assert_bool(rc.reward_granted).is_true()
	assert_array(sig_log.first_args(&"run_finished")).is_equal([RunResult.Id.DEFEAT, "run-a"])
	assert_int(sig_log.count(&"run_finished")).is_equal(1)
	assert_int(sig_log.index_of(&"profile_changed")).is_less(sig_log.index_of(&"run_finished"))
	# the grant path again (a replayed results screen, a second finish): nothing more
	assert_bool(GameRewards.grant(rc.summary)).is_false()
	rc.finalize()
	assert_int(Save.profile.data).is_equal(10 * waves)
	assert_int(Save.profile.runs_played).is_equal(1)


func test_game_shows_the_defeat_results_and_refuses_to_pause_when_the_core_falls() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=4"]), _fragile_core)
	_h.boot()
	assert_int(_h.frames_until_over(30000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.DEFEAT)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_int(_h.summary().result).is_equal(RunResult.Id.DEFEAT)
	assert_int(Save.profile.data).is_equal(10 * _h.summary().waves_completed)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_bool(Save.profile.awarded_run_ids.has(_h.rc().run_id)).is_true()
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	_h.call_game(&"pause_run")  # pausing is not possible once the run is lost
	assert_int(_h.state()).is_equal(GameState.Id.DEFEAT)
	assert_bool(_h.rc().paused).is_false()
