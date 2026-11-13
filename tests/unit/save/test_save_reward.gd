extends GdUnitTestSuite
## Save.grant_run_reward: once per run id, victory bookkeeping, the 64-entry cap, persistence, signal.

var fs: MemorySaveFs
var _profile_changed: int = 0


func before_test() -> void:
	fs = MemorySaveFs.new()
	SaveTestData.boot(fs)
	_profile_changed = 0
	Events.profile_changed.connect(_on_profile_changed)


func after_test() -> void:
	if Events.profile_changed.is_connected(_on_profile_changed):
		Events.profile_changed.disconnect(_on_profile_changed)
	SaveTestData.reset()


func _on_profile_changed() -> void:
	_profile_changed += 1


func test_same_run_id_adds_data_once() -> void:
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 140, 400)).is_true()
	assert_int(Save.profile.data).is_equal(140)
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 140, 400)).is_false()
	assert_int(Save.profile.data).is_equal(140)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(1)


func test_victory_counts_the_mission_and_keeps_the_best_core_hp() -> void:
	Save.grant_run_reward("run_a", RunResult.Id.VICTORY, 120, 400)
	assert_int(Save.profile.missions_completed).is_equal(1)
	assert_int(Save.profile.best_core_hp).is_equal(400)
	Save.grant_run_reward("run_b", RunResult.Id.VICTORY, 110, 150)
	assert_int(Save.profile.best_core_hp).is_equal(400)  # max, not last
	Save.grant_run_reward("run_c", RunResult.Id.VICTORY, 140, 900)
	assert_int(Save.profile.best_core_hp).is_equal(900)
	assert_int(Save.profile.missions_completed).is_equal(3)
	assert_int(Save.profile.data).is_equal(370)


func test_defeat_adds_data_but_no_mission_and_no_best_core_hp() -> void:
	Save.grant_run_reward("run_a", RunResult.Id.DEFEAT, 30, 0)
	assert_int(Save.profile.data).is_equal(30)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(0)
	assert_int(Save.profile.best_core_hp).is_equal(0)
	Save.grant_run_reward("run_b", RunResult.Id.DEFEAT, 20, 800)  # core HP of a defeat is never a best
	assert_int(Save.profile.best_core_hp).is_equal(0)


func test_awarded_list_is_capped_at_64_newest_last() -> void:
	for i: int in 70:
		assert_bool(Save.grant_run_reward("run_%d" % i, RunResult.Id.DEFEAT, 1, 0)).is_true()
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(64)
	assert_str(Save.profile.awarded_run_ids[0]).is_equal("run_6")
	assert_str(Save.profile.awarded_run_ids[63]).is_equal("run_69")
	assert_int(Save.profile.data).is_equal(70)
	assert_int(Save.profile.runs_played).is_equal(70)
	assert_bool(Save.grant_run_reward("run_69", RunResult.Id.DEFEAT, 1, 0)).is_false()


func test_reward_is_saved_before_the_call_returns() -> void:
	Save.grant_run_reward("run_x", RunResult.Id.VICTORY, 150, 600)
	var on_disk: Profile = ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile
	assert_int(on_disk.data).is_equal(150)
	assert_bool(on_disk.awarded_run_ids.has("run_x")).is_true()


func test_reward_survives_a_restart_and_is_never_paid_twice() -> void:
	Save.grant_run_reward("run_x", RunResult.Id.VICTORY, 150, 600)
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)  # same file system: a restart
	assert_int(Save.profile.data).is_equal(150)
	assert_bool(Save.grant_run_reward("run_x", RunResult.Id.VICTORY, 150, 600)).is_false()
	assert_int(Save.profile.data).is_equal(150)


func test_profile_changed_is_emitted_only_for_a_real_grant() -> void:
	Save.grant_run_reward("run_1", RunResult.Id.DEFEAT, 10, 0)
	assert_int(_profile_changed).is_equal(1)
	Save.grant_run_reward("run_1", RunResult.Id.DEFEAT, 10, 0)
	assert_int(_profile_changed).is_equal(1)


func test_unusable_ids_and_amounts() -> void:
	assert_bool(Save.grant_run_reward("", RunResult.Id.VICTORY, 100, 100)).is_false()
	assert_bool(Save.grant_run_reward("r".repeat(Profile.MAX_ID_LENGTH + 1), RunResult.Id.VICTORY, 100, 100)).is_false()
	assert_int(Save.profile.data).is_equal(0)
	assert_bool(Save.grant_run_reward("run_neg", RunResult.Id.DEFEAT, -50, -5)).is_true()
	assert_int(Save.profile.data).is_equal(0)  # a negative amount never takes Data away


func test_failed_save_keeps_the_grant_in_memory_and_never_double_pays() -> void:
	fs.fail_writes = true
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 100, 500)).is_true()
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()
	assert_bool(Save.grant_run_reward("run_1", RunResult.Id.VICTORY, 100, 500)).is_false()
	assert_int(Save.profile.data).is_equal(100)
	fs.fail_writes = false
	assert_bool(Save.flush()).is_true()  # the next flush persists it
	assert_int(ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile.data).is_equal(100)
