extends GdUnitTestSuite
## The profile on the real disk (user://, which the test wrapper redirects to build\test_appdata): two finished runs
## through Game write profile_v1.json twice, the second write keeps the first profile as .bak, and a relaunch (a second
## Save manager on the same files) shows the same totals. Short boosted runs; the files are removed before and after.
## Refuses to run when user:// is not the redirected test folder, so it can never touch a real profile.

const FILES: Array[String] = [SaveTestData.MAIN, SaveTestData.TMP, SaveTestData.BAK, SaveTestData.CORRUPT, SaveTestData.NEWER]

var _h: GameHarness
var _disk: DiskSaveFs


func before_test() -> void:
	_disk = DiskSaveFs.new()
	if _redirected():
		_clean()


func after_test() -> void:
	if _h != null:
		_h.dispose()  # puts an in-memory save back
		_h = null
	if _redirected():
		_clean()


func _redirected() -> bool:
	return OS.get_user_data_dir().replace("\\", "/").contains("test_appdata")


func _clean() -> void:
	for path: String in FILES:
		_disk.remove(path)


func _boot_on_disk() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=3"]), GameHarness.one_wave)
	_h.game.set(&"sim_config_hook", IntegrationKit.boost)
	Save.use_fs(_disk)
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.NEW_PROFILE)  # a fresh profile
	_h.boot()


func test_a_finished_run_writes_the_profile_file_and_a_relaunch_reads_it_back() -> void:
	assert_bool(_redirected()).is_true()  # the guard: user:// must be the test folder
	if not _redirected():
		return
	_boot_on_disk()
	assert_bool(_disk.exists(Save.PATH_MAIN)).is_false()
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_bool(_disk.exists(Save.PATH_MAIN)).is_true()
	assert_bool(_disk.exists(Save.PATH_TMP)).is_false()  # the temp file was renamed over the main one
	var on_disk: Profile = ProfileCodec.decode(_disk.read(Save.PATH_MAIN)).profile
	assert_object(on_disk).is_not_null()
	assert_int(on_disk.data).is_equal(_h.summary().data_reward)
	assert_int(on_disk.runs_played).is_equal(1)
	var launched: Node = IntegrationKit.relaunch(DiskSaveFs.new())
	auto_free(launched)
	assert_int(launched.get(&"last_load_status")).is_equal(Save.LoadStatus.OK)
	assert_array(IntegrationKit.totals(IntegrationKit.profile_of(launched))).is_equal(IntegrationKit.totals(Save.profile))


func test_the_second_run_keeps_the_first_profile_as_the_backup() -> void:
	assert_bool(_redirected()).is_true()
	if not _redirected():
		return
	_boot_on_disk()
	_h.frames_until_over(60000)
	var first: Array = IntegrationKit.totals(Save.profile)
	(_h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen).retry_pressed.emit()
	assert_int(_h.frames_until_over(60000)).is_greater(0)
	var second: Array = IntegrationKit.totals(Save.profile)
	assert_int(Save.profile.runs_played).is_equal(2)
	var backup: Profile = ProfileCodec.decode(_disk.read(Save.PATH_BAK)).profile
	assert_object(backup).is_not_null()
	assert_array(IntegrationKit.totals(backup)).is_equal(first)  # the previous good file, not a copy of the new one
	var main_file: Profile = ProfileCodec.decode(_disk.read(Save.PATH_MAIN)).profile
	assert_array(IntegrationKit.totals(main_file)).is_equal(second)
	assert_int(main_file.data).is_equal(2 * backup.data)  # same seed, same boosted run, same reward twice


func test_a_damaged_main_file_is_recovered_from_the_backup_by_a_relaunch() -> void:
	assert_bool(_redirected()).is_true()
	if not _redirected():
		return
	_boot_on_disk()
	_h.frames_until_over(60000)
	(_h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen).retry_pressed.emit()
	_h.frames_until_over(60000)
	var first_run_data: int = ProfileCodec.decode(_disk.read(Save.PATH_BAK)).profile.data
	_disk.write(Save.PATH_MAIN, "{ this is not json")  # a torn write after the second run
	var launched: Node = IntegrationKit.relaunch(DiskSaveFs.new())
	auto_free(launched)
	assert_int(launched.get(&"last_load_status")).is_equal(Save.LoadStatus.RECOVERED_FROM_BACKUP)
	assert_int(IntegrationKit.profile_of(launched).data).is_equal(first_run_data)  # the grant of the first run survived
