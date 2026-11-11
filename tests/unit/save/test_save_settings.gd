extends GdUnitTestSuite
## Save settings and hints: key and type checks, settings_changed, persistence across a reload.

var fs: MemorySaveFs
var _changed: Array[StringName] = []


func before_test() -> void:
	fs = MemorySaveFs.new()
	SaveTestData.boot(fs)
	_changed.clear()
	Events.settings_changed.connect(_on_settings_changed)


func after_test() -> void:
	if Events.settings_changed.is_connected(_on_settings_changed):
		Events.settings_changed.disconnect(_on_settings_changed)
	SaveTestData.boot(MemorySaveFs.new())


func _on_settings_changed(key: StringName) -> void:
	_changed.append(key)


func test_defaults() -> void:
	assert_bool(Save.get_setting(&"sound_on")).is_true()
	assert_bool(Save.get_setting(&"music_on")).is_true()
	assert_bool(Save.get_setting(&"haptics_on")).is_true()
	assert_bool(Save.get_setting(&"reduced_flash")).is_false()
	assert_bool(Save.get_setting(&"high_contrast")).is_false()
	assert_int(Save.get_setting(&"quality")).is_equal(2)
	assert_int(Save.get_setting(&"fps_cap")).is_equal(60)


func test_valid_change_is_applied_saved_and_announced() -> void:
	Save.set_setting(&"sound_on", false)
	assert_bool(Save.get_setting(&"sound_on")).is_false()
	assert_array(_changed).is_equal([&"sound_on"])
	var on_disk: Profile = ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile
	assert_bool(on_disk.settings[&"sound_on"]).is_false()


func test_values_survive_a_reload() -> void:
	Save.set_setting(&"sound_on", false)
	Save.set_setting(&"reduced_flash", true)
	Save.set_setting(&"quality", 0)
	Save.set_setting(&"fps_cap", 30)
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_bool(Save.get_setting(&"sound_on")).is_false()
	assert_bool(Save.get_setting(&"reduced_flash")).is_true()
	assert_int(Save.get_setting(&"quality")).is_equal(0)
	assert_int(Save.get_setting(&"fps_cap")).is_equal(30)
	assert_bool(Save.get_setting(&"music_on")).is_true()


func test_unknown_key_is_rejected() -> void:
	Save.set_setting(&"god_mode", true)
	assert_object(Save.get_setting(&"god_mode")).is_null()
	assert_bool(Save.profile.settings.has(&"god_mode")).is_false()
	assert_int(_changed.size()).is_equal(0)
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()  # nothing was saved either


func test_wrong_type_is_rejected() -> void:
	Save.set_setting(&"sound_on", "no")
	Save.set_setting(&"music_on", 0)
	Save.set_setting(&"quality", 1.0)
	Save.set_setting(&"quality", "high")
	Save.set_setting(&"fps_cap", true)
	assert_bool(Save.get_setting(&"sound_on")).is_true()
	assert_bool(Save.get_setting(&"music_on")).is_true()
	assert_int(Save.get_setting(&"quality")).is_equal(2)
	assert_int(Save.get_setting(&"fps_cap")).is_equal(60)
	assert_int(_changed.size()).is_equal(0)


func test_out_of_range_value_is_rejected() -> void:
	Save.set_setting(&"quality", 3)
	Save.set_setting(&"quality", -1)
	Save.set_setting(&"fps_cap", 45)
	assert_int(Save.get_setting(&"quality")).is_equal(2)
	assert_int(Save.get_setting(&"fps_cap")).is_equal(60)
	assert_int(_changed.size()).is_equal(0)


func test_every_valid_change_emits_once_with_its_key() -> void:
	Save.set_setting(&"haptics_on", false)
	Save.set_setting(&"quality", 1)
	Save.set_setting(&"high_contrast", true)
	assert_array(_changed).is_equal([&"haptics_on", &"quality", &"high_contrast"])


func test_unknown_setting_reads_as_null() -> void:
	assert_object(Save.get_setting(&"nope")).is_null()


func test_hints_are_remembered_across_a_reload() -> void:
	assert_bool(Save.has_seen_hint("hint_aim")).is_false()
	Save.mark_hint_seen("hint_aim")
	Save.mark_hint_seen("hint_aim")
	assert_bool(Save.has_seen_hint("hint_aim")).is_true()
	assert_int(Save.profile.hints_seen.size()).is_equal(1)
	Save.load_profile()
	assert_bool(Save.has_seen_hint("hint_aim")).is_true()
	assert_bool(Save.has_seen_hint("hint_other")).is_false()


func test_empty_hint_key_is_ignored() -> void:
	Save.mark_hint_seen("")
	assert_int(Save.profile.hints_seen.size()).is_equal(0)
	assert_bool(Save.has_seen_hint("")).is_false()
