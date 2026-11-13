extends GdUnitTestSuite
## The variety combat HUD (VARIETY_SPEC 11.4): the threat ticker, the act line, offline abilities, boss pips, the act banner,
## the breather panel, the untouched legacy HUD and High Contrast.

var _api: FakeRunApi
var _hud: CombatHud


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("combat2")
	_hud = VarietyEKit.hud(self, _api)


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _bar() -> HudWeaponBar:
	return _hud.bottom.weapon_bar


func test_the_ticker_shows_the_warning_with_a_countdown_and_a_filling_bar() -> void:
	var line: HudTickerLine = _hud.banners.ticker.lines[0]
	assert_bool(line.visible).is_true()
	assert_str(line.text_label.text).is_equal(Strings.tf("hud.ticker.in", [Strings.t("event.deadfall_strike.name"), 2]))
	assert_float(line.bar.fraction).is_equal_approx(0.25, 0.01)
	assert_bool(line.harmful).is_false()
	assert_int(_hud.banners.ticker.visible_lines()).is_equal(1)


func test_the_ticker_shows_at_most_three_lines_and_a_harmful_one_has_the_warning_mark() -> void:
	for i: int in 4:
		_api.fake_active_events.append({"id": &"static_front", "phase": 1, "ticks_left": 300, "ticks_total": 720, "harmful": true, "x": 0.0, "z": 0.0})
	_hud.refresh()
	assert_int(_hud.banners.ticker.visible_lines()).is_equal(3)
	var line: HudTickerLine = _hud.banners.ticker.lines[1]
	assert_bool(line.harmful).is_true()
	assert_str(line.text_label.text).is_equal(Strings.tf("hud.ticker.on", [Strings.t("event.static_front.name"), 5]))
	assert_object(line.icon_rect.texture).is_not_null()
	# V4-U priorities: harmful running lines outrank the helpful Deadfall warning, which waits behind them (it is not shown)
	for shown: HudTickerLine in _hud.banners.ticker.lines:
		assert_bool(shown.harmful).is_true()
		assert_str(shown.text_label.text).not_contains(Strings.t("event.deadfall_strike.name"))


func test_an_elite_entering_the_field_is_a_ticker_notice() -> void:
	Events.elite_spawned.emit(7, &"rusher", 1)
	var shown: int = _hud.banners.ticker.visible_lines()
	assert_int(shown).is_equal(2)
	assert_str(_hud.banners.ticker.lines[1].text_label.text).contains(Strings.t("enemy.rusher.name").to_upper())
	assert_str(_hud.banners.ticker.lines[1].text_label.text).contains(Strings.t("affix.plated.name"))


func test_the_top_bar_shows_the_act_and_the_wave_of_the_run() -> void:
	assert_str(_hud.top_bar.wave_label.text).is_equal("%s\n%s" % [Strings.tf("act.label", ["I"]), Strings.tf("hud.wave_short", [3, 5])])
	assert_bool(_hud.top_bar.core_value_label.visible).is_false()
	_api.fake_shield_hp = 70.0
	_hud.refresh()
	assert_bool(_hud.top_bar.shield_icon.visible).is_true()


func test_an_ability_locked_by_a_static_front_reads_offline_by_word_and_pattern() -> void:
	_api.fake_ability_block[&"emp"] = Reason.Id.LOCKED_BY_EVENT
	_api.fake_ability_cooldown_left[&"emp"] = 600
	_hud.refresh()
	var b: HudAbilityButton = _hud.bottom.abilities.buttons[&"emp"]
	assert_int(b.state).is_equal(HudAbilityButton.State.OFFLINE)
	assert_str(b.state_label.text).is_equal(Strings.t("hud.ability.offline"))
	assert_bool(b.static_overlay.visible).is_true()
	b.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_the_boss_bar_names_the_node_and_shows_phase_pips() -> void:
	_api.fake_boss_hp = 4000.0
	_api.fake_boss_phase = 1
	_api.fake_boss_phase_count = 3
	Events.boss_spawned.emit(1, &"siege_hulk")
	assert_str(_hud.banners.boss_bar.name_label.text).is_equal(Strings.t("boss.siege_hulk.name"))
	assert_bool(_hud.banners.boss_bar.pips.visible).is_true()
	assert_int(_hud.banners.boss_bar.pips.count).is_equal(3)
	assert_int(_hud.banners.boss_bar.pips.phase).is_equal(1)
	assert_str(_hud.banners.banner_whisper.text).is_equal(Strings.t("boss.siege_hulk.banner"))


func test_the_act_start_banner_names_the_act_and_its_plating_tier() -> void:
	Events.act_started.emit(2)
	assert_str(_hud.banners.banner_title.text).is_equal(Strings.tf("hud.act_banner.title", ["II", Strings.t("act.gantry.name")]))
	assert_str(_hud.banners.banner_whisper.text).is_equal(Strings.tf("act.tier", [2]))


func test_the_breather_panel_shows_only_while_no_choice_is_open() -> void:
	_api.fake_phase = GameState.Id.INTERMISSION
	_api.fake_awaiting = RunApi.AWAIT_DRAFT
	_hud.refresh()
	assert_bool(_hud.intermission.visible).is_false()
	_api.fake_awaiting = RunApi.AWAIT_NONE
	_api.fake_phase_ticks_left = 120
	_hud.refresh()
	assert_bool(_hud.intermission.visible).is_true()


func test_the_legacy_content_keeps_the_legacy_hud() -> void:
	var legacy: CombatHud = CombatHudTestKit.make_hud(self, FakeRunApi.new())
	assert_bool(legacy.variety.active).is_false()
	assert_bool(legacy.bottom.tab_button.visible).is_true()
	assert_bool(legacy.bottom.weapon_bar.visible).is_false()
	assert_float(legacy.bottom_band_px()).is_equal_approx(1920.0 * 0.23, 0.01)
	assert_bool(legacy.banners.ticker.visible).is_false()


func test_high_contrast_outlines_the_weapon_bar_text() -> void:
	Save.set_setting(&"high_contrast", true)
	var hud: CombatHud = VarietyEKit.hud(self, _api)
	var card: HudWeaponCard = hud.bottom.weapon_bar.cards[0]
	assert_int(card.name_label.get_theme_constant(&"outline_size")).is_greater_equal(5)
	assert_int(hud.bottom.weapon_bar.strike.name_label.get_theme_constant(&"outline_size")).is_greater_equal(5)
