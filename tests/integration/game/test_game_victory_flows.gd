extends GdUnitTestSuite
## What happens after a victory: a failed save is retried, retry starts a fresh run without a second grant, the menu
## button leaves cleanly. One-wave content with a boosted core so every run is over in a couple of seconds.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=3"]), GameHarness.one_wave)
	_h.game.set(&"sim_config_hook", _boost)


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func _boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true


func test_a_failed_flush_at_the_end_is_retried_and_the_grant_survives_a_restart() -> void:
	_h.boot()
	_h.fs.fail_writes = true
	_h.frames_until_over(60000)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_bool(GameRewards.flush_pending).is_true()
	assert_bool(_h.fs.exists(Save.PATH_MAIN)).is_false()  # nothing reached the disk
	var data: int = Save.profile.data
	assert_int(data).is_greater(0)
	_h.fs.fail_writes = false
	_h.game.call(&"goto_menu")  # the next state change retries the flush
	assert_bool(GameRewards.flush_pending).is_false()
	Save.load_profile()  # a restart
	assert_int(Save.profile.data).is_equal(data)
	assert_bool(Save.profile.awarded_run_ids.size() == 1).is_true()


func test_retry_after_victory_starts_a_new_run_and_does_not_grant_again() -> void:
	_h.boot()
	_h.frames_until_over(60000)
	var data: int = Save.profile.data
	var first_id: String = _h.rc().run_id
	(_h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen).retry_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_str(_h.rc().run_id).is_not_equal(first_id)
	assert_int(_h.rc().sim.config.run_seed).is_equal(3)  # --seed stays fixed for a retry
	assert_int(Save.profile.data).is_equal(data)  # starting the run grants nothing
	assert_object(_h.hud()).is_not_null()
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_null()
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(2)
	assert_int(Save.profile.data).is_equal(data * 2)


func test_the_menu_button_on_the_results_returns_to_the_menu_with_the_new_total() -> void:
	_h.boot()
	_h.frames_until_over(60000)
	var data: int = Save.profile.data
	(_h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen).menu_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.rc()).is_null()
	assert_object(_h.view()).is_null()
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_not_null()
	assert_int(Save.profile.data).is_equal(data)
	assert_int(Save.profile.runs_played).is_equal(1)
