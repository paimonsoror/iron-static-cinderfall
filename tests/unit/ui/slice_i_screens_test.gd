extends GdUnitTestSuite
## V3-I: what the slice integration changed in the UI. The menu's RESUME RUN button, the briefing and the results of a
## generated run (wave count, boss wave, the machines the run can field), the crate line of the threat ticker, and the
## draft screen with a used buy-out or a locked draft. Legacy behaviour is pinned next to each change.

var _variety: ContentSet
var _legacy: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_variety = VarietyAKit.slice_content()  # these screens are pinned to the slice: act I, three packs, five machines, the Hulk in wave 5
	_legacy = TestContent.baseline()


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _menu() -> MainMenuScreen:
	var s: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU) as MainMenuScreen
	s.setup(Profile.defaults())
	return s


func _summary(result: int, waves: int) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = "r"
	s.result = result
	s.waves_completed = waves
	s.core_hp = 400
	s.core_max_hp = 1000
	s.duration_ticks = 9000
	s.kills_by_type = PackedInt32Array()
	s.kills_by_type.resize(Ids.ENEMIES.size())
	s.kills_by_type[Ids.EN_SKITTER] = 120
	s.kills_by_type[Ids.EN_MOTE] = 140
	s.kills_by_type[Ids.EN_BURSTER] = 9
	s.kills_by_type[Ids.EN_HULK] = 1
	s.data_reward = 120
	return s


# --- the main menu ---


func test_the_menu_hides_resume_run_until_it_is_told_a_wave() -> void:
	var s: MainMenuScreen = _menu()
	assert_bool(s.resume_button.visible).is_false()
	assert_int(s.resume_wave).is_equal(0)
	s.set_resume_wave(3)
	assert_bool(s.resume_button.visible).is_true()
	assert_str(s.resume_button.text).is_equal(Strings.tf("menu.resume", [3]))
	assert_str(s.resume_button.text).contains("3")
	s.set_resume_wave(0)
	assert_bool(s.resume_button.visible).is_false()
	s.set_resume_wave(-4)
	assert_bool(s.resume_button.visible).is_false()


func test_resume_run_emits_its_signal_and_start_mission_stays() -> void:
	var s: MainMenuScreen = _menu()
	s.set_resume_wave(2)
	var hits: Array[String] = []
	s.resume_pressed.connect(func() -> void: hits.append("resume"))
	s.start_pressed.connect(func() -> void: hits.append("start"))
	s.resume_button.pressed.emit()
	s.start_button.pressed.emit()
	assert_array(hits).is_equal(["resume", "start"])
	await ScreensTestKit.settle(get_tree())
	assert_array(ScreensTestKit.small_buttons(s)).is_empty()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_float(s.resume_button.global_position.y).is_less(s.start_button.global_position.y)  # above START MISSION


func test_the_menu_with_resume_run_keeps_every_button_on_a_square_screen() -> void:
	var view: Vector2 = Vector2(1080.0, 1080.0)
	var s: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU, view) as MainMenuScreen
	s.setup(Profile.defaults())
	s.set_resume_wave(4)
	await ScreensTestKit.settle(get_tree())
	for button: Button in UiKit.buttons(s):
		if button.is_visible_in_tree():
			assert_float(button.global_position.y + button.size.y).is_less_equal(view.y + 0.5)
			assert_float(button.global_position.y).is_greater_equal(-0.5)


# --- the roster of a run ---


func test_the_roster_of_the_slice_is_five_waves_five_machines_and_the_hulk_in_wave_five() -> void:
	assert_int(RunRoster.wave_count(_variety)).is_equal(5)
	var ids: Array[StringName] = []
	for def: EnemyDef in RunRoster.enemies(_variety):
		ids.append(def.id)
	assert_array(ids).is_equal([&"skitter", &"hollow_warden", &"siege_hulk", &"mote", &"burster"])  # content order; no rusher
	var bosses: Array[Dictionary] = RunRoster.boss_waves(_variety)
	assert_int(bosses.size()).is_equal(1)
	var boss: EnemyDef = bosses[0]["enemy"]
	assert_str(String(boss.id)).is_equal("siege_hulk")
	assert_int(bosses[0]["wave"]).is_equal(5)


func test_the_roster_of_the_legacy_content_is_the_old_four() -> void:
	assert_int(RunRoster.wave_count(_legacy)).is_equal(5)
	assert_int(RunRoster.enemies(_legacy).size()).is_equal(4)
	assert_int(RunRoster.boss_waves(_legacy).size()).is_equal(1)
	assert_int(RunRoster.wave_count(null)).is_equal(0)
	assert_int(RunRoster.enemies(null).size()).is_equal(0)


func test_a_boss_wave_with_two_candidates_is_not_named() -> void:
	var second: BossDef = BossDef.new()
	second.id = &"brood_carrier"
	second.enemy_index = Ids.EN_BROOD_CARRIER
	second.pool_act = 1
	_variety.bosses.append(second)
	assert_int(RunRoster.boss_waves(_variety).size()).is_equal(0)  # the plan of the seed decides; the briefing cannot know
	assert_bool(RunRoster.enemies(_variety).has(_variety.enemies[Ids.EN_BROOD_CARRIER])).is_true()


