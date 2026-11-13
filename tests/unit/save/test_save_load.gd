extends GdUnitTestSuite
## Save.load_profile / flush on an in-memory file system (A15): first run, round trip, backup, corruption, newer
## schema, failed and torn writes, the crash window between flush's two renames.

var fs: MemorySaveFs


func before_test() -> void:
	fs = MemorySaveFs.new()
	SaveTestData.boot(fs)


func after_test() -> void:
	SaveTestData.reset()  # leave the autoload on a clean in-memory profile


func _reload() -> int:
	return Save.load_profile()


func test_first_run_gives_a_new_profile() -> void:
	assert_int(Save.last_load_status).is_equal(Save.LoadStatus.NEW_PROFILE)
	assert_int(Save.profile.data).is_equal(0)
	assert_dict(Save.profile.settings).is_equal(Profile.defaults().settings)
	assert_int(fs.files.size()).is_equal(0)  # loading never writes


func test_round_trip() -> void:
	Save.profile.data = 321
	Save.profile.best_core_hp = 555
	Save.profile.hints_seen.append("hint_a")
	assert_bool(Save.flush()).is_true()
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(321)
	assert_int(Save.profile.best_core_hp).is_equal(555)
	assert_bool(Save.has_seen_hint("hint_a")).is_true()


func test_flush_leaves_only_the_main_file_the_first_time() -> void:
	assert_bool(Save.flush()).is_true()
	assert_bool(fs.exists(SaveTestData.MAIN)).is_true()
	assert_bool(fs.exists(SaveTestData.TMP)).is_false()
	assert_bool(fs.exists(SaveTestData.BAK)).is_false()


func test_second_flush_keeps_the_previous_file_as_backup() -> void:
	Save.profile.data = 10
	Save.flush()
	var first: String = fs.read(SaveTestData.MAIN)
	Save.profile.data = 20
	Save.flush()
	assert_str(fs.read(SaveTestData.BAK)).is_equal(first)
	assert_bool(fs.exists(SaveTestData.TMP)).is_false()
	assert_int(ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile.data).is_equal(20)


func test_truncated_main_recovers_from_backup() -> void:
	Save.profile.data = 10
	Save.flush()
	Save.profile.data = 20
	Save.flush()  # main: 20, bak: 10
	var good: String = fs.read(SaveTestData.MAIN)
	fs.files[SaveTestData.MAIN] = good.substr(0, 20)
	assert_int(_reload()).is_equal(Save.LoadStatus.RECOVERED_FROM_BACKUP)
	assert_int(Save.profile.data).is_equal(10)


func test_recovery_does_not_let_a_bad_main_replace_the_good_backup() -> void:
	Save.profile.data = 10
	Save.flush()
	Save.profile.data = 20
	Save.flush()
	fs.files[SaveTestData.MAIN] = "{ broken"
	_reload()  # recovered from bak (data 10)
	Save.profile.data += 5
	assert_bool(Save.flush()).is_true()
	assert_int(ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile.data).is_equal(15)
	assert_int(ProfileCodec.decode(fs.read(SaveTestData.BAK)).profile.data).is_equal(10)  # still the good one


func test_main_and_backup_both_bad_resets_and_keeps_a_corrupt_copy() -> void:
	var bad: String = SaveTestData.text("profile_truncated")
	fs.files[SaveTestData.MAIN] = bad
	fs.files[SaveTestData.BAK] = "not json at all"
	assert_int(_reload()).is_equal(Save.LoadStatus.RESET_AFTER_CORRUPTION)
	assert_int(Save.profile.data).is_equal(0)
	assert_str(fs.read(SaveTestData.CORRUPT)).is_equal(bad)
	assert_bool(Save.flush()).is_true()  # a fresh profile can be written again
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_str(fs.read(SaveTestData.CORRUPT)).is_equal(bad)


func test_corrupt_main_without_backup_resets() -> void:
	fs.files[SaveTestData.MAIN] = SaveTestData.text("profile_not_object")
	assert_int(_reload()).is_equal(Save.LoadStatus.RESET_AFTER_CORRUPTION)
	assert_bool(fs.exists(SaveTestData.CORRUPT)).is_true()


func test_a_second_corruption_does_not_overwrite_the_first_corrupt_copy() -> void:
	fs.files[SaveTestData.MAIN] = "first damage"
	_reload()
	fs.files[SaveTestData.MAIN] = "second damage"
	_reload()
	assert_str(fs.read(SaveTestData.CORRUPT)).is_equal("first damage")
	assert_str(fs.read(SaveTestData.CORRUPT + ".1")).is_equal("second damage")


