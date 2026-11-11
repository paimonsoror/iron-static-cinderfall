extends GdUnitTestSuite
## Game's wiring of the HUD, the view settings, the camera fit and the first-run hints.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=1"]))
	_h.boot()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func test_the_hud_is_set_up_on_the_real_api_and_shows_the_live_run() -> void:
	_h.frames(_h.content.mission.prepare_ticks + 20)
	_h.hud().refresh()
	assert_int(_h.rc().api.wave()).is_equal(1)
	assert_str(_h.hud().top_bar.wave_label.text).is_equal(Strings.tf("hud.wave", [1, _h.content.waves.size()]))
	assert_bool(_h.hud().top_bar.pause_button.visible).is_true()


func test_hud_purchases_go_through_the_api_to_the_sim() -> void:
	_h.rc().sim.scrap = 600
	_h.frames(_h.content.mission.prepare_ticks + 5)
	var before: int = _h.rc().sim.scrap
	_h.rc().api.purchase_upgrade(_h.rc().api.next_command_id(), &"damage")
	_h.frames(2)
	assert_int(_h.rc().sim.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(_h.rc().sim.scrap).is_less(before)
	assert_array(_h.events_log.last_args(&"upgrade_level_changed")).is_equal([&"damage", 1])


func test_a_hint_reaches_the_hud_once_per_profile() -> void:
	Events.scrap_changed.emit(400)
	Events.scrap_changed.emit(500)
	assert_int(_h.events_log.count(&"hint_requested")).is_equal(1)
	assert_array(_h.events_log.first_args(&"hint_requested")).is_equal(["hint.tap_upgrades"])
	assert_bool(Save.has_seen_hint("hint.tap_upgrades")).is_true()
	assert_bool(_h.hud().banners.hint_panel.visible).is_true()


func test_a_seen_hint_is_not_shown_again_in_the_next_run() -> void:
	Events.core_hit.emit(1, &"skitter", 12.0, 0.0)
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	_h.events_log.clear()
	Events.core_hit.emit(2, &"skitter", 12.0, 0.0)
	assert_int(_h.events_log.count(&"hint_requested")).is_equal(0)


func test_changing_quality_in_settings_reaches_the_live_view() -> void:
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.HIGH)  # the profile default is 2
	Save.set_setting(&"quality", 0)
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.LOW)
	Save.set_setting(&"quality", 1)
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.MID)


func test_the_view_starts_with_the_saved_settings() -> void:
	_h.dispose()
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none"]))
	Save.set_setting(&"quality", 0)  # create() gave a fresh profile; this is what the player saved before the launch
	_h.boot()
	assert_int(_h.view().actor_layer.quality()).is_equal(VisualQuality.Tier.LOW)


func test_high_contrast_rebuilds_the_theme_of_the_ui_layers() -> void:
	var hud_root: Control = _h.node("UI/HudRoot") as Control
	var before: Theme = hud_root.theme
	Save.set_setting(&"high_contrast", true)
	assert_object(hud_root.theme).is_not_same(before)
	assert_object((_h.node("UI/OverlayRoot") as Control).theme).is_same(hud_root.theme)


func test_the_camera_refits_between_the_hud_bands_when_the_window_changes() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var arena: ArenaDef = _h.content.arena
	_h.hud().set_safe_margins(Vector4(0.0, 140.0, 0.0, 90.0))  # a notch and a gesture bar appeared
	get_viewport().size_changed.emit()
	await _h.settle(get_tree(), 2)
	var solved: CameraFitResult = CameraFit.solve(arena, size, _h.hud().top_band_px(), _h.hud().bottom_band_px())
	assert_float(_h.view().camera_rig.px_per_meter()).is_equal_approx(solved.px_per_meter, 0.001)
	_h.hud().set_safe_margins(Vector4.ZERO)
	get_viewport().size_changed.emit()
	await _h.settle(get_tree(), 2)
	var plain: CameraFitResult = CameraFit.solve(arena, size, _h.hud().top_band_px(), _h.hud().bottom_band_px())
	assert_float(_h.view().camera_rig.px_per_meter()).is_equal_approx(plain.px_per_meter, 0.001)
	assert_float(plain.px_per_meter).is_not_equal(solved.px_per_meter)


func test_the_camera_is_fitted_when_the_run_starts() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var solved: CameraFitResult = CameraFit.solve(_h.content.arena, size, _h.hud().top_band_px(), _h.hud().bottom_band_px())
	assert_float(_h.view().camera_rig.px_per_meter()).is_equal_approx(solved.px_per_meter, 0.001)


func test_the_view_follows_the_sim_each_frame() -> void:
	_h.frames(_h.content.mission.prepare_ticks)
	for i: int in 900:
		if _h.rc().sim.alive_count() > 0:
			break
		_h.frames(1)
	assert_int(_h.rc().sim.alive_count()).is_greater(0)
	var shown: int = _h.view().actor_layer.get_child_count()
	assert_int(shown).is_greater(0)
	assert_vector(_h.view().actor_layer.enemy_world_position(_first_enemy_id())).is_not_equal(Vector3.INF)


func _first_enemy_id() -> int:
	var st: EnemyStore = _h.rc().sim.enemies
	for i: int in st.high_water:
		if st.alive[i] == 1:
			return st.id[i]
	return 0