func test_the_briefing_of_a_generated_run_lists_its_waves_boss_and_threats() -> void:
	var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING) as BriefingScreen
	s.setup(_variety)
	assert_int(s.objective_labels.size()).is_equal(3)
	assert_str(s.objective_labels[0].text).is_equal(Strings.tf("briefing.obj.waves", [5]))
	assert_str(s.objective_labels[2].text).is_equal(Strings.tf("briefing.obj.boss", [Strings.t("enemy.siege_hulk.name"), 5]))
	var ids: Array[StringName] = []
	for row: BriefingThreatRow in s.threat_rows:
		ids.append(row.glyph.enemy_id)
		assert_str(row.name_label.text).is_not_empty()
		assert_bool(row.desc_label.text.begins_with("#")).is_false()  # every machine has its lore.threat line
	assert_array(ids).is_equal([&"mote", &"skitter", &"burster", &"hollow_warden", &"siege_hulk"])  # weakest first
	for i: int in s.threat_rows.size():
		assert_int(s.threat_rows[i].chevrons.count).is_equal(i + 1)
		assert_int(s.threat_rows[i].chevrons.max_count).is_equal(5)
	# the new types are drawn by RunEnemyGlyph (the kit glyph knows the old four only)
	assert_bool(s.threat_rows[0].glyph.hide_art).is_true()
	assert_int(VarietyEKit.nodes_of(s.threat_rows[0], RunEnemyGlyph).size()).is_equal(1)
	assert_bool(s.threat_rows[1].glyph.hide_art).is_false()
	assert_int(VarietyEKit.nodes_of(s.threat_rows[1], RunEnemyGlyph).size()).is_equal(0)
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()


func test_the_briefing_fits_a_1080x1920_screen_with_five_threats() -> void:
	var view: Vector2 = Vector2(1080.0, 1920.0)
	var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING, view) as BriefingScreen
	s.setup(_variety)
	await ScreensTestKit.settle(get_tree())
	for button: Button in [s.deploy_button, s.back_button]:
		assert_float(button.global_position.y + button.size.y).is_less_equal(view.y + 0.5)
	assert_array(ScreensTestKit.small_buttons(s)).is_empty()


func test_the_results_of_a_generated_run_show_its_waves_and_its_kills() -> void:
	var s: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS) as ResultsScreen
	s.setup(_summary(RunResult.Id.DEFEAT, 3), _variety, Profile.defaults(), true)
	assert_str(s.waves_cell.value.text).is_equal("3/5")
	assert_int(s.kill_rows.size()).is_equal(5)  # skitter, hollow warden, siege hulk, mote, burster
	var counts: Array[String] = []
	for l: Label in s.kill_rows:
		counts.append(l.text)
	assert_array(counts).is_equal(["120", "0", "1", "140", "9"])
	assert_str(s.kills_cell.value.text).is_equal("270")
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	var legacy: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS) as ResultsScreen
	legacy.setup(_summary(RunResult.Id.VICTORY, 5), _legacy, Profile.defaults(), true)
	assert_str(legacy.waves_cell.value.text).is_equal("5/5")
	assert_int(legacy.kill_rows.size()).is_equal(4)


func test_the_results_fit_a_1080x1920_screen_with_five_kill_rows() -> void:
	var view: Vector2 = Vector2(1080.0, 1920.0)
	var s: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS, view) as ResultsScreen
	s.setup(_summary(RunResult.Id.VICTORY, 5), _variety, Profile.defaults(), true)
	await ScreensTestKit.settle(get_tree())
	for button: Button in [s.retry_button, s.menu_button]:
		assert_float(button.global_position.y + button.size.y).is_less_equal(view.y + 0.5)
		assert_float(button.global_position.y).is_greater_equal(0.0)


# --- the threat ticker ---


func test_the_ticker_shows_the_crate_on_the_field_first() -> void:
	var ticker: HudThreatTicker = HudThreatTicker.new()
	auto_free(ticker)
	add_child(ticker)
	var none: Array[Dictionary] = []
	ticker.refresh(none, _variety)
	assert_int(ticker.visible_lines()).is_equal(0)
	ticker.refresh(none, _variety, {"contested": false, "ticks_left": 420, "ticks_total": 720, "life_left": 2000})
	assert_int(ticker.visible_lines()).is_equal(1)
	assert_str(ticker.lines[0].text_label.text).is_equal(Strings.tf("hud.ticker.on", [Strings.t("event.supply_drop.name"), 7]))
	assert_bool(ticker.lines[0].harmful).is_false()
	assert_bool(ticker.lines[0].bar.visible).is_true()
	assert_float(ticker.lines[0].bar.fraction).is_equal_approx(300.0 / 720.0, 0.001)  # the bar fills while the area is clear
	ticker.refresh(none, _variety, {"contested": true, "ticks_left": 420, "ticks_total": 720, "life_left": 2000})
	assert_str(ticker.lines[0].text_label.text).is_equal(Strings.t("hud.crate.contested"))
	assert_bool(ticker.lines[0].harmful).is_true()  # red, a warning triangle, and the word
	var strike: Array[Dictionary] = [
		{"id": &"deadfall_strike", "phase": 0, "ticks_left": 90, "ticks_total": 120, "harmful": false, "x": 0.0, "z": 0.0},
	]
	ticker.refresh(strike, _variety, {"contested": false, "ticks_left": 60, "ticks_total": 720, "life_left": 2000})
	assert_int(ticker.visible_lines()).is_equal(2)
	assert_str(ticker.lines[1].text_label.text).contains(Strings.t("event.deadfall_strike.name"))
	ticker.refresh(strike, _variety)
	assert_int(ticker.visible_lines()).is_equal(1)  # the crate is gone: its line with it


