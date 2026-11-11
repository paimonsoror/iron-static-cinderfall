extends GdUnitTestSuite
## CombatHud state: top bar, boss bar, banners, hints, low-core warning, drawer strip, intermission, readout.

var _api: FakeRunApi
var _hud: CombatHud


func before_test() -> void:
	_api = FakeRunApi.new()
	_api.fake_phase = GameState.Id.SPAWNING
	_hud = CombatHudTestKit.make_hud(self, _api)


func test_the_top_bar_shows_core_percent_wave_and_grouped_scrap() -> void:
	_api.fake_wave = 3
	_api.set_scrap(1240)
	_api.set_core(870.0)
	_hud.refresh()
	assert_str(_hud.top_bar.core_label.text).is_equal(Strings.tf("hud.core_pct", [87]))
	assert_str(_hud.top_bar.core_value_label.text).is_equal(Strings.tf("hud.core_hp", [870, 1000]))
	assert_str(_hud.top_bar.wave_label.text).is_equal(Strings.tf("hud.wave", [3, 5]))
	assert_str(_hud.top_bar.scrap_label.text).is_equal("1,240")
	assert_float(_hud.top_bar.core_bar.fraction).is_equal_approx(0.87, 0.001)


func test_the_shield_is_a_cyan_overlay_segment_and_a_label() -> void:
	_api.fake_shield_hp = 100.0
	_hud.refresh()
	assert_float(_hud.top_bar.core_bar.overlay_fraction).is_equal_approx(0.1, 0.001)
	assert_str(_hud.top_bar.core_value_label.text).is_equal(Strings.tf("hud.shield_up", [100]))
	_api.fake_shield_hp = 0.0
	_hud.refresh()
	assert_float(_hud.top_bar.core_bar.overlay_fraction).is_equal(0.0)


func test_the_boss_bar_is_visible_only_when_the_boss_hp_is_not_negative() -> void:
	assert_bool(_hud.banners.boss_bar.visible).is_false()
	_api.fake_boss_hp = 2800.0
	_hud.refresh()
	assert_bool(_hud.banners.boss_bar.visible).is_true()
	assert_str(_hud.banners.boss_bar.name_label.text).is_equal(Strings.t("enemy.siege_hulk.name").to_upper())
	_api.fake_boss_hp = 1400.0
	_hud.refresh()
	assert_float(_hud.banners.boss_bar.bar.fraction).is_equal_approx(0.5, 0.001)
	_api.fake_boss_hp = 0.0  # alive with no hp left is still a boss (-1 is the only "no boss")
	_hud.refresh()
	assert_bool(_hud.banners.boss_bar.visible).is_true()
	_api.fake_boss_hp = -1.0
	_hud.refresh()
	assert_bool(_hud.banners.boss_bar.visible).is_false()


func test_the_low_core_warning_appears_below_25_percent_only() -> void:
	_api.set_core(300.0)
	assert_bool(_hud.banners.warn_panel.visible).is_false()
	_api.set_core(240.0)
	assert_bool(_hud.banners.warn_panel.visible).is_true()
	assert_str(_hud.banners.warn_label.text).is_equal(Strings.tf("hud.warn.core", [24]))
	_api.set_core(600.0)
	assert_bool(_hud.banners.warn_panel.visible).is_false()


func test_a_wave_start_shows_the_banner_and_its_whisper_line() -> void:
	Events.wave_started.emit(3)
	assert_bool(_hud.banners.banner_box.visible).is_true()
	assert_str(_hud.banners.banner_title.text).is_equal(Strings.tf("hud.banner.wave", [3]))
	assert_str(_hud.banners.banner_whisper.text).is_equal(Strings.t("hud.whisper.3"))
	Events.wave_started.emit(1)
	assert_str(_hud.banners.banner_whisper.text).is_equal(Strings.t("hud.whisper.1"))


func test_the_boss_spawn_shows_a_boss_banner() -> void:
	_api.fake_boss_hp = 2800.0
	Events.boss_spawned.emit(7, &"siege_hulk")
	assert_bool(_hud.banners.banner_box.visible).is_true()
	assert_str(_hud.banners.banner_title.text).is_equal(
		Strings.tf("hud.banner.boss", [Strings.t("enemy.siege_hulk.name").to_upper()]))
	assert_str(_hud.banners.banner_whisper.text).is_equal(Strings.t("hud.whisper.boss"))


func test_a_hint_request_shows_one_line_from_the_string_table() -> void:
	assert_bool(_hud.banners.hint_panel.visible).is_false()
	Events.hint_requested.emit("hint.tap_upgrades")
	assert_bool(_hud.banners.hint_panel.visible).is_true()
	assert_str(_hud.banners.hint_label.text).is_equal(Strings.t("hint.tap_upgrades"))


func test_the_deploy_countdown_shows_before_wave_one() -> void:
	_api.fake_phase = GameState.Id.PREPARING
	_api.fake_phase_ticks_left = 150
	_hud.refresh()
	assert_bool(_hud.banners.banner_box.visible).is_true()
	assert_str(_hud.banners.banner_title.text).is_equal(Strings.tf("hud.deploying", [3]))
	_api.fake_phase = GameState.Id.SPAWNING
	_hud.refresh()
	assert_bool(_hud.banners.banner_box.visible).is_false()


