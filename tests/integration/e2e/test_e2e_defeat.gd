extends GdUnitTestSuite
## The DEFEAT path through Game on the shipped game data (the 15-wave game): `--autoplay=none` drafts nothing, scraps
## every crate and takes route A, the core falls in act I, the results show DEFEAT, the reward is what the run banked
## (CONTENT 10: 6 Data per cleared wave; route A pays none), written to the profile exactly once, and a relaunch shows
## the same totals (A14, A15). The run is played once in before().

const NONE_KINDS: Array[int] = [
	SimCommand.Kind.SKIP_DRAFT, SimCommand.Kind.PICK_ROUTE, SimCommand.Kind.SALVAGE, SimCommand.Kind.SKIP_INTERMISSION,
]

var _h: GameHarness
var _fs: IntegrationCountingFs


func before() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=1"]), Callable(), HarnessKit.shipped())
	_fs = IntegrationCountingFs.new()
	Save.use_fs(_fs)
	Save.load_profile()
	_h.boot()
	_h.frames_until_over(SimHarness.VARIETY_MAX_TICKS)


func after() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_a_run_that_drafts_nothing_is_lost_before_the_boss_dies() -> void:
	assert_int(_h.state()).is_equal(GameState.Id.DEFEAT)
	assert_int(_h.rc().sim.result()).is_equal(RunResult.Id.DEFEAT)
	assert_float(_h.rc().sim.core_hp).is_equal(0.0)
	assert_int(_h.rc().sim.wave).is_between(2, 5)  # scorecard S6: `none` falls in act I
	assert_int(_h.rc().sim.waves_completed).is_less(5)
	assert_int(_h.rc().api.wave_count()).is_equal(15)
	for cmd: SimCommand in _h.rc().sim.command_log.entries:
		assert_bool(NONE_KINDS.has(cmd.kind)).override_failure_message("command kind %d" % cmd.kind).is_true()
	for stacks: int in _h.rc().sim.draft.stacks:
		assert_int(stacks).is_equal(0)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_object(_h.hud()).is_null()
	assert_int(_h.child_count("UI/HudRoot")).is_equal(0)  # no choice overlay outlives the run's HUD


func test_the_defeat_pays_the_waves_it_cleared_once_and_nothing_else() -> void:
	var waves: int = _h.summary().waves_completed
	var expected: int = _h.content.run.reward_per_wave * waves
	assert_int(_h.content.run.reward_per_wave).is_equal(6)
	assert_int(_h.rc().sim.stats.data).is_equal(expected)  # the sim banked it wave by wave
	assert_int(waves).is_greater(0)
	assert_int(_h.summary().result).is_equal(RunResult.Id.DEFEAT)
	assert_int(_h.summary().data_reward).is_equal(expected)
	assert_int(Save.profile.data).is_equal(expected)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(0)
	assert_int(Save.profile.best_core_hp).is_equal(0)
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	assert_array(_h.events_log.first_args(&"run_finished")).is_equal([RunResult.Id.DEFEAT, _h.rc().run_id])
	assert_bool(GameRewards.grant(_h.summary())).is_false()  # a second finish of the same run pays nothing
	assert_int(Save.profile.data).is_equal(expected)
	assert_bool(RunStore.exists(_fs)).is_false()  # the run ended: its run file is gone, nothing to resume


func test_the_defeat_is_on_disk_once_and_a_relaunch_shows_the_same_totals() -> void:
	assert_int(_fs.main_replacements).is_equal(Save.profile.hints_seen.size() + 1)  # one write per hint shown, one for the reward
	assert_int(_fs.stored_profile().data).is_equal(Save.profile.data)
	var launched: Node = IntegrationKit.relaunch(_fs)
	auto_free(launched)
	assert_array(IntegrationKit.totals(IntegrationKit.profile_of(launched))).is_equal(IntegrationKit.totals(Save.profile))
	assert_bool(IntegrationKit.profile_of(launched).awarded_run_ids.has(_h.rc().run_id)).is_true()
