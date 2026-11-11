extends GdUnitTestSuite
## Pause through the real Game in every phase (A13): the sim is simply not stepped, so the state hash, the tick, the
## countdowns, the cooldowns and the event count stay exactly as they were for as long as the pause lasts, and the run
## goes on from the same place after RESUME. Two baseline waves with boosted damage, so every phase comes up quickly.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=7"]), IntegrationKit.two_waves)
	_h.game.set(&"sim_config_hook", IntegrationKit.boost)
	_h.boot()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


## Gets to `phase`, uses the abilities where the phase allows it (so there are live timers to freeze), pauses through
## the HUD button, lets 10 seconds of frames go by, and checks that nothing moved; then resumes.
func _check_pause_in(phase: int) -> void:
	assert_int(IntegrationKit.run_to_phase(_h, phase, 9000)).is_greater_equal(0)
	var rc: RunController = _h.rc()
	if phase == GameState.Id.SPAWNING:
		_h.frames(120)
		rc.api.activate_ability(rc.api.next_command_id(), &"emp")
		rc.api.activate_ability(rc.api.next_command_id(), &"overdrive")
		_h.frames(5)
		assert_int(rc.api.ability_active_left(&"overdrive")).is_greater(0)
	var before: Dictionary = IntegrationKit.frozen_state(rc)
	_h.hud().pause_requested.emit()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_bool(rc.api.is_paused()).is_true()
	assert_int(_h.frames(600)).is_equal(0)  # ten seconds of frames, no tick
	assert_dict(IntegrationKit.frozen_state(rc)).is_equal(before)
	_h.call_game(&"resume_run")
	assert_int(_h.state()).is_equal(phase)  # back where it was
	assert_int(_h.frames(30)).is_equal(30)
	assert_str(rc.sim.state_hash()).is_not_equal(before["hash"])  # and the run goes on


func test_pause_in_preparing_freezes_the_run() -> void:
	_check_pause_in(GameState.Id.PREPARING)


func test_pause_in_spawning_freezes_the_hash_and_every_cooldown() -> void:
	_check_pause_in(GameState.Id.SPAWNING)


func test_pause_in_clearing_freezes_the_run() -> void:
	_check_pause_in(GameState.Id.CLEARING)


func test_pause_in_intermission_does_not_spend_the_countdown() -> void:
	_check_pause_in(GameState.Id.INTERMISSION)
	assert_int(_h.rc().sim.phase_ticks_left).is_between(
		_h.content.mission.intermission_ticks - 40, _h.content.mission.intermission_ticks
	)


func test_the_back_gesture_pauses_and_a_second_one_resumes_without_moving_the_sim() -> void:
	IntegrationKit.run_to_phase(_h, GameState.Id.SPAWNING, 9000)
	_h.frames(200)
	var before: Dictionary = IntegrationKit.frozen_state(_h.rc())
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	_h.frames(300)
	assert_dict(IntegrationKit.frozen_state(_h.rc())).is_equal(before)
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)
	assert_dict(IntegrationKit.frozen_state(_h.rc())).is_equal(before)  # resuming itself runs no tick


func test_commands_during_a_pause_never_reach_the_sim() -> void:
	IntegrationKit.run_to_phase(_h, GameState.Id.SPAWNING, 9000)
	_h.frames(100)
	var rc: RunController = _h.rc()
	_h.hud().pause_requested.emit()
	var before: Dictionary = IntegrationKit.frozen_state(rc)
	rc.api.purchase_upgrade(rc.api.next_command_id(), &"damage")
	rc.api.activate_ability(rc.api.next_command_id(), &"shield")
	rc.api.skip_intermission()
	_h.frames(5)
	assert_dict(IntegrationKit.frozen_state(rc)).is_equal(before)
	assert_int(rc.sim.command_queue.size()).is_equal(0)
	assert_int(rc.sim.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
