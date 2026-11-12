extends GdUnitTestSuite
## A bot plays a whole run through the real Game (RunController, view, HUD, overlays) and the game it plays is, hash for
## hash, the one the headless harness plays for that seed: what `tools\sim_run.ps1` measures is what the app runs.
##  - the legacy game: the greedy bot (PolicyBot GREEDY, task W2-D) on the frozen legacy fixture, five scripted waves;
##  - the shipped game: the balanced bot on the slice data, a generated run with every intermission choice answered
##    (V3-I; the old "greedy wins with 30% to 80% of the core" corridor was a target of the scripted 5-wave game).

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_a_greedy_bot_run_of_the_legacy_game_is_the_run_of_the_headless_harness() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=greedy", "--seed=1"]))
	_h.boot()
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.GREEDY)
	assert_object(_h.rc().sim.plan).is_null()  # the legacy content has no run plan
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	var headless: HarnessReport = SimHarness.run(SimHarness.config_for(TestContent.baseline(), 1), PolicyBot.Policy.GREEDY)
	assert_int(_h.rc().sim.result()).is_equal(headless.result)
	assert_int(_h.rc().sim.waves_completed).is_equal(headless.waves_completed)
	assert_float(_h.rc().sim.core_hp).is_equal(headless.core_hp)
	assert_bool(GameState.is_terminal(_h.state())).is_true()
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward)


func test_a_balanced_bot_run_of_the_shipped_game_wins_and_is_the_run_of_the_headless_harness() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=balanced", "--seed=1"]), Callable(), HarnessKit.shipped())
	_h.boot()
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.BALANCED)
	assert_object(_h.rc().sim.plan).is_not_null()
	assert_int(_h.frames_until_over(SimHarness.VARIETY_MAX_TICKS)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	var headless: HarnessReport = SimHarness.run(SimHarness.config_for(HarnessKit.shipped(), 1), PolicyBot.Policy.BALANCED, 0)
	assert_int(headless.result).is_equal(RunResult.Id.VICTORY)
	assert_int(_h.rc().sim.tick).is_equal(headless.ticks)
	assert_str(_h.rc().sim.state_hash()).is_equal(headless.state_hash)
	assert_int(_h.rc().sim.events.event_hash).is_equal(headless.event_hash)
	assert_int(_h.rc().sim.waves_completed).is_equal(5)
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
