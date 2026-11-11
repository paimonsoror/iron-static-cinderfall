extends GdUnitTestSuite
## The greedy-bot run of the plan (GDD 8.4): the bot (PolicyBot GREEDY, task W2-D) plays a whole run on the real,
## tuned content and wins with 30% to 80% of the core left. PolicyBot.act is still a stub, so the test is skipped:
## to enable it, change `_do_skip` to false once W2-D has merged.

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_a_greedy_bot_run_wins_with_30_to_80_percent_core(
	_do_skip: bool = true, _skip_reason: String = "enable when W2-D merges"
) -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=greedy", "--seed=1"]))
	_h.game.set(&"content", Content.db)  # the tuned game data, not the frozen baseline
	_h.boot()
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.GREEDY)
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	var fraction: float = _h.rc().sim.core_hp / _h.rc().sim.core_max_hp
	assert_float(fraction).is_between(0.3, 0.8)
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward)
