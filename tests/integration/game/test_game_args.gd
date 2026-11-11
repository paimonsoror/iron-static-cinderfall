extends GdUnitTestSuite
## The debug arguments of ARCH 11 as Game honours them: --autoplay, --seed, --scenario=hold<N>, --quality, --debug-perf.

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func _boot(arg_list: Array[String]) -> void:
	_h = GameHarness.create(self, PackedStringArray(arg_list))
	_h.boot()


func test_without_arguments_the_game_waits_on_the_boot_screen() -> void:
	_boot([])
	assert_int(_h.state()).is_equal(GameState.Id.BOOT)
	assert_object(_h.rc()).is_null()


func test_autoplay_skips_the_menus_and_deploys_at_once() -> void:
	_boot(["--autoplay=none"])
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_object(_h.rc()).is_not_null()
	assert_object(_h.hud()).is_not_null()
	assert_int(_h.screen_count()).is_equal(0)


func test_autoplay_none_attaches_the_do_nothing_bot() -> void:
	_boot(["--autoplay=none"])
	assert_object(_h.rc().bot).is_not_null()
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.NONE)


func test_autoplay_greedy_and_a_bare_autoplay_attach_the_greedy_bot() -> void:
	_boot(["--autoplay=greedy"])
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.GREEDY)
	_h.dispose()
	_boot(["--autoplay"])
	assert_int(_h.rc().bot.policy).is_equal(PolicyBot.Policy.GREEDY)


func test_the_bot_acts_before_every_tick_of_the_run() -> void:
	_boot(["--autoplay=none"])
	var counting: CountingBot = CountingBot.new()
	_h.rc().bot = counting
	_h.frames(25)
	assert_int(counting.calls).is_equal(25)
	assert_int(counting.last_tick_seen).is_equal(24)  # it sees the world before the tick is applied


func test_seed_fixes_the_run_seed_and_a_retry_keeps_it() -> void:
	_boot(["--autoplay=none", "--seed=9"])
	assert_int(_h.rc().sim.config.run_seed).is_equal(9)
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	assert_int(_h.rc().sim.config.run_seed).is_equal(9)
	assert_str(_h.rc().run_id).contains("-9")


func test_without_a_seed_argument_each_run_gets_its_own_time_based_seed() -> void:
	_boot(["--autoplay=none"])
	var first: int = _h.rc().sim.config.run_seed
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	assert_int(first).is_greater_equal(0)
	assert_int(_h.rc().sim.config.run_seed).is_not_equal(first)


func test_the_hold_scenario_runs_the_real_sim_with_an_invulnerable_core_and_n_enemies() -> void:
	_boot(["--scenario=hold12"])
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)  # a scenario deploys at once, like autoplay
	assert_bool(_h.rc().sim.config.debug_invulnerable_core).is_true()
	assert_object(_h.rc().scenario).is_not_null()
	_h.frames(_h.content.mission.prepare_ticks + 600)
	assert_bool(GameState.is_combat(_h.rc().sim.phase)).is_true()
	assert_int(_h.rc().sim.alive_count()).is_greater_equal(9)
	assert_float(_h.rc().sim.core_hp).is_equal(_h.rc().sim.core_max_hp)


func test_quality_forces_the_tier_even_when_the_profile_says_otherwise() -> void:
	Save.set_setting(&"quality", 2)
	_boot(["--autoplay=none", "--quality=0"])
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.LOW)
	Save.set_setting(&"quality", 1)  # settings_changed fires, the forced tier stays
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.LOW)


func test_debug_perf_adds_the_perf_hud_to_the_debug_layer() -> void:
	_boot(["--autoplay=none", "--debug-perf"])
	assert_object(_h.find_in("DebugRoot", &"PerfHud")).is_not_null()
	_h.dispose()
	_boot(["--autoplay=none"])
	assert_int(_h.child_count("UI/DebugRoot")).is_equal(0)


func test_mute_silences_the_audio_director() -> void:
	_boot(["--autoplay=none", "--mute"])
	assert_bool(Sfx.disabled).is_true()


class CountingBot extends PolicyBot:
	var calls: int = 0
	var last_tick_seen: int = -1

	func _init() -> void:
		super(PolicyBot.Policy.NONE)

	func act(world: SimWorld) -> void:
		calls += 1
		last_tick_seen = world.tick
