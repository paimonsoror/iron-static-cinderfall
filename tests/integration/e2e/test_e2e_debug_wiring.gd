extends GdUnitTestSuite
## What Game wires for the debug arguments and the boot screen (ARCH 8, ARCH 11): the PerfHud of `--debug-perf` is set up
## in the tree and fed the tick times and the enemy count, the BattleDebugOverlay of `--debug-overlay` follows every
## run's sim and lets go of it again, and the first BattleView is built (and warmed up) while the boot screen shows.

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func _boot(arg_list: Array[String]) -> void:
	_h = GameHarness.create(self, PackedStringArray(arg_list), IntegrationKit.short_prepare)
	_h.boot()


func _perf() -> PerfHud:
	return _h.find_in("DebugRoot", &"PerfHud") as PerfHud


func _warm_view() -> BattleView:
	var o: Object = _h.game.get(&"_warm_view")
	return o as BattleView


## The `key=value` pairs of a `[PERF]` line, parsed the way tools/smoke_android.ps1 does.
func _pairs(line: String) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	assert_bool(line.begins_with("[PERF] ")).is_true()
	var re: RegEx = RegEx.create_from_string("(\\w+)=([\\d.]+)")
	for m: RegExMatch in re.search_all(line):
		out[m.get_string(1)] = m.get_string(2).to_float()
	return out


# --- --debug-perf ---


func test_debug_perf_sets_the_hud_up_in_the_tree_and_feeds_it_the_tick_times_and_the_enemy_count() -> void:
	_boot(["--scenario=hold12", "--seed=3", "--debug-perf"])
	var perf: PerfHud = _perf()
	assert_object(perf).is_not_null()
	assert_object(perf.get_node_or_null("PerfText")).is_not_null()  # setup() ran, after the node was in the tree
	assert_bool(perf.mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()  # it never eats a tap
	_h.frames(300)
	perf.sample_frame(1.0 / 60.0)
	var pairs: Dictionary[String, float] = _pairs(perf.report_now())
	for key: String in ["fps", "min", "frame_ms", "p95_ms", "tick_ms", "enemies", "draws", "prims", "vid_mb"]:
		assert_bool(pairs.has(key)).is_true()
	assert_float(pairs["tick_ms"]).is_greater(0.0)  # record_tick_usec is called from the run controller
	assert_float(pairs["tick_ms"]).is_less(5.0)
	assert_int(int(pairs["enemies"])).is_equal(_h.rc().sim.alive_count())
	assert_int(int(pairs["enemies"])).is_greater_equal(9)
	assert_int(perf.reports_logged).is_equal(1)


func test_the_tick_feed_follows_a_retry_and_without_the_flag_there_is_no_hud() -> void:
	_boot(["--scenario=hold12", "--seed=3", "--debug-perf"])
	var perf: PerfHud = _perf()
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	_h.frames(100)
	var line: String = perf.report_now()
	assert_float(_pairs(line)["tick_ms"]).is_greater(0.0)  # the new run's controller feeds it too
	_h.dispose()
	_boot(["--scenario=hold12", "--seed=3"])
	assert_object(_perf()).is_null()
	assert_int(_h.child_count("UI/DebugRoot")).is_equal(0)
	assert_bool(_h.rc().tick_sink.is_valid()).is_false()


# --- --debug-overlay ---


func test_debug_overlay_follows_the_run_and_a_retry_and_lets_go_on_the_way_out() -> void:
	_h = GameHarness.create(
		self, PackedStringArray(["--scenario=hold12", "--seed=3", "--debug-overlay=flow,slots"]), IntegrationKit.short_prepare
	)
	var stuck_listeners: int = Events.enemy_stuck.get_connections().size()  # the signal log is already one of them
	_h.boot()
	var overlay: BattleDebugOverlay = _h.view().get_node_or_null("BattleDebugOverlay") as BattleDebugOverlay
	assert_object(overlay).is_not_null()
	assert_array(overlay.active_layers()).is_equal([BattleDebugOverlay.Layer.FLOW, BattleDebugOverlay.Layer.SLOTS])
	var arrows: MultiMeshInstance3D = overlay.layer_node(BattleDebugOverlay.Layer.FLOW) as MultiMeshInstance3D
	assert_int(arrows.multimesh.visible_instance_count).is_greater(100)  # the flow field of the real nav
	assert_object(overlay.get(&"_sim")).is_same(_h.rc().sim)
	assert_int(Events.enemy_stuck.get_connections().size()).is_greater(stuck_listeners)
	var first_sim: SimWorld = _h.rc().sim
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	assert_object(overlay.get(&"_sim")).is_same(_h.rc().sim)  # rebound to the new run
	assert_object(overlay.get(&"_sim")).is_not_same(first_sim)
	assert_array(overlay.active_layers()).is_equal([BattleDebugOverlay.Layer.FLOW, BattleDebugOverlay.Layer.SLOTS])
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).quit_pressed.emit()
	assert_object(_h.view()).is_null()  # the view and its overlay are gone
	assert_object(overlay.get(&"_sim") if is_instance_valid(overlay) else null).is_null()
	await _h.settle(get_tree(), 3)
	assert_int(Events.enemy_stuck.get_connections().size()).is_equal(stuck_listeners)


