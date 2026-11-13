extends GdUnitTestSuite
## V4-U: the kit selector (GDD 8.5), the briefing that carries it, and the main menu additions (ARCHIVE, DAILY RUN, BEST WAVE)
## plus the Archive overlay the menu opens by itself. Driven through ArchiveBank / Profile objects, so none of it needs the
## profile v2 of task V4-M: its fields are read through MetaProfile, which answers neutral values without them.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = V4uKit.content()


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _selector(bank: ArchiveBank, view: Vector2 = Vector2(1080.0, 1920.0)) -> KitSelector:
	var node: KitSelector = KitSelector.new()
	V4uKit.host(self, view).add_child(node)
	node.setup(bank.profile, _cs, bank)
	return node


# --- the kit selector ---


func test_the_selector_lists_every_kit_and_marks_the_chosen_one() -> void:
	var bank: ArchiveBank = ArchiveBank.new(V4uKit.profile(0, ["k_breacher"]), _cs)
	bank.set_kit(&"k_breacher")
	var s: KitSelector = _selector(bank)
	assert_int(s.cards.size()).is_equal(6)
	assert_str(String(s.selected_id)).is_equal("k_breacher")
	assert_str(s.card_of(&"k_breacher").state_label.text).is_equal(Strings.t("kit.selected"))
	assert_str(s.card_of(&"k_standard").state_label.text).is_equal(Strings.t("kit.pick"))
	assert_str(s.card_of(&"k_gambler").state_label.text).is_equal(Strings.t("kit.locked"))
	assert_str(s.rules_label.text).is_equal(Strings.t("kit.breacher.desc"))
	assert_bool(s.visible).is_true()


func test_a_kit_that_is_not_owned_falls_back_to_the_standard_kit() -> void:
	var bank: ArchiveBank = ArchiveBank.new(V4uKit.profile(0), _cs)
	bank.set_kit(&"k_gunline")  # a stale choice: not owned
	var s: KitSelector = _selector(bank)
	assert_str(String(s.selected_id)).is_equal("k_standard")


func test_tapping_an_owned_kit_writes_it_and_emits_and_a_locked_one_only_reads_its_hint() -> void:
	var bank: ArchiveBank = ArchiveBank.new(V4uKit.profile(0, ["k_ledger"]), _cs)
	var s: KitSelector = _selector(bank)
	var picked: Array[StringName] = []
	s.kit_selected.connect(func(id: StringName) -> void: picked.append(id))
	s.card_of(&"k_ledger").tap()
	assert_array(picked).is_equal([&"k_ledger"])
	assert_str(String(bank.kit())).is_equal("k_ledger")
	assert_str(s.card_of(&"k_ledger").state_label.text).is_equal(Strings.t("kit.selected"))
	assert_str(s.card_of(&"k_standard").state_label.text).is_equal(Strings.t("kit.pick"))
	s.card_of(&"k_gambler").tap()
	assert_array(picked).is_equal([&"k_ledger"])  # nothing new
	assert_str(String(bank.kit())).is_equal("k_ledger")
	assert_str(s.rules_label.text).contains(Strings.t("kit.locked_hint"))
	assert_bool(s.select(&"k_nope")).is_false()


func test_the_selector_is_hidden_on_a_content_with_one_kit() -> void:
	var legacy: ContentSet = TestContent.baseline()
	var node: KitSelector = KitSelector.new()
	V4uKit.host(self, Vector2(1080.0, 1920.0)).add_child(node)
	node.setup(Profile.defaults(), legacy, ArchiveBank.new(Profile.defaults(), legacy))
	assert_bool(node.visible).is_false()


func test_the_kit_cards_are_touch_sized_and_scroll_sideways() -> void:
	var s: KitSelector = _selector(ArchiveBank.new(V4uKit.profile(0), _cs))
	await V4uKit.settle(get_tree())
	for card: KitCard in s.cards:
		assert_float(card.size.y).is_greater_equal(132.0)
		assert_float(card.size.x).is_greater_equal(KitCard.WIDTH - 1.0)
	assert_int(s.scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
	for label: Label in UiKit.labels(s):
		if label.is_visible_in_tree() and label.text != "":
			assert_int(label.get_theme_font_size(&"font_size")).is_greater_equal(30)


func test_the_save_bound_selector_writes_the_kit_into_the_profile() -> void:
	Save.profile.unlocks.append("k_signal")
	var node: KitSelector = KitSelector.new()
	V4uKit.host(self, Vector2(1080.0, 1920.0)).add_child(node)
	node.setup(Save.profile, _cs)
	node.card_of(&"k_signal").tap()
	assert_str(String(Save.profile.kit)).is_equal("k_signal")


# --- the briefing ---


func test_the_briefing_of_a_generated_run_carries_the_kit_selector_above_deploy() -> void:
	var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING) as BriefingScreen
	s.setup(_cs)
	await V4uKit.settle(get_tree())
	assert_bool(s.kit_selector.visible).is_true()
	assert_int(s.kit_selector.cards.size()).is_equal(6)
	assert_float(s.kit_selector.global_position.y).is_less(s.deploy_button.global_position.y)
	assert_str(s.radio_label.text).contains("three pushes")  # the approved briefing of GDD 2.3


