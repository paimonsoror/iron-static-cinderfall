extends GdUnitTestSuite
## ProfileCodec: encode/decode round trip, sanitizing of wrong types and negative numbers, unusable files.


func test_defaults_round_trip() -> void:
	var back: ProfileDecodeResult = ProfileCodec.decode(ProfileCodec.encode(Profile.defaults()))
	assert_object(back.profile).is_not_null()
	assert_int(back.schema_version).is_equal(Profile.SCHEMA_VERSION)
	assert_int(back.profile.data).is_equal(0)
	assert_dict(back.profile.settings).is_equal(Profile.defaults().settings)


func test_full_round_trip() -> void:
	var p: Profile = Profile.defaults()
	p.data = 1234
	p.missions_completed = 3
	p.best_core_hp = 777
	p.runs_played = 9
	p.awarded_run_ids = PackedStringArray(["a", "b", "c"])
	p.hints_seen = PackedStringArray(["h1", "h2"])
	p.settings[&"sound_on"] = false
	p.settings[&"quality"] = 0
	p.settings[&"fps_cap"] = 30
	var q: Profile = ProfileCodec.decode(ProfileCodec.encode(p)).profile
	assert_int(q.data).is_equal(1234)
	assert_int(q.missions_completed).is_equal(3)
	assert_int(q.best_core_hp).is_equal(777)
	assert_int(q.runs_played).is_equal(9)
	assert_array(Array(q.awarded_run_ids)).is_equal(["a", "b", "c"])
	assert_array(Array(q.hints_seen)).is_equal(["h1", "h2"])
	assert_dict(q.settings).is_equal(p.settings)
	assert_int(q.settings[&"quality"]).is_equal(0)


func test_encoded_text_has_the_arch_keys() -> void:
	var text: String = ProfileCodec.encode(Profile.defaults())
	var parsed: Dictionary = JSON.parse_string(text)
	for key: String in ["schema_version", "data", "missions_completed", "best_core_hp", "runs_played", "awarded_run_ids", "hints_seen", "settings"]:
		assert_bool(parsed.has(key)).is_true()
	var settings: Dictionary = parsed["settings"]
	assert_int(settings.size()).is_equal(7)
	assert_bool(text.ends_with("}\n")).is_true()


func test_valid_fixture_decodes() -> void:
	var p: Profile = ProfileCodec.decode(SaveTestData.text("profile_valid")).profile
	assert_int(p.data).is_equal(250)
	assert_int(p.missions_completed).is_equal(2)
	assert_int(p.best_core_hp).is_equal(640)
	assert_int(p.runs_played).is_equal(3)
	assert_array(Array(p.awarded_run_ids)).is_equal(["run_a", "run_b", "run_c"])
	assert_array(Array(p.hints_seen)).is_equal(["hint_aim"])
	assert_bool(p.settings[&"sound_on"]).is_false()
	assert_bool(p.settings[&"reduced_flash"]).is_true()
	assert_int(p.settings[&"quality"]).is_equal(1)
	assert_int(p.settings[&"fps_cap"]).is_equal(30)


func test_wrong_types_are_sanitized() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode(SaveTestData.text("profile_wrong_types"))
	assert_object(r.profile).is_not_null()
	var p: Profile = r.profile
	assert_int(p.data).is_equal(0)
	assert_int(p.missions_completed).is_equal(0)
	assert_int(p.best_core_hp).is_equal(0)
	assert_int(p.runs_played).is_equal(0)
	assert_array(Array(p.awarded_run_ids)).is_equal(["run_ok", "run_two"])  # non-strings, empty and duplicates dropped
	assert_int(p.hints_seen.size()).is_equal(0)
	assert_bool(p.settings[&"sound_on"]).is_true()  # "yes" is not a bool: default
	assert_bool(p.settings[&"music_on"]).is_true()  # 1 is not a bool: default
	assert_bool(p.settings[&"haptics_on"]).is_false()  # valid values are kept
	assert_bool(p.settings[&"reduced_flash"]).is_true()
	assert_bool(p.settings[&"high_contrast"]).is_false()  # null: default
	assert_int(p.settings[&"quality"]).is_equal(2)  # 7 is out of range: default
	assert_int(p.settings[&"fps_cap"]).is_equal(60)  # 45 is not an allowed cap: default
	assert_bool(p.settings.has(&"god_mode")).is_false()


