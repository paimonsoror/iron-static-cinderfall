extends GdUnitTestSuite
## W3-A: the bot of `--autoplay` and the player's taps draw their command ids from one counter. Before, both counted
## 1, 2, 3 ..., so the first CONTINUE tap of the player repeated the bot's first id and the sim dropped it silently as a
## duplicate (a repeated skip has no answer at all), and a player's purchase could cancel one of the bot's.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=greedy", "--seed=1"]), IntegrationKit.two_waves)
	_h.game.set(&"sim_config_hook", IntegrationKit.boost)
	_h.boot()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_the_bot_draws_its_ids_from_the_hud_counter() -> void:
	var rc: RunController = _h.rc()
	assert_bool(rc.bot.id_source.is_valid()).is_true()
	var first: int = rc.api.next_command_id()
	_h.frames(3)
	rc.sim.add_scrap(1000)
	_h.frames(5)
	assert_int(rc.bot.commands_submitted).is_greater(0)
	assert_int(rc.api.next_command_id()).is_greater(first + rc.bot.commands_submitted)  # the bot advanced the shared counter


func test_continue_pressed_during_autoplay_is_never_dropped_as_a_repeated_id() -> void:
	assert_int(_h.frames_until_over(60000)).is_greater(0)  # presses CONTINUE in every intermission, like a player
	var sim: SimWorld = _h.rc().sim
	var seen: Dictionary[int, bool] = {}
	var skips: int = 0
	for cmd: SimCommand in sim.command_log.entries:
		assert_bool(seen.has(cmd.command_id)).is_false()  # no id was ever used twice
		seen[cmd.command_id] = true
		if cmd.kind == SimCommand.Kind.SKIP_INTERMISSION:
			skips += 1
	assert_int(skips).is_greater(0)
	assert_int(sim.stats.wave_start_tick[2] - sim.stats.wave_clear_tick[1]).is_less(10)  # the skip took effect at once
	for r: Dictionary in _h.events_log.rows:
		if r["name"] == &"purchase_resolved":
			var args: Array = r["args"]
			assert_int(args[2]).is_not_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
