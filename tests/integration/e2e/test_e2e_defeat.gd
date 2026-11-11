extends GdUnitTestSuite
## The DEFEAT path through Game on the tuned game data: `--autoplay=none` buys nothing, the core falls in wave 3 or 4
## (GDD 8.4), the results show DEFEAT, the reward is 10 Data per cleared wave, written to the profile exactly once, and a
## relaunch shows the same totals (A14, A15). The run is played once in before().

var _h: GameHarness
var _fs: IntegrationCountingFs


func before() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=1"]))
	_h.game.set(&"content", Content.db)  # the tuned game data, not the frozen baseline
	_fs = IntegrationCountingFs.new()
	Save.use_fs(_fs)
	Save.load_profile()
	_h.boot()
	_h.frames_until_over(60000)


func after() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_a_run_that_buys_nothing_is_lost_in_wave_3_or_4() -> void:
	assert_int(_h.state()).is_equal(GameState.Id.DEFEAT)
	assert_int(_h.rc().sim.result()).is_equal(RunResult.Id.DEFEAT)
	assert_float(_h.rc().sim.core_hp).is_equal(0.0)
	assert_int(_h.rc().sim.wave).is_between(3, 4)
	for cmd: SimCommand in _h.rc().sim.command_log.entries:
		assert_int(cmd.kind).is_equal(SimCommand.Kind.SKIP_INTERMISSION)  # only the CONTINUE taps of the harness
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(_h.hud()).is_null()


func test_the_defeat_pays_10_data_per_cleared_wave_once_and_nothing_else() -> void:
	var waves: int = _h.summary().waves_completed
	assert_int(_h.summary().result).is_equal(RunResult.Id.DEFEAT)
	assert_int(_h.summary().data_reward).is_equal(10 * waves)
	assert_int(Save.profile.data).is_equal(10 * waves)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(0)
	assert_int(Save.profile.best_core_hp).is_equal(0)
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	assert_array(_h.events_log.first_args(&"run_finished")).is_equal([RunResult.Id.DEFEAT, _h.rc().run_id])
	assert_bool(GameRewards.grant(_h.summary())).is_false()  # a second finish of the same run pays nothing
	assert_int(Save.profile.data).is_equal(10 * waves)


func test_the_defeat_is_on_disk_once_and_a_relaunch_shows_the_same_totals() -> void:
	assert_int(_fs.main_replacements).is_equal(Save.profile.hints_seen.size() + 1)  # one write per hint shown, one for the reward
	assert_int(_fs.stored_profile().data).is_equal(Save.profile.data)
	var launched: Node = IntegrationKit.relaunch(_fs)
	auto_free(launched)
	assert_array(IntegrationKit.totals(IntegrationKit.profile_of(launched))).is_equal(IntegrationKit.totals(Save.profile))
	assert_bool(IntegrationKit.profile_of(launched).awarded_run_ids.has(_h.rc().run_id)).is_true()
