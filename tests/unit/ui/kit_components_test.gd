extends GdUnitTestSuite
## UiKit factories and helpers, the settings rows, the screen frame, the drawn controls, the string keys.

var _saved_max_fps: int = 0


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_saved_max_fps = Engine.max_fps


func after_test() -> void:
	Engine.max_fps = _saved_max_fps
	ScreensTestKit.fresh_save()


func test_the_kit_keeps_its_wave_0_surface() -> void:
	assert_object(auto_free(UiKit.panel())).is_instanceof(PanelContainer)
	var b: Button = UiKit.button("menu.start")
	auto_free(b)
	assert_str(b.text).is_equal(Strings.t("menu.start"))
	assert_float(b.custom_minimum_size.x).is_greater_equal(132.0)
	assert_float(b.custom_minimum_size.y).is_greater_equal(148.0)
	var l: Label = UiKit.label("menu.start", 40)
	auto_free(l)
	assert_int(l.get_theme_font_size("font_size")).is_equal(40)
	var bar: ProgressBar = UiKit.bar()
	auto_free(bar)
	assert_bool(bar.show_percentage).is_false()
	var icon: TextureRect = UiKit.icon(&"core")
	auto_free(icon)
	assert_object(icon.texture).is_not_null()
	var none: TextureRect = UiKit.icon(&"no_such_icon")
	auto_free(none)
	assert_object(none.texture).is_null()


