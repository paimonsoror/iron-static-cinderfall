extends GdUnitTestSuite
## GameRewards: Data is granted once per run id, flushed at once, and a failed flush is retried (GDD 8.2).

var _fs: MemorySaveFs


func before_test() -> void:
	_fs = GameRunKit.fresh_save()


func after_test() -> void:
	GameRunKit.reset_save()


func _summary(run_id: String, result: int, reward: int, core_hp: int = 0) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = run_id
	s.result = result
	s.data_reward = reward
	s.core_hp = core_hp
	return s


func _saved_data() -> int:
	return ProfileCodec.decode(_fs.read(Save.PATH_MAIN)).profile.data


func test_a_victory_grants_once_and_a_second_call_grants_nothing() -> void:
	var s: RunSummary = _summary("run-1", RunResult.Id.VICTORY, 143, 860)
	assert_bool(GameRewards.grant(s)).is_true()
	assert_int(Save.profile.data).is_equal(143)
	assert_int(Save.profile.missions_completed).is_equal(1)
	assert_int(Save.profile.best_core_hp).is_equal(860)
	assert_bool(GameRewards.grant(s)).is_false()
	assert_int(Save.profile.data).is_equal(143)
	assert_int(Save.profile.runs_played).is_equal(1)


func test_a_defeat_grants_its_reward_without_a_mission() -> void:
	assert_bool(GameRewards.grant(_summary("run-2", RunResult.Id.DEFEAT, 30))).is_true()
	assert_int(Save.profile.data).is_equal(30)
	assert_int(Save.profile.missions_completed).is_equal(0)


func test_an_unfinished_or_abandoned_run_grants_nothing() -> void:
	assert_bool(GameRewards.grant(_summary("run-3", RunResult.Id.ABANDONED, 50))).is_false()
	assert_bool(GameRewards.grant(_summary("run-4", RunResult.Id.NONE, 50))).is_false()
	assert_int(Save.profile.data).is_equal(0)
	assert_int(Save.profile.runs_played).is_equal(0)


func test_the_grant_is_on_disk_before_the_function_returns() -> void:
	GameRewards.grant(_summary("run-5", RunResult.Id.VICTORY, 120, 400))
	assert_int(_saved_data()).is_equal(120)
	assert_bool(GameRewards.flush_pending).is_false()


func test_a_failed_flush_is_remembered_and_retried_until_it_works() -> void:
	_fs.fail_writes = true
	assert_bool(GameRewards.grant(_summary("run-6", RunResult.Id.VICTORY, 140, 900))).is_true()
	assert_int(Save.profile.data).is_equal(140)  # the grant stands in memory
	assert_bool(GameRewards.flush_pending).is_true()
	assert_bool(GameRewards.retry_pending()).is_false()  # disk still failing
	assert_bool(GameRewards.flush_pending).is_true()
	_fs.fail_writes = false
	assert_bool(GameRewards.retry_pending()).is_true()
	assert_bool(GameRewards.flush_pending).is_false()
	assert_int(_saved_data()).is_equal(140)


func test_a_restart_after_a_successful_retry_keeps_the_grant() -> void:
	_fs.fail_writes = true
	GameRewards.grant(_summary("run-7", RunResult.Id.DEFEAT, 20))
	_fs.fail_writes = false
	GameRewards.retry_pending()
	Save.load_profile()  # what a restart does
	assert_int(Save.profile.data).is_equal(20)
	assert_bool(Save.profile.awarded_run_ids.has("run-7")).is_true()


func test_retry_with_nothing_pending_writes_nothing() -> void:
	GameRewards.grant(_summary("run-8", RunResult.Id.DEFEAT, 10))
	_fs.files.erase(Save.PATH_MAIN)
	assert_bool(GameRewards.retry_pending()).is_true()
	assert_bool(_fs.exists(Save.PATH_MAIN)).is_false()


func test_flush_now_records_a_failure_for_a_later_retry() -> void:
	_fs.fail_writes = true
	assert_bool(GameRewards.flush_now()).is_false()
	assert_bool(GameRewards.flush_pending).is_true()
	_fs.fail_writes = false
	assert_bool(GameRewards.flush_now()).is_true()
	assert_bool(GameRewards.flush_pending).is_false()
