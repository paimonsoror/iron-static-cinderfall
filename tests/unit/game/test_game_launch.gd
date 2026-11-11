extends GdUnitTestSuite
## GameLaunch: how the debug arguments shape a run, seed choice and run ids.


func _args(arg_list: Array[String]) -> DebugArgs:
	return DebugArgs.parse(PackedStringArray(arg_list))


func test_only_autoplay_and_a_hold_scenario_skip_the_menus() -> void:
	assert_bool(GameLaunch.wants_autostart(_args([]))).is_false()
	assert_bool(GameLaunch.wants_autostart(_args(["--seed=3", "--mute", "--debug-perf", "--quality=1"]))).is_false()
	assert_bool(GameLaunch.wants_autostart(_args(["--autoplay"]))).is_true()
	assert_bool(GameLaunch.wants_autostart(_args(["--autoplay=none"]))).is_true()
	assert_bool(GameLaunch.wants_autostart(_args(["--scenario=hold28"]))).is_true()
	assert_bool(GameLaunch.wants_autostart(_args(["--scenario=boss"]))).is_false()  # the puppet scenario, not a run


func test_a_hold_scenario_makes_the_core_invulnerable_and_attaches_the_driver() -> void:
	var cfg: SimConfig = GameRunKit.config()
	var rc: RunController = auto_free(RunController.new())
	GameLaunch.configure(cfg, rc, _args(["--scenario=hold50"]), 4)
	assert_bool(cfg.debug_invulnerable_core).is_true()
	assert_object(rc.scenario).is_not_null()
	assert_int(rc.scenario.hold).is_equal(50)
	assert_object(rc.bot).is_null()


func test_autoplay_picks_the_bot_policy() -> void:
	var cfg: SimConfig = GameRunKit.config()
	var rc: RunController = auto_free(RunController.new())
	GameLaunch.configure(cfg, rc, _args(["--autoplay=none"]), 1)
	assert_int(rc.bot.policy).is_equal(PolicyBot.Policy.NONE)
	GameLaunch.configure(cfg, rc, _args(["--autoplay=greedy"]), 1)
	assert_int(rc.bot.policy).is_equal(PolicyBot.Policy.GREEDY)
	GameLaunch.configure(cfg, rc, _args(["--autoplay=whatever"]), 1)
	assert_int(rc.bot.policy).is_equal(PolicyBot.Policy.NONE)
	assert_bool(cfg.debug_invulnerable_core).is_false()  # autoplay alone changes no rule


func test_a_normal_launch_configures_nothing() -> void:
	var cfg: SimConfig = GameRunKit.config()
	var rc: RunController = auto_free(RunController.new())
	GameLaunch.configure(cfg, rc, _args(["--seed=2"]), 2)
	assert_object(rc.bot).is_null()
	assert_object(rc.scenario).is_null()
	assert_bool(cfg.debug_invulnerable_core).is_false()
	assert_float(cfg.debug_damage_mult).is_equal(1.0)


func test_an_explicit_seed_beats_the_argument_which_beats_the_clock() -> void:
	assert_int(GameLaunch.pick_seed(0, _args(["--seed=77"]))).is_equal(0)
	assert_int(GameLaunch.pick_seed(5, _args(["--seed=77"]))).is_equal(5)
	assert_int(GameLaunch.pick_seed(-1, _args(["--seed=77"]))).is_equal(77)
	var timed: int = GameLaunch.pick_seed(-1, _args([]))
	assert_int(timed).is_between(0, 0x7FFFFFFF)


func test_run_ids_follow_unix_dash_seed_and_never_repeat_within_a_session() -> void:
	var used: Dictionary[String, bool] = {}
	var first: String = GameLaunch.make_run_id(9, used, PackedStringArray())
	assert_bool(first.ends_with("-9")).is_true()
	assert_bool(first.split("-")[0].is_valid_int()).is_true()
	var seen: Dictionary = {first: true}
	for i: int in 30:
		var id: String = GameLaunch.make_run_id(9, used, PackedStringArray())
		assert_bool(seen.has(id)).is_false()
		seen[id] = true


func test_a_run_id_that_was_already_rewarded_is_never_reused() -> void:
	var used: Dictionary[String, bool] = {}
	var taken: String = GameLaunch.make_run_id(3, used, PackedStringArray())
	var fresh_session: Dictionary[String, bool] = {}
	var next: String = GameLaunch.make_run_id(3, fresh_session, PackedStringArray([taken]))
	assert_str(next).is_not_equal(taken)