func test_the_strip_is_visible_only_when_the_drawer_is_open_in_spawning_or_clearing() -> void:
	var cases: Dictionary = {
		GameState.Id.PREPARING: false, GameState.Id.SPAWNING: true, GameState.Id.CLEARING: true,
		GameState.Id.INTERMISSION: false, GameState.Id.VICTORY: false, GameState.Id.DEFEAT: false,
	}
	for phase: int in cases.keys():
		var want: bool = cases[phase]
		_api.fake_phase = phase
		_hud.close_drawer()
		_hud.refresh()
		assert_bool(_hud.strip.visible).is_false()  # drawer closed: never
		_hud.open_drawer()
		_hud.refresh()
		assert_bool(_hud.strip.visible).is_equal(want)
		assert_str(_hud.strip.label.text).is_equal(Strings.t("hud.strip"))
		_hud.close_drawer()


func test_the_tab_toggles_the_drawer_and_close_drawer_closes_it() -> void:
	assert_bool(_hud.is_drawer_open()).is_false()
	_hud.bottom.tab_button.pressed.emit()
	assert_bool(_hud.is_drawer_open()).is_true()
	assert_bool(_hud.drawer.visible).is_true()
	_hud.close_drawer()
	assert_bool(_hud.is_drawer_open()).is_false()
	_hud.bottom.tab_button.pressed.emit()
	_hud.bottom.tab_button.pressed.emit()
	assert_bool(_hud.is_drawer_open()).is_false()
	assert_int(_api.calls.size()).is_equal(0)  # opening a drawer is not a command


func test_the_intermission_panel_opens_on_intermission_started() -> void:
	assert_bool(_hud.intermission.visible).is_false()
	_api.fake_phase = GameState.Id.INTERMISSION
	_api.fake_phase_ticks_left = 480
	Events.intermission_started.emit(2, 480)
	assert_bool(_hud.intermission.visible).is_true()
	assert_bool(_hud.is_drawer_open()).is_true()  # the drawer opens by itself
	assert_str(_hud.intermission.title_label.text).is_equal(Strings.tf("hud.intermission.cleared", [2]))
	assert_str(_hud.intermission.countdown_label.text).is_equal(Strings.tf("hud.intermission.next", [8]))
	_api.fake_phase_ticks_left = 130
	_hud.refresh()
	assert_str(_hud.intermission.countdown_label.text).is_equal(Strings.tf("hud.intermission.next", [3]))
	assert_bool(_hud.strip.visible).is_false()  # no "combat continues" in a quiet moment


func test_continue_calls_skip_intermission_once() -> void:
	_api.fake_phase = GameState.Id.INTERMISSION
	Events.intermission_started.emit(1, 480)
	assert_str(_hud.intermission.continue_button.text).is_equal(Strings.t("hud.intermission.continue"))
	_hud.intermission.continue_button.pressed.emit()
	var skips: Array[Dictionary] = CombatHudTestKit.calls_of(_api, "skip_intermission")
	assert_int(skips.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)


func test_the_drawer_that_opened_itself_closes_at_the_next_wave_but_a_chosen_one_stays() -> void:
	_api.fake_phase = GameState.Id.INTERMISSION
	Events.intermission_started.emit(1, 480)
	assert_bool(_hud.is_drawer_open()).is_true()
	_api.fake_phase = GameState.Id.SPAWNING
	Events.wave_started.emit(2)
	assert_bool(_hud.is_drawer_open()).is_false()
	_hud.open_drawer()  # the player chose this one
	Events.wave_started.emit(3)
	assert_bool(_hud.is_drawer_open()).is_true()


func test_the_readout_shows_the_magazine_ready_empty_and_reloading() -> void:
	_api.fake_magazine = 9
	_hud.refresh()
	assert_str(_hud.bottom.ammo.mag_label.text).is_equal(Strings.tf("hud.ammo.mag", [9, 12]))
	assert_str(_hud.bottom.ammo.status_label.text).is_equal(Strings.t("hud.ammo.ready"))
	assert_str(_hud.bottom.ammo.weapon_label.text).is_equal(Strings.t("weapon.pistol.name").to_upper())
	_api.fake_magazine = 0
	_hud.refresh()
	assert_str(_hud.bottom.ammo.status_label.text).is_equal(Strings.t("hud.ammo.empty"))
	_api.fake_reload_ticks_left = 50
	Events.reload_started.emit(100)
	assert_str(_hud.bottom.ammo.status_label.text).is_equal(Strings.t("hud.ammo.reloading"))
	assert_bool(_hud.bottom.ammo.reload_bar.visible).is_true()
	assert_float(_hud.bottom.ammo.reload_bar.fraction).is_equal_approx(0.5, 0.001)


func test_the_pause_button_only_emits_pause_requested() -> void:
	var hits: Array[int] = []
	_hud.pause_requested.connect(func() -> void: hits.append(1))
	_hud.top_bar.pause_button.pressed.emit()
	assert_int(hits.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(0)  # Game owns pausing, the HUD only asks


func test_no_visible_label_is_empty_in_any_state() -> void:
	for n: int in 6:
		CombatHudTestKit.drive(_hud, _api, n)
		_hud.refresh()
		assert_array(CombatHudTestKit.empty_visible_labels(_hud)).is_empty()
		for b: BaseButton in CombatHudTestKit.buttons(_hud):
			var btn: Button = b as Button
			if btn != null and btn.is_visible_in_tree():
				var has_words: bool = btn.text != "" or btn.icon != null or CombatHudTestKit.labels(btn).size() > 0
				assert_bool(has_words).is_true()
