extends GdUnitTestSuite
## App lifecycle through the real MobileShell notifications (A13, A15): when the app goes to the background or loses
## focus the profile is written at once and the run is paused; coming back does not resume by itself. The shell reacts
## on mobile builds only, so the tests switch it on; on this desktop build the same notification does nothing.

var _h: GameHarness
var _fs: IntegrationCountingFs
var _shell: MobileShell


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=2"]))
	_fs = IntegrationCountingFs.new()
	Save.use_fs(_fs)
	Save.load_profile()
	_h.boot()
	_h.frames(_h.content.mission.prepare_ticks + 60)
	_shell = _h.node("MobileShell") as MobileShell


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_the_application_paused_notification_pauses_the_run_and_flushes_the_profile() -> void:
	_shell.lifecycle_enabled = true
	Save.profile.data = 31  # a change in memory that no write has seen
	assert_bool(_fs.exists(Save.PATH_MAIN)).is_false()
	_shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_bool(_h.rc().paused).is_true()
	assert_object(_h.find_in("OverlayRoot", &"PauseOverlay")).is_not_null()
	assert_int(_fs.stored_profile().data).is_equal(31)
	assert_bool(GameRewards.flush_pending).is_false()
	var tick: int = _h.rc().sim.tick
	assert_int(_h.frames(300)).is_equal(0)  # the time in the background is not played
	assert_int(_h.rc().sim.tick).is_equal(tick)


func test_losing_focus_does_the_same_and_coming_back_does_not_resume() -> void:
	_shell.lifecycle_enabled = true
	Save.profile.data = 7
	_shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_int(_fs.stored_profile().data).is_equal(7)
	_shell.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _h.settle(get_tree())
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)  # only the player's RESUME continues the run
	assert_bool(_h.rc().paused).is_true()


func test_a_failed_write_on_the_way_to_the_background_is_retried_later() -> void:
	_shell.lifecycle_enabled = true
	Save.profile.data = 55
	_fs.fail_writes = true
	_shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)  # the pause happens anyway
	assert_bool(GameRewards.flush_pending).is_true()
	_fs.fail_writes = false
	_h.call_game(&"resume_run")  # any state change retries the pending write
	assert_bool(GameRewards.flush_pending).is_false()
	assert_int(_fs.stored_profile().data).is_equal(55)


func test_on_this_desktop_build_the_notification_changes_nothing() -> void:
	assert_bool(_shell.lifecycle_enabled).is_equal(OS.has_feature("mobile"))
	if OS.has_feature("mobile"):
		return
	Save.profile.data = 9
	_shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_h.state()).is_not_equal(GameState.Id.PAUSED)
	assert_bool(_fs.exists(Save.PATH_MAIN)).is_false()


func test_the_background_pause_works_in_an_intermission_too() -> void:
	_h.dispose()
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=2"]), IntegrationKit.two_waves)
	_h.game.set(&"sim_config_hook", IntegrationKit.boost)
	Save.use_fs(_fs)
	_h.boot()
	_shell = _h.node("MobileShell") as MobileShell
	_shell.lifecycle_enabled = true
	assert_int(IntegrationKit.run_to_phase(_h, GameState.Id.INTERMISSION, 9000)).is_greater_equal(0)
	var left: int = _h.rc().sim.phase_ticks_left
	_shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	_h.frames(300)
	assert_int(_h.rc().sim.phase_ticks_left).is_equal(left)  # the intermission countdown did not run
	_h.call_game(&"resume_run")
	assert_int(_h.state()).is_equal(GameState.Id.INTERMISSION)