func test_the_briefing_of_the_legacy_content_has_no_kit_selector() -> void:
	var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING) as BriefingScreen
	s.setup(TestContent.baseline())
	assert_bool(s.kit_selector.visible).is_false()


# --- the main menu ---


func _menu(profile: Profile, view: Vector2 = Vector2(1080.0, 2400.0)) -> MainMenuScreen:
	var s: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU, view) as MainMenuScreen
	s.setup(profile)
	return s


func test_the_menu_has_an_archive_button_that_opens_the_archive_over_it() -> void:
	var s: MainMenuScreen = _menu(Profile.defaults())
	var hits: Array[bool] = []
	s.archive_pressed.connect(func() -> void: hits.append(true))
	s.archive_button.pressed.emit()
	assert_array(hits).is_equal([true])
	assert_object(s.archive_screen).is_not_null()
	assert_bool(s.archive_screen.is_inside_tree()).is_true()
	s.archive_screen.close()
	await V4uKit.settle(get_tree())
	assert_object(s.archive_screen).is_null()


func test_the_game_layer_can_keep_the_archive_for_itself() -> void:
	var s: MainMenuScreen = _menu(Profile.defaults())
	s.open_archive_overlay = false
	var hits: Array[bool] = []
	s.archive_pressed.connect(func() -> void: hits.append(true))
	s.archive_button.pressed.emit()
	assert_array(hits).is_equal([true])
	assert_object(s.archive_screen).is_null()


func test_daily_run_appears_after_the_first_act_one_boss_kill_and_says_how_today_went() -> void:
	var p: Profile = Profile.defaults()
	var s: MainMenuScreen = _menu(p)
	assert_bool(s.daily_visible()).is_false()
	# the v2 fields are read through Object.get: a profile without them (this build) answers "no boss killed yet"
	assert_bool(MetaProfile.act_one_boss_killed(p, _cs)).is_false()
	assert_int(MetaProfile.best_wave(p)).is_equal(0)
	var daily_date: String = MetaProfile.daily(p)["date"]
	assert_str(daily_date).is_equal("")
	var act_one: BossDef = null
	for boss: BossDef in _cs.bosses:
		if boss.pool_act == 1:
			act_one = boss
	assert_object(act_one).is_not_null()
	assert_bool(MetaProfile.act_one_boss_killed_in({String(act_one.id): 1}, _cs)).is_true()
	assert_bool(MetaProfile.act_one_boss_killed_in({act_one.id: 2.0}, _cs)).is_true()  # a JSON number that stayed a float
	assert_bool(MetaProfile.act_one_boss_killed_in({"siege_hulk": 0}, _cs)).is_false()
	assert_bool(MetaProfile.act_one_boss_killed_in({}, _cs)).is_false()


func test_the_menu_shows_the_best_wave_in_place_of_missions_held_on_a_generated_run() -> void:
	var s: MainMenuScreen = _menu(Profile.defaults())
	assert_bool(s.wave_cell.visible).is_true()
	assert_bool(s.missions_cell.visible).is_false()
	assert_str(s.wave_cell.value.text).is_equal(Strings.t("menu.none"))


func test_the_menu_buttons_fit_a_square_screen_and_every_aspect() -> void:
	for view: Vector2 in [Vector2(1080.0, 1080.0), Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0), V4uKit.NARROW]:
		var s: MainMenuScreen = _menu(Profile.defaults(), view)
		s.set_resume_wave(3)
		await V4uKit.settle(get_tree())
		assert_array(ScreensTestKit.bad_texts(s)).is_empty()
		for b: Button in UiKit.buttons(s):
			if b.is_visible_in_tree():
				assert_float(b.size.y).is_greater_equal(132.0)
				assert_float(b.global_position.x).is_greater_equal(-0.5)
				assert_float(b.global_position.x + b.size.x).is_less_equal(view.x + 0.5)
				assert_float(b.global_position.y + b.size.y).override_failure_message("%s at %s" % [b.text, view]).is_less_equal(view.y + 0.5)


func test_the_new_tagline_and_victory_lines_are_the_approved_ones() -> void:
	assert_str(Strings.t("lore.tagline")).is_equal("Hold the line at Relay Core B-4. Three pushes. One Warden.")
	assert_str(Strings.t("lore.results.victory")).is_equal("B-4 is still warm. Node 9 is not. The yards hold. Flint is still standing. Accord out.")
	assert_str(Strings.t("lore.briefing.text")).starts_with("B-4 is still warm. The perimeter is gone and Cinder cannot turn around.")
	assert_str(Strings.t("lore.briefing.text")).ends_with("Count what you bring back. Accord out.")
	assert_str(Strings.t("lore.results.defeat")).is_equal("relay core b-4: offline. wardens active at b-4: 0. network preserved.")


func test_the_back_gesture_closes_the_archive_overlay_before_anything_else() -> void:
	var s: MainMenuScreen = _menu(Profile.defaults())
	assert_bool(s.close_overlay()).is_false()  # nothing open: the game layer handles back itself
	s.archive_button.pressed.emit()
	assert_bool(s.close_overlay()).is_true()
	await V4uKit.settle(get_tree())
	assert_object(s.archive_screen).is_null()
	assert_bool(s.close_overlay()).is_false()
