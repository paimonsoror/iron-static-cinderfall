extends GdUnitTestSuite
## W3-A: a real grant is written to the disk exactly once (it used to be written twice, which made the `.bak`
## equal to the new profile and lost the previous one), and a failed write is read from `Save.profile_dirty()`.

var _fs: IntegrationCountingFs


func before_test() -> void:
	_fs = IntegrationCountingFs.new()
	Save.use_fs(_fs)
	Save.load_profile()
	GameRewards.flush_pending = false


func after_test() -> void:
	GameRunKit.reset_save()


func _summary(run_id: String, result: int, reward: int, core_hp: int = 0) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = run_id
	s.result = result
	s.data_reward = reward
	s.core_hp = core_hp
	return s


func test_a_grant_replaces_the_profile_file_exactly_once() -> void:
	assert_bool(GameRewards.grant(_summary("run-1", RunResult.Id.VICTORY, 120, 400))).is_true()
	assert_int(_fs.main_replacements).is_equal(1)
	assert_int(_fs.tmp_writes).is_equal(1)
	assert_bool(GameRewards.flush_pending).is_false()


func test_the_backup_keeps_the_profile_from_before_the_latest_grant() -> void:
	GameRewards.grant(_summary("run-1", RunResult.Id.VICTORY, 120, 400))
	GameRewards.grant(_summary("run-2", RunResult.Id.DEFEAT, 30))
	assert_int(_fs.stored_profile().data).is_equal(150)
	assert_int(_fs.backup_profile().data).is_equal(120)  # not 150: the second write did not repeat itself


func test_a_repeated_grant_writes_nothing() -> void:
	var s: RunSummary = _summary("run-1", RunResult.Id.VICTORY, 120, 400)
	GameRewards.grant(s)
	var replaced: int = _fs.main_replacements
	assert_bool(GameRewards.grant(s)).is_false()
	assert_int(_fs.main_replacements).is_equal(replaced)


func test_a_failed_write_is_pending_and_a_repeated_finish_retries_it() -> void:
	_fs.fail_writes = true
	var s: RunSummary = _summary("run-1", RunResult.Id.VICTORY, 120, 400)
	assert_bool(GameRewards.grant(s)).is_true()
	assert_bool(GameRewards.flush_pending).is_true()
	_fs.fail_writes = false
	assert_bool(GameRewards.grant(s)).is_false()  # nothing is granted twice, but the write is retried
	assert_bool(GameRewards.flush_pending).is_false()
	assert_int(_fs.stored_profile().data).is_equal(120)
	assert_int(_fs.stored_profile().runs_played).is_equal(1)
