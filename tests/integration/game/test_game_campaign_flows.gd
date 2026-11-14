extends GdUnitTestSuite
## V5-A: the game-layer connections of the Archive screens through the real Game (GameRunFlow): DAILY RUN on the menu,
## the milestone lines and SAME SEED on the results screen, the back gesture on a screen's own overlay, and the debug
## starts. The shipped data is cut to its first wave where a quick, real (not debug) victory is needed: a run with a
## debug switch records nothing in the Archive, so the milestones need a run without one.

var _h: GameHarness


func after_test() -> void:
	Game.run = null  # the autoload's run (set by the one test that needs the live-run link of GameRewards)
	if _h != null:
		_h.dispose()
		_h = null


static func _first_wave_only(c: ContentSet) -> void:
	c.run.waves.resize(1)


func _launch(args: Array[String], tweak: Callable = Callable()) -> void:
	_h = GameHarness.create(self, PackedStringArray(args), tweak, HarnessKit.shipped())
	_h.boot()
	var boot_screen: BootScreen = _h.find_in("ScreenRoot", &"BootScreen") as BootScreen
	if boot_screen != null:
		boot_screen.finished.emit()


func _menu() -> MainMenuScreen:
	return _h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen


func _results() -> ResultsScreen:
	return _h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen


func test_the_daily_run_button_deploys_todays_seed_with_the_standard_kit_and_the_full_pool() -> void:
	_launch(["--seed=3"])
	Save.profile.kit = &"k_gunline"  # the Daily Run does not care which kit the profile holds
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	var today: String = GameLaunch.utc_date()
	_menu().daily_pressed.emit()
	_h.freeze()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	var config: SimConfig = _h.rc().sim.config
	assert_bool(config.daily).is_true()
	assert_int(config.run_seed).is_equal(GameLaunch.daily_seed(today))
	assert_int(config.kit_index).is_equal(_h.content.kit_index(GameLaunch.DAILY_KIT))
	assert_bool(config.has_unlock("u_w_rail")).is_true()  # the same pool for everyone
	assert_bool(_h.rc().api.has_unlock(&"u_f_boss_intel")).is_true()
	assert_int(_h.rc().sim.arsenal.slot_count).is_equal(3)
	# a second press while a run is up does nothing
	assert_bool(GameRunFlow.start_daily(_h.game)).is_false()
	await _h.settle(get_tree(), 2)


func test_a_real_victory_lists_its_milestones_and_same_seed_starts_that_seed_again() -> void:
	_launch(["--seed=7"], _first_wave_only)
	_menu().start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.freeze()
	# GameRewards.launch_of asks the Game autoload for the live run (kit, daily); the harness has its own Game node
	Game.run = _h.rc()
	assert_bool(_h.rc().sim.config.is_debug()).is_false()
	assert_int(_h.frames_until_over(20000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	var screen: ResultsScreen = _results()
	assert_object(screen).is_not_null()
	# the reward: the run's Data and the two milestones of a first victory with the standard kit
	var paid: Array = Save.last_reward.get("milestones", [])
	var ids: Array[String] = []
	for row: Variant in paid:
		var entry: Dictionary = row
		ids.append(str(entry["id"]))
	assert_array(ids).contains(["ms_first_victory", "ms_victory_kit_k_standard"])
	var milestone_data: int = Save.last_reward.get("milestone_data", 0)
	assert_int(milestone_data).is_equal(275)
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward + milestone_data)
	assert_bool(screen.milestone_label.visible).is_true()
	assert_int(screen.milestone_label.text.split("\n").size()).is_equal(paid.size())
	assert_str(screen.milestone_label.text).contains("200")
	# the back gesture closes the Archive over the results first, then leaves for the menu
	var archive: ArchiveScreen = screen.open_archive()
	assert_object(archive).is_not_null()
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_object(_results()).is_not_null()
	assert_bool(screen.close_overlay()).is_false()  # it is closed
	# SAME SEED: a new run with the seed and the kit of the run that ended, never a Daily Run
	var first_id: String = _h.rc().run_id
	screen.same_seed_pressed.emit(7)
	_h.freeze()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_int(_h.rc().sim.config.run_seed).is_equal(7)
	assert_int(_h.rc().sim.config.kit_index).is_equal(0)
	assert_bool(_h.rc().sim.config.daily).is_false()
	assert_str(_h.rc().run_id).is_not_equal(first_id)
	assert_object(_results()).is_null()
	assert_int(Save.profile.runs_played).is_equal(1)
	await _h.settle(get_tree(), 2)


func test_same_seed_does_nothing_outside_the_results() -> void:
	_launch(["--seed=7"])
	GameRunFlow.start_same_seed(7, _h.game)
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.rc()).is_null()