func test_without_the_flag_no_overlay_node_is_built() -> void:
	_boot(["--scenario=hold12", "--seed=3"])
	assert_object(_h.view().get_node_or_null("BattleDebugOverlay")).is_null()


func test_debug_overlay_all_turns_on_the_four_layers() -> void:
	_boot(["--scenario=hold12", "--seed=3", "--debug-overlay"])
	var overlay: BattleDebugOverlay = _h.view().get_node_or_null("BattleDebugOverlay") as BattleDebugOverlay
	assert_array(overlay.active_layers()).has_size(4)


# --- the first BattleView during the boot screen ---


func test_the_first_view_is_built_and_warmed_up_during_the_boot_screen() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	assert_int(_h.state()).is_equal(GameState.Id.BOOT)
	assert_object(_warm_view()).is_null()  # the boot screen gets its first frames first
	_h.game.call(&"_prebuild_view")  # what the short timer of Game.boot does
	var warm: BattleView = _warm_view()
	assert_object(warm).is_not_null()
	assert_object(_h.view()).is_null()  # outside a run Game.battle_view stays null (ARCH 7.4)
	assert_bool(warm.visible).is_true()
	var warmup: Node = warm.arena_view.get_node_or_null("ShaderWarmup")
	assert_object(warmup).is_not_null()  # every material is drawn once, now
	await _h.settle(get_tree(), 4)
	assert_bool(is_instance_valid(warmup) and not warmup.is_queued_for_deletion()).is_false()  # done (2 frames)
	assert_int(_h.state()).is_equal(GameState.Id.BOOT)  # all of it before the menu


func test_the_boot_timer_builds_the_view_and_the_first_deploy_adopts_it() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	await get_tree().create_timer(Game.WARM_VIEW_DELAY_S + 0.25).timeout
	var warm: BattleView = _warm_view()
	assert_object(warm).is_not_null()
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_bool(warm.visible).is_false()  # nothing is drawn behind the menu
	assert_object(_h.view()).is_null()
	(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	assert_object(_h.view()).is_same(warm)  # the deploy reuses the warmed-up view, it builds nothing
	assert_bool(warm.visible).is_true()
	assert_object(_warm_view()).is_null()
	assert_int(_h.child_count("World")).is_equal(1)
	assert_int(_h.state()).is_equal(GameState.Id.PREPARING)


func test_leaving_a_run_for_the_menu_still_frees_the_view() -> void:
	_h = GameHarness.create(self)
	_h.boot()
	_h.game.call(&"_prebuild_view")
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()
	(_h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen).start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.frames(30)
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).quit_pressed.emit()
	await _h.settle(get_tree(), 3)
	assert_object(_h.view()).is_null()
	assert_int(_h.child_count("World")).is_equal(0)  # freed on the way to the menu, as before
