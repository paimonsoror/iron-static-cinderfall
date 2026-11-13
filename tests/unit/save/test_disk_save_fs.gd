extends GdUnitTestSuite
## DiskSaveFs on user:// (the test wrapper redirects APPDATA, so this never touches a real profile). The important
## case is rename over an existing file: Windows refuses it unless the target is removed first.

const A: String = "user://w1d_test_a.json"
const B: String = "user://w1d_test_b.json"
const C: String = "user://w1d_test_c.json"

var disk: DiskSaveFs


func before_test() -> void:
	disk = DiskSaveFs.new()
	_clean()


func after_test() -> void:
	_clean()


func _clean() -> void:
	for p: String in [A, B, C]:
		disk.remove(p)


func test_rename_over_an_existing_file_replaces_it() -> void:
	assert_bool(disk.write(A, "old contents")).is_true()
	assert_bool(disk.write(B, "new contents")).is_true()
	assert_bool(disk.rename(B, A)).is_true()  # fails on Windows if the target were not removed first
	assert_str(disk.read(A)).is_equal("new contents")
	assert_bool(disk.exists(B)).is_false()


func test_write_read_exists_remove() -> void:
	assert_bool(disk.exists(A)).is_false()
	assert_str(disk.read(A)).is_equal("")
	assert_bool(disk.write(A, "{\"k\": \"vé\"}\n")).is_true()
	assert_bool(disk.exists(A)).is_true()
	assert_str(disk.read(A)).is_equal("{\"k\": \"vé\"}\n")
	assert_bool(disk.write(A, "shorter")).is_true()  # overwriting truncates
	assert_str(disk.read(A)).is_equal("shorter")
	assert_bool(disk.remove(A)).is_true()
	assert_bool(disk.exists(A)).is_false()
	assert_bool(disk.remove(A)).is_false()


func test_rename_of_a_missing_source_fails_and_keeps_the_target() -> void:
	disk.write(A, "keep me")
	assert_bool(disk.rename(B, A)).is_false()
	assert_str(disk.read(A)).is_equal("keep me")


func test_rename_to_a_free_name() -> void:
	disk.write(A, "payload")
	assert_bool(disk.rename(A, C)).is_true()
	assert_str(disk.read(C)).is_equal("payload")
	assert_bool(disk.exists(A)).is_false()


func test_save_flushes_and_reloads_through_the_disk_twice() -> void:
	# The real files of the autoload (user://profile_v2.json*), inside the redirected test APPDATA. The second flush
	# renames over an existing main file and over an existing backup.
	var disk_fs: DiskSaveFs = DiskSaveFs.new()
	_remove_profile_files(disk_fs)
	assert_int(SaveTestData.boot(disk_fs)).is_equal(Save.LoadStatus.NEW_PROFILE)
	Save.profile.data = 11
	assert_bool(Save.flush()).is_true()
	Save.profile.data = 22
	assert_bool(Save.flush()).is_true()
	Save.profile.data = 33
	assert_bool(Save.flush()).is_true()
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(33)
	assert_int(ProfileCodec.decode(disk_fs.read(SaveTestData.BAK)).profile.data).is_equal(22)
	assert_bool(disk_fs.exists(SaveTestData.TMP)).is_false()
	_remove_profile_files(disk_fs)
	SaveTestData.reset()


func _remove_profile_files(fs: SaveFs) -> void:
	for p: String in [SaveTestData.MAIN, SaveTestData.TMP, SaveTestData.BAK, SaveTestData.CORRUPT, SaveTestData.NEWER,
			SaveTestData.V1_MAIN, SaveTestData.V1_TMP, SaveTestData.V1_BAK]:
		fs.remove(p)