func test_the_combat_hud_feeds_the_crate_status_to_the_ticker() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	var before: int = hud.banners.ticker.visible_lines()
	api.fake_crate_status = {"contested": false, "ticks_left": 600, "ticks_total": 720, "life_left": 2000, "x": 0.0, "z": 0.0}
	Events.crate_dropped.emit(0.0, 0.0)
	assert_int(hud.banners.ticker.visible_lines()).is_equal(before + 1)
	assert_str(hud.banners.ticker.lines[0].text_label.text).contains(Strings.t("event.supply_drop.name"))
	api.fake_crate_status = {}
	Events.crate_secured.emit()
	assert_int(hud.banners.ticker.visible_lines()).is_equal(before)


# --- the wave banner ---


func test_the_wave_banner_of_a_generated_run_names_the_pack_and_the_modifier() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	api.fake_wave_route = {"name_key": "pack.powder.name", "modifier_key": "modifier.volatile.name"}
	Events.wave_started.emit(3)
	assert_str(hud.banners.banner_title.text).is_equal(Strings.tf("hud.banner.wave", [3]))
	assert_str(hud.banners.banner_whisper.text).is_equal("%s // %s" % [Strings.t("pack.powder.name"), Strings.t("modifier.volatile.name")])
	api.fake_wave_route = {"name_key": "pack.tide.name", "modifier_key": ""}
	Events.wave_started.emit(4)
	assert_str(hud.banners.banner_whisper.text).is_equal(Strings.t("pack.tide.name"))
	api.fake_wave_route = {"name_key": "", "modifier_key": ""}  # a boss wave: the boss banner follows on its own
	Events.wave_started.emit(5)
	assert_str(hud.banners.banner_whisper.text).is_equal("")
	for n: int in [2, 3, 4]:  # never the lines of the five scripted waves
		assert_str(hud.banners.banner_whisper.text).is_not_equal(Strings.t("hud.whisper.%d" % n))


func test_the_legacy_hud_keeps_its_wave_whispers() -> void:
	var api: FakeRunApi = FakeRunApi.new()
	var packed: PackedScene = load(VarietyEKit.HUD) as PackedScene
	var hud: CombatHud = packed.instantiate() as CombatHud
	VarietyEKit.host(self, VarietyEKit.SIZES[0]).add_child(hud)
	hud.setup(api, _legacy, null)
	Events.wave_started.emit(2)
	assert_str(hud.banners.banner_whisper.text).is_equal(Strings.t("hud.whisper.2"))


# --- the draft screen ---


func test_a_used_buy_out_takes_the_keep_also_buttons_away() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("draft")
	var o: DraftOverlay = VarietyEKit.overlay(self, "draft", api) as DraftOverlay
	o.cards[0].tap()
	assert_bool(o.cards[1].buyout_button.visible).is_true()
	api.fake_buyout_used = true
	o.refresh()
	assert_bool(o.cards[1].buyout_button.visible).is_false()
	assert_bool(o.cards[2].buyout_button.visible).is_false()
	o.cards[1].buyout_toggled.emit()  # a tap that was already under way stages nothing
	assert_int(o.buyout_slot).is_equal(-1)
	o.confirm_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(api, "buy_out").size()).is_equal(0)
	assert_int(VarietyEKit.calls_of(api, "pick_directive").size()).is_equal(1)


func test_a_locked_draft_refuses_reroll_and_patch_with_the_reason() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("draft")
	api.fake_scrap = 5000
	api.fake_draft_locked = true
	var o: DraftOverlay = VarietyEKit.overlay(self, "draft", api) as DraftOverlay
	assert_float(o.reroll_button.modulate.a).is_less(1.0)
	assert_float(o.patch_button.modulate.a).is_less(1.0)
	o.reroll_button.pressed.emit()
	o.patch_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(api, "reroll_draft").size()).is_equal(0)
	assert_int(VarietyEKit.calls_of(api, "patch_core").size()).is_equal(0)
	assert_str(o.notice_label.text).is_equal(Strings.t("reason.locked_by_event"))
	api.fake_draft_locked = false
	o.refresh()
	assert_float(o.reroll_button.modulate.a).is_equal(1.0)
	o.reroll_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(api, "reroll_draft").size()).is_equal(1)
