extends GdUnitTestSuite
## Game: BOOT -> MENU -> BRIEFING -> run -> pause -> resume / restart / quit, with the real sim, view, HUD and overlays.

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


## Boots the normal way and deploys from the menu; the run is at tick 0 (PREPARING).
func _deployed() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	var boot_screen: BootScreen = _h.find_in("ScreenRoot", &"BootScreen") as BootScreen
	boot_screen.finished.emit()
	var menu: MainMenuScreen = _h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen
	menu.start_pressed.emit()
	var briefing: BriefingScreen = _h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen
	briefing.deploy_pressed.emit()


func _pause_overlay() -> PauseOverlay:
	return _h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay


func test_boot_shows_the_boot_screen_and_the_menu_follows_its_finished_signal() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	assert_int(_h.state()).is_equal(GameState.Id.BOOT)
	var boot_screen: BootScreen = _h.find_in("ScreenRoot", &"BootScreen") as BootScreen
	assert_object(boot_screen).is_not_null()
	boot_screen.finished.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_not_null()
	assert_object(_h.find_in("ScreenRoot", &"BootScreen")).is_null()


func test_the_boot_screen_never_holds_the_game_longer_than_the_failsafe() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	await get_tree().create_timer(2.3).timeout
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_int(_h.screen_count()).is_equal(1)


func test_menu_briefing_and_back() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()
	(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.BRIEFING)
	var briefing: BriefingScreen = _h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen
	assert_object(briefing).is_not_null()
	assert_int(_h.screen_count()).is_equal(1)
	briefing.back_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_not_null()


func test_deploying_builds_the_run_the_view_and_the_hud_and_clears_the_screens() -> void:
	_deployed()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_object(_h.rc()).is_not_null()
	assert_object(_h.view()).is_not_null()
	assert_object(_h.hud()).is_not_null()
	assert_int(_h.screen_count()).is_equal(0)
	assert_int(_h.child_count("UI/HudRoot")).is_equal(1)
	assert_int(_h.events_log.count(&"run_started")).is_equal(1)
	assert_str(_h.rc().run_id).is_not_empty()
	assert_int(_h.rc().api.phase()).is_equal(GameState.Id.PREPARING)


func test_sim_phases_are_mirrored_into_the_machine_and_into_state_changed() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 1)
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)
	var pairs: Array[Vector2i] = []
	for r: Dictionary in _h.events_log.rows:
		if r["name"] == &"state_changed":
			var a: Array = r["args"]
			var from_state: int = a[0]
			var to_state: int = a[1]
			pairs.append(Vector2i(from_state, to_state))
	assert_array(pairs).is_equal([
		Vector2i(GameState.Id.BOOT, GameState.Id.MENU),
		Vector2i(GameState.Id.MENU, GameState.Id.BRIEFING),
		Vector2i(GameState.Id.BRIEFING, GameState.Id.PREPARING),
		Vector2i(GameState.Id.PREPARING, GameState.Id.SPAWNING),
	])


func test_the_hud_pause_button_pauses_shows_the_overlay_and_freezes_the_sim() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	var tick: int = _h.rc().sim.tick
	_h.hud().pause_requested.emit()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_bool(_h.rc().api.is_paused()).is_true()
	assert_object(_pause_overlay()).is_not_null()
	assert_int(_h.frames(120)).is_equal(0)
	assert_int(_h.rc().sim.tick).is_equal(tick)
	_h.rc().api.purchase_upgrade(5, &"damage")  # the drawer is behind the overlay, but the API refuses anyway
	assert_array(_h.events_log.last_args(&"purchase_resolved")).is_equal([5, false, Reason.Id.PAUSED])


func test_resume_returns_to_the_state_the_pause_came_from() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	_h.hud().pause_requested.emit()
	_pause_overlay().resume_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)
	assert_object(_pause_overlay()).is_null()
	assert_bool(_h.rc().paused).is_false()
	assert_int(_h.frames(10)).is_equal(10)


func test_restart_from_the_pause_overlay_starts_a_fresh_run() -> void:
	_deployed()
	_h.frames(120)
	var old_id: String = _h.rc().run_id
	var old_run: RunController = _h.rc()
	_h.hud().pause_requested.emit()
	_pause_overlay().restart_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_str(_h.rc().run_id).is_not_equal(old_id)
	assert_int(_h.rc().sim.tick).is_equal(0)
	assert_bool(_h.rc() == old_run).is_false()
	assert_object(_pause_overlay()).is_null()
	assert_int(_h.events_log.count(&"run_started")).is_equal(2)


func test_quit_from_the_pause_overlay_abandons_the_run_without_a_reward() -> void:
	_deployed()
	_h.frames(300)
	_h.hud().pause_requested.emit()
	_pause_overlay().quit_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.rc()).is_null()
	assert_object(_h.view()).is_null()
	assert_object(_h.hud()).is_null()
	assert_int(Save.profile.runs_played).is_equal(0)
	assert_int(Save.profile.data).is_equal(0)
	assert_int(_h.events_log.count(&"run_finished")).is_equal(0)
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_not_null()


func test_the_back_gesture_closes_the_drawer_first_then_pauses_then_resumes() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	_h.hud().open_drawer()
	assert_bool(_h.hud().is_drawer_open()).is_true()
	_h.call_game(&"request_back")
	assert_bool(_h.hud().is_drawer_open()).is_false()
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)  # the first back only closed the drawer
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)


func test_the_back_gesture_closes_the_settings_overlay_before_resuming() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	_h.hud().pause_requested.emit()
	_pause_overlay().settings_pressed.emit()
	assert_object(_h.find_in("OverlayRoot", &"SettingsScreen")).is_not_null()
	_h.call_game(&"request_back")
	assert_object(_h.find_in("OverlayRoot", &"SettingsScreen")).is_null()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	_h.call_game(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)


func test_the_back_gesture_goes_one_screen_back_and_asks_before_quitting() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	_h.call_game(&"request_back")  # during boot: nothing
	assert_int(_h.state()).is_equal(GameState.Id.BOOT)
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()
	(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
	_h.call_game(&"request_back")  # briefing -> menu
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	var before: int = _h.child_count("UI/OverlayRoot")
	_h.call_game(&"request_back")  # menu: the first press asks (a message), it does not quit
	assert_int(_h.child_count("UI/OverlayRoot")).is_equal(before + 1)
	assert_int(_h.state()).is_equal(GameState.Id.MENU)


func test_the_app_going_to_the_background_pauses_flushes_and_stays_paused() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	Save.profile.data = 31  # not flushed yet
	var shell: MobileShell = _h.node("MobileShell") as MobileShell
	shell.on_app_paused()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_bool(_h.rc().paused).is_true()
	assert_int(ProfileCodec.decode(_h.fs.read(Save.PATH_MAIN)).profile.data).is_equal(31)
	await _h.settle(get_tree())
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)  # coming back does not resume by itself


func test_the_os_back_request_reaches_the_policy() -> void:
	_deployed()
	_h.frames(_h.content.mission.prepare_ticks + 30)
	var shell: MobileShell = _h.node("MobileShell") as MobileShell
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