func test_newer_schema_is_set_aside_with_the_original_bytes() -> void:
	var newer: String = SaveTestData.text("profile_newer")
	fs.files[SaveTestData.MAIN] = newer
	assert_int(_reload()).is_equal(Save.LoadStatus.NEWER_SCHEMA_SET_ASIDE)
	assert_str(fs.read(SaveTestData.NEWER)).is_equal(newer)
	assert_int(Save.profile.data).is_equal(0)  # a fresh profile; nothing of the newer file is interpreted


func test_newer_schema_is_copied_once_across_launches() -> void:
	fs.files[SaveTestData.MAIN] = SaveTestData.text("profile_newer")
	_reload()
	_reload()
	_reload()
	assert_bool(fs.exists(SaveTestData.NEWER + ".1")).is_false()


func test_flush_after_newer_schema_keeps_the_copy_intact() -> void:
	var newer: String = SaveTestData.text("profile_newer")
	fs.files[SaveTestData.MAIN] = newer
	_reload()
	Save.profile.data = 4
	assert_bool(Save.flush()).is_true()
	assert_str(fs.read(SaveTestData.NEWER)).is_equal(newer)
	assert_bool(fs.exists(SaveTestData.BAK)).is_false()  # the newer file is not a valid backup of this schema
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(4)


func test_newer_schema_without_a_verified_copy_is_never_overwritten() -> void:
	var newer: String = SaveTestData.text("profile_newer")
	fs.files[SaveTestData.MAIN] = newer
	fs.fail_writes = true
	assert_int(_reload()).is_equal(Save.LoadStatus.NEWER_SCHEMA_SET_ASIDE)
	fs.fail_writes = false
	assert_bool(Save.flush()).is_false()
	assert_str(fs.read(SaveTestData.MAIN)).is_equal(newer)


func test_failed_write_leaves_the_previous_file_intact() -> void:
	Save.profile.data = 10
	Save.flush()
	var before: String = fs.read(SaveTestData.MAIN)
	Save.profile.data = 99
	fs.fail_writes = true
	assert_bool(Save.flush()).is_false()
	fs.fail_writes = false
	assert_str(fs.read(SaveTestData.MAIN)).is_equal(before)
	assert_bool(fs.exists(SaveTestData.TMP)).is_false()
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(10)


func test_torn_write_is_caught_by_the_read_back() -> void:
	Save.profile.data = 10
	Save.flush()
	var before: String = fs.read(SaveTestData.MAIN)
	Save.profile.data = 99
	fs.truncate_writes = true
	assert_bool(Save.flush()).is_false()  # the temp file read back differently
	fs.truncate_writes = false
	assert_str(fs.read(SaveTestData.MAIN)).is_equal(before)
	assert_bool(fs.exists(SaveTestData.TMP)).is_false()


func test_failed_final_rename_restores_the_previous_file() -> void:
	Save.profile.data = 10
	Save.flush()
	var before: String = fs.read(SaveTestData.MAIN)
	Save.profile.data = 99
	fs.fail_rename_from = SaveTestData.TMP
	assert_bool(Save.flush()).is_false()
	fs.fail_rename_from = ""
	assert_str(fs.read(SaveTestData.MAIN)).is_equal(before)
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(10)


func test_crash_between_the_two_renames_recovers_the_newest_file() -> void:
	Save.profile.data = 10
	Save.flush()
	var old: String = fs.read(SaveTestData.MAIN)
	Save.profile.data = 20
	var newest: String = ProfileCodec.encode(Save.profile)
	fs.files.erase(SaveTestData.MAIN)  # main renamed to .bak, the process died before tmp became main
	fs.files[SaveTestData.BAK] = old
	fs.files[SaveTestData.TMP] = newest
	assert_int(_reload()).is_equal(Save.LoadStatus.RECOVERED_FROM_BACKUP)
	assert_int(Save.profile.data).is_equal(20)


func test_missing_main_with_only_a_backup_recovers_it() -> void:
	fs.files[SaveTestData.BAK] = SaveTestData.text("profile_valid")
	assert_int(_reload()).is_equal(Save.LoadStatus.RECOVERED_FROM_BACKUP)
	assert_int(Save.profile.data).is_equal(250)


func test_sanitized_fields_do_not_make_the_file_corrupt() -> void:
	fs.files[SaveTestData.MAIN] = SaveTestData.text("profile_wrong_types")
	assert_int(_reload()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(0)
	assert_bool(fs.exists(SaveTestData.CORRUPT)).is_false()
