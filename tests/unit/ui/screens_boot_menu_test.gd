extends GdUnitTestSuite
## BootScreen and MainMenuScreen: filled labels, once-only signals, touch sizes, the profile totals.


func before_test() -> void:
	ScreensTestKit.fresh_save()


func _boot() -> BootScreen:
	var s: BootScreen = ScreensTestKit.screen(self, ScreensTestKit.BOOT) as BootScreen
	s.setup("0.1.0")
	return s


func _menu(profile: Profile = null) -> MainMenuScreen:
	var s: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU) as MainMenuScreen
	s.setup(profile if profile != null else Profile.defaults())
	return s


func test_boot_fills_every_label_and_shows_the_version() -> void:
	var s: BootScreen = _boot()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_str(s.version_label.text).contains("0.1.0")
	assert_str(s.title_block.main_label.text).is_equal(Strings.t("boot.title_main"))
	assert_str(s.tagline_label.text).is_equal(Strings.t("lore.tagline"))
	assert_int(s.status_labels.size()).is_equal(3)


func test_boot_continue_emits_finished_once_even_when_pressed_twice() -> void:
	var s: BootScreen = _boot()
	var hits: Array[int] = [0]
	s.finished.connect(func() -> void: hits[0] += 1)
	s.continue_button.pressed.emit()
	s.continue_button.pressed.emit()
	assert_int(hits[0]).is_equal(1)


func test_boot_ends_by_itself_within_three_seconds_and_only_once() -> void:
	assert_float(BootScreen.AUTO_SECONDS).is_less_equal(3.0)
	var s: BootScreen = _boot()
	var hits: Array[int] = [0]
	s.finished.connect(func() -> void: hits[0] += 1)
	s._process(BootScreen.AUTO_SECONDS * 0.5)
	assert_int(hits[0]).is_equal(0)
	assert_float(s.progress.value).is_between(40.0, 60.0)
	s._process(BootScreen.AUTO_SECONDS)
	s._process(1.0)
	s.continue_button.pressed.emit()
	assert_int(hits[0]).is_equal(1)


func test_menu_shows_the_profile_totals_grouped() -> void:
	var p: Profile = Profile.defaults()
	p.data = 12450
	p.best_core_hp = 620
	p.missions_completed = 3
	var s: MainMenuScreen = _menu(p)
	assert_str(s.data_cell.value.text).is_equal("12,450")
	assert_str(s.best_core_cell.value.text).is_equal("620")
	assert_str(s.missions_cell.value.text).is_equal("3")
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()


func test_menu_of_a_new_profile_shows_zero_data_and_no_best_core_yet() -> void:
	var s: MainMenuScreen = _menu()
	assert_str(s.data_cell.value.text).is_equal("0")
	assert_str(s.best_core_cell.value.text).is_equal(Strings.t("menu.none"))
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()


func test_each_menu_button_emits_its_signal_once() -> void:
	var s: MainMenuScreen = _menu()
	var hits: Array[String] = []
	s.start_pressed.connect(func() -> void: hits.append("start"))
	s.settings_pressed.connect(func() -> void: hits.append("settings"))
	s.quit_pressed.connect(func() -> void: hits.append("quit"))
	s.start_button.pressed.emit()
	assert_array(hits).is_equal(["start"])
	s.settings_button.pressed.emit()
	s.quit_button.pressed.emit()
	assert_array(hits).is_equal(["start", "settings", "quit"])
	var shown: int = 0
	for button: Button in UiKit.buttons(s):
		shown += 1 if button.visible else 0
	assert_int(shown).is_equal(3)  # RESUME RUN (V3-I) is the fourth button and stays hidden without a saved run
	assert_int(UiKit.buttons(s).size()).is_equal(4)


func test_menu_and_boot_buttons_are_at_least_132_px_and_the_primary_148() -> void:
	var m: MainMenuScreen = _menu()
	var b: BootScreen = _boot()
	await ScreensTestKit.settle(get_tree())
	assert_array(ScreensTestKit.small_buttons(m)).is_empty()
	assert_array(ScreensTestKit.small_buttons(b)).is_empty()
	assert_float(m.start_button.size.y).is_greater_equal(148.0)
	assert_float(b.continue_button.size.y).is_greater_equal(148.0)


func test_the_footer_buttons_stay_on_screen_from_tall_phones_to_square() -> void:
	for view: Vector2 in [Vector2(1080.0, 2400.0), Vector2(1080.0, 1920.0), Vector2(1080.0, 1080.0)]:
		var screens: Array[Control] = [
			ScreensTestKit.screen(self, ScreensTestKit.BOOT, view),
			ScreensTestKit.screen(self, ScreensTestKit.MENU, view),
			ScreensTestKit.screen(self, ScreensTestKit.SETTINGS, view),
		]
		(screens[0] as BootScreen).setup("0.1.0")
		(screens[1] as MainMenuScreen).setup(Profile.defaults())
		(screens[2] as SettingsScreen).setup()
		await ScreensTestKit.settle(get_tree())
		for s: Control in screens:
			var frame: UiScreenFrame = s.get_child(0) as UiScreenFrame
			assert_int(UiKit.buttons(frame.footer).size()).is_greater(0)
			for button: Button in UiKit.buttons(frame.footer):
				var r: Rect2 = Rect2(button.global_position, button.size)
				assert_float(r.end.y).is_less_equal(view.y + 0.5)
				assert_float(r.end.x).is_less_equal(view.x + 0.5)
				assert_float(r.position.x).is_greater_equal(-0.5)
