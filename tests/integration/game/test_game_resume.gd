extends GdUnitTestSuite
## V2-D: Game with the run file (VARIETY_SPEC 2.8, 13.4). A run that is killed while the app is in the background comes
## back from the menu, paused, at the same tick with the same state; it ends once and is paid once. A run file of
## another build is closed at the menu. Giving a run up deletes its file. The real sim, view, HUD and overlays run.
## Each `_launch` is a new process: a fresh Game on the files the previous one left behind.

var _h: GameHarness


func after_test() -> void:
	_end_process()


func _boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true


static func _two_waves(c: ContentSet) -> void:
	c.waves = GameRunKit.first_waves(c, 2)


## A fresh Game on `files` (path -> text), at the menu.
func _launch(files: Dictionary = {}) -> void:
	_h = GameHarness.create(self, PackedStringArray(), _two_waves)
	for path: String in files:
		_h.fs.files[path] = files[path]
	Save.load_profile()
	_h.game.set(&"sim_config_hook", _boost)
	_h.boot()
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()


## The process is gone: the Game instance, its whole tree and the Save autoload's file system.
func _end_process() -> void:
	if _h == null:
		return
	var old_root: Node = _h.root
	_h.dispose()
	_h = null
	if is_instance_valid(old_root) and old_root.get_parent() != null:
		old_root.get_parent().remove_child(old_root)


