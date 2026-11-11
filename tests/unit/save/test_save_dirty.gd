extends GdUnitTestSuite
## W3-A: `Save.profile_dirty()` tells a caller that a grant or a setting is in memory but not (yet) on disk, which
## `grant_run_reward` itself cannot return.

var fs: IntegrationCountingFs


func before_test() -> void:
	fs = IntegrationCountingFs.new()
	SaveTestData.boot(fs)


func after_test() -> void:
	SaveTestData.boot(MemorySaveFs.new())


func test_a_loaded_profile_is_clean() -> void:
	assert_bool(Save.profile_dirty()).is_false()


func test_a_grant_that_reached_the_disk_leaves_the_profile_clean() -> void:
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 140, 400)).is_true()
	assert_bool(Save.profile_dirty()).is_false()
	assert_int(fs.stored_profile().data).is_equal(140)


func test_a_grant_whose_write_failed_is_granted_but_dirty() -> void:
	fs.fail_writes = true
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 140, 400)).is_true()
	assert_bool(Save.profile_dirty()).is_true()
	assert_int(Save.profile.data).is_equal(140)
	assert_bool(fs.exists(Save.PATH_MAIN)).is_false()


func test_a_successful_flush_clears_it() -> void:
	fs.fail_writes = true
	Save.grant_run_reward("run_1", RunResult.Id.DEFEAT, 20, 0)
	fs.fail_writes = false
	assert_bool(Save.flush()).is_true()
	assert_bool(Save.profile_dirty()).is_false()
	assert_int(fs.stored_profile().data).is_equal(20)


func test_a_failed_setting_write_is_dirty_too() -> void:
	fs.fail_writes = true
	Save.set_setting(&"quality", 1)
	assert_bool(Save.profile_dirty()).is_true()
	fs.fail_writes = false
	Save.mark_hint_seen("hint.x")  # the next write carries everything
	assert_bool(Save.profile_dirty()).is_false()
	var stored_quality: int = fs.stored_profile().settings[&"quality"]
	assert_int(stored_quality).is_equal(1)


func test_loading_the_profile_again_starts_clean() -> void:
	fs.fail_writes = true
	Save.grant_run_reward("run_1", RunResult.Id.DEFEAT, 20, 0)
	fs.fail_writes = false
	Save.load_profile()  # what a restart does: the unwritten grant is gone, and so is the flag
	assert_bool(Save.profile_dirty()).is_false()
	assert_int(Save.profile.data).is_equal(0)


func test_a_refused_flush_stays_dirty() -> void:
	fs.files[Save.PATH_MAIN] = SaveTestData.text("profile_newer")
	fs.fail_writes = true  # the copy of the newer file cannot be made, so the main file is protected
	Save.load_profile()
	fs.fail_writes = false
	assert_bool(Save.flush()).is_false()
	assert_bool(Save.profile_dirty()).is_true()
	assert_str(fs.read(Save.PATH_MAIN)).is_equal(SaveTestData.text("profile_newer"))  # never overwritten