func test_back_on_the_menu_closes_the_archive_before_it_asks_to_quit() -> void:
	_launch(["--seed=3"])
	assert_bool(_h.game.call(&"open_archive")).is_true()
	assert_object(_menu().archive_screen).is_not_null()
	_h.call_game(&"request_back")
	assert_object(_menu().archive_screen).is_null()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	var armed: int = _h.game.get(&"_quit_armed_until")
	assert_int(armed).is_equal(0)  # the first back only closed the overlay
	_h.call_game(&"request_back")
	armed = _h.game.get(&"_quit_armed_until")
	assert_int(armed).is_greater(0)  # the second asks to quit
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	await _h.settle(get_tree(), 2)


func test_the_menu_is_told_the_date_and_the_resume_wave() -> void:
	_launch(["--seed=3"])
	assert_int(_menu().resume_wave).is_equal(0)
	assert_bool(_menu().resume_button.visible).is_false()
	assert_bool(_menu().daily_visible()).is_false()  # no act I boss kill on a new profile
	assert_bool(GameRunFlow.open_archive(null)).is_false()


func test_a_debug_start_through_the_game_plays_the_named_wave_first_and_records_nothing() -> void:
	_launch(["--scenario=wave:6", "--autoplay=none", "--seed=4"])
	assert_bool(GameState.is_run_phase(_h.state())).is_true()  # no menu: it deploys at once
	var sim: SimWorld = _h.rc().sim
	assert_int(sim.config.debug_start_wave).is_equal(6)
	assert_int(sim.waves_completed).is_equal(5)
	_h.frames(_h.content.mission.prepare_ticks + 5)
	assert_int(sim.wave).is_equal(6)
	assert_int(_h.rc().api.act()).is_equal(2)
	assert_int(_h.events_log.count(&"act_started")).is_equal(1)
	assert_object(_h.rc().files).is_not_null()  # the run file is kept: a debug start can be resumed
	assert_int(_h.frames_until_over(SimHarness.VARIETY_MAX_TICKS)).is_greater(0)
	assert_bool(GameState.is_terminal(_h.state())).is_true()
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.best_wave).is_equal(0)  # a debug run leaves no trace in the Archive
	assert_int(Save.profile.claimed.size()).is_equal(0)
	await _h.settle(get_tree(), 2)


func test_a_debug_boss_through_the_game_starts_at_its_boss_wave() -> void:
	_launch(["--scenario=boss:tremor_rig", "--autoplay=balanced", "--seed=4"])
	var sim: SimWorld = _h.rc().sim
	assert_int(sim.waves_completed).is_equal(9)
	assert_int(sim.plan.boss_ids[1]).is_equal(Ids.EN_TREMOR_RIG)
	_h.frames(_h.content.mission.prepare_ticks + 60)
	assert_int(sim.wave).is_equal(10)
	assert_int(_h.events_log.count(&"boss_spawned")).is_equal(1)
	var spawned: Array = _h.events_log.first_args(&"boss_spawned")  # [id, kind]
	assert_str(str(spawned[1])).is_equal("tremor_rig")
	await _h.settle(get_tree(), 2)