func test_button_variants_set_the_theme_type_and_never_take_focus() -> void:
	var primary: Button = UiKit.button_primary("menu.start")
	auto_free(primary)
	var quiet: Button = UiKit.button_quiet("menu.quit")
	auto_free(quiet)
	assert_str(String(primary.theme_type_variation)).is_equal("ButtonPrimary")
	assert_str(String(quiet.theme_type_variation)).is_equal("ButtonQuiet")
	assert_int(primary.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_float(quiet.custom_minimum_size.y).is_greater_equal(132.0)


func test_number_helpers() -> void:
	assert_str(UiKit.group(0)).is_equal("0")
	assert_str(UiKit.group(999)).is_equal("999")
	assert_str(UiKit.group(1240)).is_equal("1,240")
	assert_str(UiKit.group(1234567)).is_equal("1,234,567")
	assert_str(UiKit.clock(0)).is_equal("0:00")
	assert_str(UiKit.clock(60 * 59 + 59)).is_equal("0:59")
	assert_str(UiKit.clock(60 * 272)).is_equal("4:32")
	assert_str(UiKit.clock(-5)).is_equal("0:00")
	assert_int(UiKit.percent(620.0, 1000.0)).is_equal(62)
	assert_int(UiKit.percent(1.0, 1000.0)).is_equal(1)
	assert_int(UiKit.percent(0.0, 1000.0)).is_equal(0)


func test_a_toggle_row_emits_once_per_change_and_writes_on_or_off_as_text() -> void:
	var row: UiToggleRow = UiToggleRow.new("settings.sound", "settings.sound.hint", false)
	auto_free(row)
	add_child(row)
	var seen: Array[bool] = []
	row.changed.connect(func(on: bool) -> void: seen.append(on))
	assert_str(row.switch.text).is_equal(Strings.t("settings.off"))
	row.switch.button_pressed = true
	assert_array(seen).is_equal([true])
	assert_str(row.switch.text).is_equal(Strings.t("settings.on"))
	row.set_on(false)  # silent
	assert_array(seen).is_equal([true])
	assert_bool(row.is_on()).is_false()
	assert_str(row.switch.text).is_equal(Strings.t("settings.off"))
	assert_float(row.switch.custom_minimum_size.y).is_greater_equal(132.0)
	assert_str(row.title_label.text).is_equal(Strings.t("settings.sound").to_upper())


func test_a_segmented_row_selects_one_and_emits_only_on_a_change() -> void:
	var keys: PackedStringArray = ["settings.fps.30", "settings.fps.60"]
	var values: Array[int] = [30, 60]
	var row: UiSegmentedRow = UiSegmentedRow.new("settings.fps", "settings.fps.hint", keys, values, 60)
	auto_free(row)
	add_child(row)
	var seen: Array[int] = []
	row.selected.connect(func(v: int) -> void: seen.append(v))
	assert_int(row.value()).is_equal(60)
	assert_bool(row.buttons[1].button_pressed).is_true()
	assert_bool(row.buttons[0].button_pressed).is_false()
	row.buttons[1].pressed.emit()
	assert_array(seen).is_empty()
	row.buttons[0].pressed.emit()
	assert_array(seen).is_equal([30])
	row.set_value(60)  # silent
	assert_array(seen).is_equal([30])
	assert_bool(row.buttons[1].button_pressed).is_true()
	row.set_value(45)  # not an option: nothing is selected
	assert_bool(row.buttons[0].button_pressed).is_false()
	assert_bool(row.buttons[1].button_pressed).is_false()
	for b: Button in row.buttons:
		assert_float(b.custom_minimum_size.y).is_greater_equal(132.0)


func test_the_drawn_controls_have_their_sizes_and_texts() -> void:
	var rank: UiChevrons = UiChevrons.new(2, 4)
	auto_free(rank)
	assert_int(rank.count).is_equal(2)
	assert_int(rank.max_count).is_equal(4)
	assert_float(rank.custom_minimum_size.x).is_greater(rank.custom_minimum_size.y * 3.0)
	var plate: UiHeaderPlate = UiHeaderPlate.new("armory")
	auto_free(plate)
	assert_str(plate.label.text).is_equal("ARMORY")
	var cell: UiStatCell = UiStatCell.new("DATA", "5")
	auto_free(cell)
	cell.set_value("6")
	assert_str(cell.caption.text).is_equal("DATA")
	assert_str(cell.value.text).is_equal("6")
	var glyph: UiEnemyGlyph = UiEnemyGlyph.new(&"rusher", 120.0)
	auto_free(glyph)
	assert_vector(glyph.custom_minimum_size).is_equal(Vector2(120.0, 120.0))
	var title: UiTitleBlock = UiTitleBlock.new(true)
	auto_free(title)
	assert_str(title.top_label.text).is_equal(Strings.t("boot.title_top"))
	assert_str(title.main_label.text).is_equal(Strings.t("boot.title_main"))


func test_every_drawn_control_and_the_backdrop_draw_without_errors() -> void:
	var host: Control = ScreensTestKit.host(self)
	for id: StringName in Ids.ENEMIES.slice(0, Ids.LEGACY_ENEMY_COUNT):
		var g: UiEnemyGlyph = UiEnemyGlyph.new(id, 140.0)
		host.add_child(g)
	host.add_child(UiChevrons.new(3, 4))
	for m: int in [UiBackdrop.Mode.PLAIN, UiBackdrop.Mode.HERO, UiBackdrop.Mode.VICTORY, UiBackdrop.Mode.DEFEAT]:
		var d: UiBackdrop = UiBackdrop.new(m)
		host.add_child(d)
	await ScreensTestKit.settle(get_tree())
	assert_int(host.get_child_count()).is_equal(9)


func test_the_frame_keeps_its_content_inside_the_safe_area() -> void:
	var host: Control = ScreensTestKit.host(self, Vector2(1080.0, 2400.0))
	var frame: UiScreenFrame = UiScreenFrame.new()
	host.add_child(frame)
	frame.header.add_child(UiKit.spacer(100.0))
	frame.footer.add_child(UiKit.spacer(100.0))
	frame.set_safe_margins(Vector4(20.0, 60.0, 30.0, 90.0))
	await ScreensTestKit.settle(get_tree())
	assert_float(frame.header.global_position.y).is_greater_equal(60.0 + UiScreenFrame.EDGE - 0.5)
	assert_float(frame.header.global_position.x).is_greater_equal(20.0 + UiScreenFrame.EDGE - 0.5)
	assert_float(frame.footer.get_global_rect().end.y).is_less_equal(2400.0 - 90.0 - UiScreenFrame.EDGE + 0.5)
	assert_float(frame.footer.get_global_rect().end.x).is_less_equal(1080.0 - 30.0 - UiScreenFrame.EDGE + 0.5)
	assert_vector(frame.safe_margins()).is_equal(Vector4(20.0, 60.0, 30.0, 90.0))


func test_the_frame_connects_to_the_settings_signal_only_while_it_is_in_the_tree() -> void:
	var before: int = Events.settings_changed.get_connections().size()
	var host: Control = ScreensTestKit.host(self)
	var frame: UiScreenFrame = UiScreenFrame.new()
	host.add_child(frame)
	assert_int(Events.settings_changed.get_connections().size()).is_equal(before + 1)
	host.remove_child(frame)
	assert_int(Events.settings_changed.get_connections().size()).is_equal(before)
	frame.free()


func test_the_frame_carries_the_theme_for_the_current_contrast_setting() -> void:
	var host: Control = ScreensTestKit.host(self)
	var frame: UiScreenFrame = UiScreenFrame.new()
	host.add_child(frame)
	assert_object(frame.theme).is_same(UiTheme.shared(false))
	Save.set_setting(&"high_contrast", true)
	assert_object(frame.theme).is_same(UiTheme.shared(true))


func test_settings_apply_sets_the_fps_cap_and_ignores_other_keys() -> void:
	Save.set_setting(&"fps_cap", 30)
	UiSettingsApply.apply(&"fps_cap")
	assert_int(Engine.max_fps).is_equal(30)
	Save.set_setting(&"fps_cap", 60)
	UiSettingsApply.apply_all()
	assert_int(Engine.max_fps).is_equal(60)
	UiSettingsApply.apply(&"quality")
	UiSettingsApply.apply(&"unknown_key")
	assert_int(Engine.max_fps).is_equal(60)


func test_every_string_key_the_screens_and_the_kit_name_exists_and_every_enemy_has_a_threat_line() -> void:
	var keys: Array[String] = ScreensTestKit.literal_keys("res://src/ui/screens")
	keys.append_array(ScreensTestKit.literal_keys("res://src/ui/kit"))
	assert_int(keys.size()).is_greater(30)
	for key: String in keys:
		assert_bool(Content.db.strings.has(key)).override_failure_message("missing string '%s'" % key).is_true()
	for enemy: EnemyDef in TestContent.baseline().enemies:
		assert_bool(Content.db.strings.has("lore.threat.%s" % String(enemy.id))).is_true()


func test_the_lore_text_keeps_the_canon_rules() -> void:
	var lore: Array[String] = []
	for key: String in Content.db.strings:
		if key.begins_with("lore."):
			lore.append(Content.db.strings[key])
	var all: String = " ".join(lore).to_lower()
	assert_bool(all.contains("skull")).is_false()
	assert_bool(all.contains("terminator")).is_false()
	assert_bool(all.contains("9mm")).is_false()
	assert_str(Strings.t("lore.results.defeat")).is_equal(Strings.t("lore.results.defeat").to_lower())  # CHORUS logs are lowercase
	assert_str(Strings.t("lore.briefing.text")).contains("Accord out.")
