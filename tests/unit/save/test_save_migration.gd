extends GdUnitTestSuite
## B09: the profile of the build before the Archive (profile_v1.json) becomes profile v2 on fixture files: plain, backup
## only, corrupt, newer schema, read-ahead keys, no completed mission. Testers keep their Data and settings, nothing is
## unlocked for free, and the v1 files are never touched (a downgrade still finds them).

var fs: MemorySaveFs


func after_test() -> void:
	SaveTestData.reset()


func _boot_v1(text: String) -> int:
	fs = SaveTestData.fs_with_v1(text)
	return SaveTestData.boot(fs)


func _assert_nothing_unlocked() -> void:
	var p: Profile = Save.profile
	assert_int(p.unlocks.size()).is_equal(0)
	assert_int(p.claimed.size()).is_equal(0)
	assert_str(String(p.kit)).is_equal("k_standard")
	assert_int(p.boss_kills.size() + p.victories_by_kit.size() + p.victory_weapons.size() + p.codex_seen.size()).is_equal(0)
	assert_dict(p.daily).is_equal(Profile.empty_daily())


func test_a_plain_v1_profile_keeps_everything_it_had() -> void:
	var text: String = SaveTestData.text("profile_v1_tester")
	assert_int(_boot_v1(text)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	var p: Profile = Save.profile
	assert_int(p.data).is_equal(413)
	assert_int(p.data_lifetime).is_equal(413)
	assert_int(p.missions_completed).is_equal(3)
	assert_int(p.best_core_hp).is_equal(720)
	assert_int(p.runs_played).is_equal(6)
	assert_array(Array(p.awarded_run_ids)).is_equal(["1763000001-11", "1763000100-12", "1763000200-13", "1763000300-14", "1763000400-15", "1763000500-16"])
	assert_array(Array(p.hints_seen)).is_equal(["hint_aim", "hint_drawer"])
	assert_bool(p.settings[&"music_on"]).is_false()
	assert_bool(p.settings[&"reduced_flash"]).is_true()
	assert_bool(p.settings[&"high_contrast"]).is_true()
	assert_int(p.settings[&"quality"]).is_equal(1)
	assert_int(p.settings[&"fps_cap"]).is_equal(30)
	assert_bool(p.settings[&"swap_assist"]).is_false()  # the one new setting starts at its default
	assert_int(p.best_wave).is_equal(5)
	_assert_nothing_unlocked()


func test_profile_v2_is_written_at_once_and_the_v1_file_is_left_alone() -> void:
	var text: String = SaveTestData.text("profile_v1_tester")
	_boot_v1(text)
	assert_bool(fs.exists(SaveTestData.MAIN)).is_true()
	var on_disk: Profile = ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile
	assert_int(on_disk.data).is_equal(413)
	assert_int(on_disk.data_lifetime).is_equal(413)
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(text)  # byte for byte
	assert_bool(fs.exists(SaveTestData.V1_BAK) or fs.exists(SaveTestData.V1_TMP)).is_false()
	assert_bool(Save.profile_dirty()).is_false()


func test_the_next_launch_reads_v2_and_does_not_migrate_again() -> void:
	_boot_v1(SaveTestData.text("profile_v1_tester"))
	Save.profile.data = 500  # played on: the v1 file would say 413
	assert_bool(Save.flush()).is_true()
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(500)


func test_the_v1_files_survive_later_play_unchanged() -> void:
	var text: String = SaveTestData.text("profile_v1_tester")
	_boot_v1(text)
	fs.files[SaveTestData.V1_BAK] = text
	Save.grant_run_reward("run-after-migration", RunResult.Id.DEFEAT, 40, 0)
	Save.set_setting(&"sound_on", false)
	Save.flush()
	Save.flush()  # a second flush turns the first v2 file into the v2 backup
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(text)
	assert_str(fs.read(SaveTestData.V1_BAK)).is_equal(text)
	assert_int(Save.profile.data).is_equal(453)
	assert_int(Save.profile.data_lifetime).is_equal(453)


func test_a_profile_with_no_completed_mission_has_best_wave_zero() -> void:
	assert_int(_boot_v1(SaveTestData.text("profile_v1_fresh"))).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(30)
	assert_int(Save.profile.best_wave).is_equal(0)
	assert_int(Save.profile.missions_completed).is_equal(0)


func test_a_valid_v1_file_of_the_older_fixtures_migrates() -> void:
	assert_int(_boot_v1(SaveTestData.text("profile_valid"))).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(250)
	assert_int(Save.profile.best_core_hp).is_equal(640)
	assert_bool(Save.profile.settings[&"sound_on"]).is_false()
	assert_int(Save.profile.settings[&"fps_cap"]).is_equal(30)
	assert_int(Save.profile.best_wave).is_equal(5)


func test_a_v1_backup_alone_migrates() -> void:
	fs = MemorySaveFs.new()
	fs.files[SaveTestData.V1_BAK] = SaveTestData.text("profile_v1_tester")
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)
	assert_bool(fs.exists(SaveTestData.V1_BAK)).is_true()
	assert_bool(fs.exists(SaveTestData.V1_MAIN)).is_false()  # nothing is created or moved in the v1 set


