extends GdUnitTestSuite
## SettingsScreen: every control writes through Save.set_setting with the right key and type, and applies at once.

var _changed: Array[StringName] = []
var _saved_max_fps: int = 0


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_changed.clear()
	_saved_max_fps = Engine.max_fps
	Events.settings_changed.connect(_on_changed)


func after_test() -> void:
	if Events.settings_changed.is_connected(_on_changed):
		Events.settings_changed.disconnect(_on_changed)
	Engine.max_fps = _saved_max_fps
	ScreensTestKit.fresh_save()


func _on_changed(key: StringName) -> void:
	_changed.append(key)


func _settings() -> SettingsScreen:
	var s: SettingsScreen = ScreensTestKit.screen(self, ScreensTestKit.SETTINGS) as SettingsScreen
	s.setup()
	return s


func test_setup_fills_every_label_with_no_placeholder_and_writes_nothing() -> void:
	var s: SettingsScreen = _settings()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_array(_changed).is_empty()
	assert_int(s.toggle_rows.size()).is_equal(6)  # V4-U: + Swap assist
	assert_str(s.header_plate.label.text).is_equal(Strings.t("settings.title").to_upper())


func test_setup_shows_the_stored_values() -> void:
	Save.set_setting(&"sound_on", false)
	Save.set_setting(&"high_contrast", true)
	Save.set_setting(&"quality", 0)
	Save.set_setting(&"fps_cap", 30)
	var s: SettingsScreen = _settings()
	assert_bool(s.toggle_rows[&"sound_on"].is_on()).is_false()
	assert_bool(s.toggle_rows[&"music_on"].is_on()).is_true()
	assert_bool(s.toggle_rows[&"high_contrast"].is_on()).is_true()
	assert_int(s.quality_row.value()).is_equal(0)
	assert_int(s.fps_row.value()).is_equal(30)
	assert_str(s.toggle_rows[&"sound_on"].switch.text).is_equal(Strings.t("settings.off"))
	assert_str(s.toggle_rows[&"music_on"].switch.text).is_equal(Strings.t("settings.on"))


func test_each_toggle_writes_its_own_key_as_a_bool() -> void:
	var s: SettingsScreen = _settings()
	for key: StringName in [&"sound_on", &"music_on", &"haptics_on", &"reduced_flash", &"high_contrast"]:
		var row: UiToggleRow = s.toggle_rows[key]
		var was: bool = row.is_on()
		_changed.clear()
		row.switch.button_pressed = not was
		assert_array(_changed).is_equal([key])
		var stored: Variant = Save.get_setting(key)
		assert_int(typeof(stored)).is_equal(TYPE_BOOL)
		assert_bool(stored).is_equal(not was)
		assert_str(row.switch.text).is_equal(Strings.t("settings.on" if not was else "settings.off"))


func test_quality_writes_an_int_between_0_and_2() -> void:
	var s: SettingsScreen = _settings()
	assert_int(s.quality_row.buttons.size()).is_equal(3)
	for i: int in [0, 1, 2]:
		_changed.clear()
		s.quality_row.buttons[i].pressed.emit()
		var stored: Variant = Save.get_setting(&"quality")
		assert_int(typeof(stored)).is_equal(TYPE_INT)
		assert_int(stored).is_equal(i)
		assert_bool(_changed.has(&"quality")).is_true()


func test_the_fps_cap_writes_30_or_60_as_an_int_and_sets_the_engine_cap_at_once() -> void:
	var s: SettingsScreen = _settings()
	s.fps_row.buttons[0].pressed.emit()
	var stored: Variant = Save.get_setting(&"fps_cap")
	assert_int(typeof(stored)).is_equal(TYPE_INT)
	assert_int(stored).is_equal(30)
	assert_int(Engine.max_fps).is_equal(30)
	s.fps_row.buttons[1].pressed.emit()
	assert_int(Save.get_setting(&"fps_cap")).is_equal(60)
	assert_int(Engine.max_fps).is_equal(60)


func test_pressing_the_chosen_option_again_writes_nothing() -> void:
	var s: SettingsScreen = _settings()
	s.quality_row.buttons[2].pressed.emit()  # High is the default
	assert_array(_changed).is_empty()


func test_high_contrast_re_skins_the_screen_as_soon_as_it_is_switched() -> void:
	var s: SettingsScreen = _settings()
	var frame: UiScreenFrame = s.get_child(0) as UiScreenFrame
	assert_object(frame.theme).is_same(UiTheme.shared(false))
	s.toggle_rows[&"high_contrast"].switch.button_pressed = true
	assert_object(frame.theme).is_same(UiTheme.shared(true))
	s.toggle_rows[&"high_contrast"].switch.button_pressed = false
	assert_object(frame.theme).is_same(UiTheme.shared(false))


func test_close_emits_closed_once_and_every_control_is_at_least_132_px() -> void:
	var s: SettingsScreen = _settings()
	var hits: Array[int] = [0]
	s.closed.connect(func() -> void: hits[0] += 1)
	s.close_button.pressed.emit()
	assert_int(hits[0]).is_equal(1)
	await ScreensTestKit.settle(get_tree())
	assert_array(ScreensTestKit.small_buttons(s)).is_empty()
	assert_int(UiKit.buttons(s).size()).is_equal(1 + 6 + 3 + 2)
	assert_float(s.close_button.size.y).is_greater_equal(148.0)
