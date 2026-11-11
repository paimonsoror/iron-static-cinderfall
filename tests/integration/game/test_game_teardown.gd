extends GdUnitTestSuite
## Clean teardown: after a retry or a quit to the menu there are no leftover nodes, Events connections or sim
## references (WORK_PLAN W2-A).

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


## [node count, Events connection count, orphan node count].
func _counts() -> Array[int]:
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	return [nodes, GameSignalLog.events_connection_count(), orphans]


func _pause_overlay() -> PauseOverlay:
	return _h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay


func test_retrying_20_times_leaves_the_node_count_and_the_events_connections_unchanged() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=5"]))
	_h.boot()
	_h.frames(200)
	await _h.settle(get_tree(), 4)
	var baseline: Array[int] = _counts()
	var seen_ids: Dictionary = {}
	var old_sims: Array[WeakRef] = []
	for i: int in 20:
		seen_ids[_h.rc().run_id] = true
		old_sims.append(weakref(_h.rc().sim))
		_h.hud().pause_requested.emit()
		_pause_overlay().restart_pressed.emit()
		_h.frames(30)
		await _h.settle(get_tree(), 2)
		assert_array(_counts()).is_equal(baseline)
	assert_int(seen_ids.size()).is_equal(20)  # every retry had its own run id
	for wr: WeakRef in old_sims:
		assert_object(wr.get_ref()).is_null()  # no old sim is kept alive
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)


func test_quit_to_the_menu_leaves_nothing_of_the_run_behind() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()
	await _h.settle(get_tree(), 4)
	var menu_counts: Array[int] = _counts()
	for cycle: int in 3:
		(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
		(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
		_h.frames(240)
		var sim_ref: WeakRef = weakref(_h.rc().sim)
		_h.hud().pause_requested.emit()
		_pause_overlay().quit_pressed.emit()
		await _h.settle(get_tree(), 4)
		assert_int(_h.state()).is_equal(GameState.Id.MENU)
		assert_object(_h.rc()).is_null()
		assert_object(_h.view()).is_null()
		assert_object(_h.hud()).is_null()
		assert_object(sim_ref.get_ref()).is_null()
		assert_int(_h.child_count("World")).is_equal(0)
		assert_int(_h.child_count("RunHost")).is_equal(0)
		assert_int(_h.child_count("UI/HudRoot")).is_equal(0)
		assert_int(_h.child_count("UI/OverlayRoot")).is_equal(0)
		assert_array(_counts()).is_equal(menu_counts)


func test_retry_from_the_results_screen_also_leaves_nothing_behind() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=2"]), GameHarness.one_wave)
	_h.game.set(&"sim_config_hook", _boost)
	_h.boot()
	await _h.settle(get_tree(), 4)
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	var results: ResultsScreen = _h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen
	assert_object(results).is_not_null()
	results.retry_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_null()
	await _h.settle(get_tree(), 4)
	var after_retry: Array[int] = _counts()
	_h.frames(10)
	_h.hud().pause_requested.emit()
	_pause_overlay().restart_pressed.emit()
	await _h.settle(get_tree(), 4)
	assert_array(_counts()).is_equal(after_retry)


func _boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true