func test_a_v1_temp_file_after_a_crash_between_the_renames_migrates() -> void:
	fs = MemorySaveFs.new()
	fs.files[SaveTestData.V1_BAK] = SaveTestData.text("profile_v1_fresh")
	fs.files[SaveTestData.V1_TMP] = SaveTestData.text("profile_v1_tester")  # the newest write
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)


func test_a_corrupt_v1_main_falls_back_to_its_backup() -> void:
	fs = SaveTestData.fs_with_v1(SaveTestData.text("profile_truncated"))
	fs.files[SaveTestData.V1_BAK] = SaveTestData.text("profile_v1_tester")
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(SaveTestData.text("profile_truncated"))  # still there, still corrupt


func test_a_corrupt_v1_file_with_no_backup_starts_fresh_and_is_not_moved() -> void:
	var bad: String = SaveTestData.text("profile_truncated")
	assert_int(_boot_v1(bad)).is_equal(Save.LoadStatus.RESET_AFTER_CORRUPTION)
	assert_int(Save.profile.data).is_equal(0)
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(bad)
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()  # loading writes nothing here
	assert_bool(fs.exists(SaveTestData.CORRUPT)).is_false()
	assert_bool(Save.flush()).is_true()  # a fresh v2 profile can be written
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)


func test_a_v1_file_of_a_newer_schema_is_never_interpreted_or_touched() -> void:
	var newer: String = SaveTestData.text("profile_newer")
	assert_int(_boot_v1(newer)).is_equal(Save.LoadStatus.NEWER_SCHEMA_SET_ASIDE)
	assert_int(Save.profile.data).is_equal(0)
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(newer)
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()


func test_the_read_ahead_keys_of_the_v1_build_unlock_nothing() -> void:
	assert_int(_boot_v1(SaveTestData.text("profile_v1_readahead"))).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(120)
	_assert_nothing_unlocked()
	assert_bool(ProfileCodec.encode(Save.profile).contains("u_w_lmg")).is_false()


func test_a_damaged_v1_profile_is_sanitized_like_any_other() -> void:
	assert_int(_boot_v1(SaveTestData.text("profile_wrong_types"))).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(0)
	assert_array(Array(Save.profile.awarded_run_ids)).is_equal(["run_ok", "run_two"])
	assert_bool(Save.profile.settings[&"haptics_on"]).is_false()


func test_v2_wins_when_both_files_exist() -> void:
	fs = SaveTestData.fs_with_v1(SaveTestData.text("profile_v1_tester"))
	fs.files[SaveTestData.MAIN] = SaveTestData.text("profile_v2_progress")
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(275)
	assert_array(Array(Save.profile.unlocks)).is_equal(["u_w_lmg", "u_w_hornet", "u_p_blast", "k_breacher"])
	assert_str(fs.read(SaveTestData.V1_MAIN)).is_equal(SaveTestData.text("profile_v1_tester"))


func test_a_damaged_v2_file_with_a_v1_file_beside_it_migrates_and_keeps_the_damaged_copy() -> void:
	fs = SaveTestData.fs_with_v1(SaveTestData.text("profile_v1_tester"))
	fs.files[SaveTestData.MAIN] = "{ not json"
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)
	assert_str(fs.read(SaveTestData.CORRUPT)).is_equal("{ not json")
	assert_bool(ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile != null).is_true()


func test_a_failed_write_during_migration_keeps_the_profile_and_tries_again_next_launch() -> void:
	fs = SaveTestData.fs_with_v1(SaveTestData.text("profile_v1_tester"))
	fs.fail_writes = true
	assert_int(SaveTestData.boot(fs)).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)  # the migrated profile stands in memory
	assert_bool(Save.profile_dirty()).is_true()
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()
	fs.fail_writes = false
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)  # v1 was never removed: it migrates again
	assert_int(Save.profile.data).is_equal(413)
	assert_bool(Save.profile_dirty()).is_false()


func test_a_new_player_has_no_v1_file_and_starts_new() -> void:
	assert_int(SaveTestData.boot(MemorySaveFs.new())).is_equal(Save.LoadStatus.NEW_PROFILE)
	_assert_nothing_unlocked()
	assert_int(Save.profile.data).is_equal(0)


func test_the_v1_status_exists_and_was_appended() -> void:
	assert_int(Save.LoadStatus.MIGRATED_FROM_V1).is_equal(5)  # append only: the first five keep their values
	assert_int(Save.LoadStatus.NEWER_SCHEMA_SET_ASIDE).is_equal(4)


func test_migration_does_not_depend_on_the_archive_content() -> void:
	SaveTestData.boot_with(SaveTestData.fs_with_v1(SaveTestData.text("profile_v1_tester")), TestContent.variety())
	assert_int(Save.last_load_status).is_equal(Save.LoadStatus.MIGRATED_FROM_V1)
	assert_int(Save.profile.data).is_equal(413)
	assert_str(String(Save.profile.kit)).is_equal("k_standard")