func _deploy() -> void:
	(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.freeze()


## The app goes to the background, then the process dies: returns the files it left.
func _background_and_kill() -> Dictionary:
	(_h.node("MobileShell") as MobileShell).on_app_paused()
	var files: Dictionary = _h.fs.files.duplicate()
	_end_process()
	return files


func _resume_from_menu() -> bool:
	var resumed: bool = _h.game.call(&"resume_run_from_disk")
	_h.freeze()
	return resumed


func _pause_overlay() -> PauseOverlay:
	return _h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay


func test_a_run_killed_in_the_background_twice_resumes_paused_and_is_paid_once() -> void:
	_launch()
	_deploy()
	_h.frames(_h.content.mission.prepare_ticks + 400)
	var run_id: String = _h.rc().run_id
	var tick: int = _h.rc().sim.tick
	var state_hash: String = _h.rc().sim.state_hash()
	var phase: int = _h.rc().sim.phase
	assert_bool(GameState.is_combat(phase)).is_true()
	var files: Dictionary = _background_and_kill()
	assert_bool(files.has(RunStore.PATH_MAIN)).is_true()

	# second launch: the menu is told the wave and its RESUME RUN button resumes
	_launch(files)
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	var menu: MainMenuScreen = _h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen  # the real menu (V3-I)
	assert_int(menu.resume_wave).is_equal(1)
	assert_bool(menu.resume_button.visible).is_true()
	assert_str(menu.resume_button.text).is_equal(Strings.tf("menu.resume", [1]))  # RESUME RUN (WAVE 1)
	menu.resume_button.pressed.emit()
	_h.freeze()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_object(_pause_overlay()).is_not_null()  # the player comes back to the pause overlay
	assert_object(_h.hud()).is_not_null()
	assert_object(_h.view()).is_not_null()
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_null()
	var rc: RunController = _h.rc()
	assert_bool(rc.paused).is_true()
	assert_str(rc.run_id).is_equal(run_id)
	assert_int(rc.resume_mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_int(rc.sim.tick).is_equal(tick)
	assert_str(rc.sim.state_hash()).is_equal(state_hash)
	assert_int(_h.frames(30)).is_equal(0)  # paused: nothing moves
	files = _background_and_kill()  # killed again, still paused

	# third launch: resume, play to the end
	_launch(files)
	assert_bool(_resume_from_menu()).is_true()
	assert_int(_h.rc().sim.tick).is_equal(tick)
	_pause_overlay().resume_pressed.emit()
	assert_int(_h.state()).is_equal(phase)  # the application state is the sim's phase again
	assert_int(_h.frames(30)).is_equal(30)
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_str(_h.summary().run_id).is_equal(run_id)
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(1)
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	assert_bool(RunStore.exists(_h.fs)).is_false()  # the run ended: nothing to resume
	assert_bool(_resume_from_menu()).is_false()


func test_a_kill_in_the_intermission_resumes_into_the_intermission() -> void:
	_launch()
	_deploy()
	for i: int in 20000:
		if _h.rc().sim.waves_completed >= 1:
			break
		_h.frames(1)
	assert_int(_h.rc().sim.phase).is_equal(GameState.Id.INTERMISSION)
	_h.frames(20)
	var left: int = _h.rc().sim.phase_ticks_left
	var files: Dictionary = _background_and_kill()
	_launch(files)
	assert_int(GameRunFlow.resumable_wave(_h.content)).is_equal(2)  # RESUME RUN (WAVE 2)
	assert_bool(_resume_from_menu()).is_true()
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_int(_h.rc().sim.phase_ticks_left).is_equal(left)
	_pause_overlay().resume_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.INTERMISSION)
	_h.rc().api.skip_intermission()
	_h.frames(2)
	assert_int(_h.state()).is_equal(GameState.Id.SPAWNING)
	assert_int(_h.rc().sim.wave).is_equal(2)


func test_a_run_file_of_another_build_is_closed_at_the_menu_and_paid_once() -> void:
	var stale: String = SaveTestData.text("run_other_build")
	_launch({RunStore.PATH_MAIN: stale})
	# the file says three waves were cleared; this content has two, and a damaged number never pays more than that
	var reward: int = Formulas.data_reward(RunResult.Id.DEFEAT, 2, 0.0, _h.content.mission)
	assert_int(reward).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_int(Save.profile.data).is_equal(reward)  # paid before the menu shows the profile
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_bool(RunStore.exists(_h.fs)).is_false()
	assert_bool(_resume_from_menu()).is_false()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	var files: Dictionary = _h.fs.files.duplicate()
	files[RunStore.PATH_MAIN] = stale  # the same file again on the next launch
	_end_process()
	_launch(files)
	assert_int(Save.profile.data).is_equal(reward)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_bool(RunStore.exists(_h.fs)).is_false()


func test_overlays_pauses_restart_and_quit_in_one_visit() -> void:
	_launch()
	assert_int(GameRunFlow.resumable_wave(_h.content)).is_equal(0)
	var menu: MainMenuScreen = _h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen
	assert_bool(menu.resume_button.visible).is_false()  # no run file: no RESUME RUN button
	assert_bool(_resume_from_menu()).is_false()  # nothing to resume
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_object(_h.find_in("ScreenRoot", &"MainMenuScreen")).is_not_null()
	assert_object(_h.rc()).is_null()
	_deploy()
	assert_bool(_resume_from_menu()).is_false()  # only from the menu
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	_h.frames(60)
	assert_bool(RunStore.exists(_h.fs)).is_true()
	# a choice overlay appears above the HUD while the sim waits, and goes when the wait ends
	assert_object(_h.find_in("HudRoot", &"DraftOverlay")).is_null()
	Events.await_changed.emit(RunApi.AWAIT_DRAFT)
	var overlay: Node = _h.find_in("HudRoot", &"DraftOverlay")
	assert_object(overlay).is_not_null()
	assert_int(overlay.get_index()).is_greater(_h.hud().get_index())
	Events.await_changed.emit(RunApi.AWAIT_ROUTE)
	assert_object(_h.find_in("HudRoot", &"DraftOverlay")).is_null()
	assert_object(_h.find_in("HudRoot", &"RouteOverlay")).is_not_null()
	# every pause writes the resume tick; a restart gives the run up and the file is the new run's
	var first_id: String = _h.rc().run_id
	_h.hud().pause_requested.emit()
	assert_int(RunFile.whole(Save.load_run()["resume_tick"], -1)).is_equal(_h.rc().sim.tick)
	_pause_overlay().restart_pressed.emit()
	_h.freeze()
	assert_object(_h.find_in("HudRoot", &"RouteOverlay")).is_null()  # the overlay left with its run
	var second_id: String = _h.rc().run_id
	assert_str(second_id).is_not_equal(first_id)
	assert_str(RunFile.id_of(Save.load_run())).is_equal(second_id)
	# quitting to the menu gives the run up: no file, no payment, no overlay
	_h.frames(60)
	Events.await_changed.emit(RunApi.AWAIT_SALVAGE)
	_h.hud().pause_requested.emit()
	_pause_overlay().quit_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_int(_h.child_count("UI/HudRoot")).is_equal(0)
	assert_bool(RunStore.exists(_h.fs)).is_false()
	assert_int(Save.profile.runs_played).is_equal(0)
	assert_bool(_resume_from_menu()).is_false()
	await _h.settle(get_tree(), 2)