func test_negative_numbers_become_zero_and_fractions_round_down() -> void:
	var p: Profile = ProfileCodec.decode(SaveTestData.text("profile_negative")).profile
	assert_int(p.data).is_equal(0)
	assert_int(p.missions_completed).is_equal(0)
	assert_int(p.best_core_hp).is_equal(0)
	assert_int(p.runs_played).is_equal(4)
	assert_int(p.settings[&"quality"]).is_equal(2)


func test_huge_numbers_are_capped() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode('{"schema_version": 1, "data": 1e300, "runs_played": 99999999999}')
	assert_int(r.profile.data).is_equal(Profile.MAX_COUNT)
	assert_int(r.profile.runs_played).is_equal(Profile.MAX_COUNT)


func test_unknown_keys_are_ignored_and_never_loaded() -> void:
	var text: String = '{"schema_version": 1, "data": 5, "script": "res://evil.gd", "settings": {"path": "res://x.tres"}}'
	var r: ProfileDecodeResult = ProfileCodec.decode(text)
	assert_int(r.profile.data).is_equal(5)
	assert_bool(r.profile.settings.has(&"path")).is_false()
	assert_int(r.profile.settings.size()).is_equal(7)


func test_truncated_file_is_unusable() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode(SaveTestData.text("profile_truncated"))
	assert_object(r.profile).is_null()
	assert_str(r.error).starts_with("invalid JSON")


func test_files_without_a_usable_schema_version_are_unusable() -> void:
	for text: String in [SaveTestData.text("profile_not_object"), SaveTestData.text("profile_no_schema"), "", "   \n", "null",
			'{"schema_version": 0}', '{"schema_version": -3}', '{"schema_version": "1"}', '{"schema_version": 1.5}']:
		var r: ProfileDecodeResult = ProfileCodec.decode(text)
		assert_object(r.profile).is_null()
		assert_str(r.error).is_not_empty()


func test_oversized_file_is_unusable() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode('{"schema_version": 1, "pad": "' + "x".repeat(Profile.MAX_FILE_CHARS) + '"}')
	assert_object(r.profile).is_null()
	assert_str(r.error).starts_with("file too large")


func test_newer_schema_is_reported_not_decoded() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode(SaveTestData.text("profile_newer"))
	assert_object(r.profile).is_null()
	assert_int(r.schema_version).is_equal(99)
	assert_str(r.error).contains("newer")


func test_awarded_ids_keep_the_newest_64() -> void:
	var p: Profile = Profile.defaults()
	for i: int in 70:
		p.awarded_run_ids.append("run_%d" % i)
	var q: Profile = ProfileCodec.decode(ProfileCodec.encode(p)).profile
	assert_int(q.awarded_run_ids.size()).is_equal(64)
	assert_str(q.awarded_run_ids[0]).is_equal("run_6")
	assert_str(q.awarded_run_ids[63]).is_equal("run_69")
	var raw: Array = []
	for i: int in 70:
		raw.append("r%d" % i)
	var r: ProfileDecodeResult = ProfileCodec.decode(JSON.stringify({"schema_version": 1, "awarded_run_ids": raw}))
	assert_int(r.profile.awarded_run_ids.size()).is_equal(64)
	assert_str(r.profile.awarded_run_ids[63]).is_equal("r69")


func test_encode_clamps_negative_counters() -> void:
	var p: Profile = Profile.defaults()
	p.data = -5
	p.best_core_hp = -1
	var q: Profile = ProfileCodec.decode(ProfileCodec.encode(p)).profile
	assert_int(q.data).is_equal(0)
	assert_int(q.best_core_hp).is_equal(0)
