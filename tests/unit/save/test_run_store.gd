extends GdUnitTestSuite
## V2-D: the run file on disk (ARCH 7.5, VARIETY_SPEC 13.3): `Save.save_run`, `load_run`, `clear_run` and RunStore.
## The write is crash-safe like the profile's, a damaged file falls back to the backup, and the profile files
## (`profile_v1.json`, its .bak) are never touched by it.

var _fs: MemorySaveFs


func before_test() -> void:
	_fs = MemorySaveFs.new()
	Save.use_fs(_fs)
	Save.load_profile()


func after_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	Save.load_profile()


func _doc(run_id: String = "100-7", wave: int = 2) -> Dictionary:
	return {
		"schema_version": 1, "build": "0.1.0", "content_hash": "abcdef012345", "run_id": run_id, "seed": 7,
		"kit": "k_standard", "unlocked": ["u_w_lmg"], "daily": false,
		"boundary": {"wave": wave, "tick": 4810, "state_hash": "aa", "state": {"version": 2}},
		"log": [{"tick": 100, "id": 1, "kind": 2, "arg": 0}], "tail": [{"tick": 4811, "id": 2, "kind": 0, "arg": 1}],
	}


func _wave_of(doc: Dictionary) -> int:
	var boundary: Dictionary = doc["boundary"]
	var wave: float = boundary["wave"]
	return roundi(wave)


func test_there_is_no_run_file_on_a_fresh_profile() -> void:
	assert_dict(Save.load_run()).is_empty()
	assert_bool(RunStore.exists(_fs)).is_false()
	Save.clear_run()  # nothing to delete, no error
	assert_dict(Save.load_run()).is_empty()


func test_a_saved_run_comes_back_with_every_field() -> void:
	assert_bool(Save.save_run(_doc())).is_true()
	assert_bool(_fs.exists(RunStore.PATH_MAIN)).is_true()
	assert_bool(_fs.exists(RunStore.PATH_TMP)).is_false()
	var back: Dictionary = Save.load_run()
	assert_str(str(back["run_id"])).is_equal("100-7")
	assert_str(str(back["content_hash"])).is_equal("abcdef012345")
	assert_int(_wave_of(back)).is_equal(2)
	var tail: Array = back["tail"]
	assert_int(tail.size()).is_equal(1)
	var unlocked: Array = back["unlocked"]
	assert_array(unlocked).is_equal(["u_w_lmg"])
	assert_bool(back["daily"] == false).is_true()


func test_the_file_is_the_path_of_the_spec_and_plain_json() -> void:
	Save.save_run(_doc())
	assert_str(RunStore.PATH_MAIN).is_equal("user://run_v1.json")
	var parsed: Variant = JSON.parse_string(_fs.read(RunStore.PATH_MAIN))
	assert_int(typeof(parsed)).is_equal(TYPE_DICTIONARY)


func test_the_second_write_keeps_the_previous_file_as_the_backup() -> void:
	Save.save_run(_doc("100-7", 1))
	Save.save_run(_doc("100-7", 2))
	assert_int(_wave_of(RunStore.decode(_fs.read(RunStore.PATH_MAIN)))).is_equal(2)
	assert_int(_wave_of(RunStore.decode(_fs.read(RunStore.PATH_BAK)))).is_equal(1)


func test_a_failed_write_leaves_the_previous_run_file_intact() -> void:
	Save.save_run(_doc("100-7", 1))
	_fs.fail_writes = true
	assert_bool(Save.save_run(_doc("100-7", 2))).is_false()
	_fs.fail_writes = false
	assert_int(_wave_of(Save.load_run())).is_equal(1)


func test_a_torn_write_is_noticed_and_leaves_the_previous_run_file_intact() -> void:
	Save.save_run(_doc("100-7", 1))
	_fs.truncate_writes = true
	assert_bool(Save.save_run(_doc("100-7", 2))).is_false()
	_fs.truncate_writes = false
	assert_bool(_fs.exists(RunStore.PATH_TMP)).is_false()
	assert_int(_wave_of(Save.load_run())).is_equal(1)


func test_a_failed_rename_puts_the_previous_file_back() -> void:
	Save.save_run(_doc("100-7", 1))
	_fs.fail_rename_from = RunStore.PATH_TMP
	assert_bool(Save.save_run(_doc("100-7", 2))).is_false()
	_fs.fail_rename_from = ""
	assert_int(_wave_of(RunStore.decode(_fs.read(RunStore.PATH_MAIN)))).is_equal(1)
	assert_int(_wave_of(Save.load_run())).is_equal(1)


func test_a_damaged_main_file_falls_back_to_the_backup() -> void:
	Save.save_run(_doc("100-7", 1))
	Save.save_run(_doc("100-7", 2))
	_fs.files[RunStore.PATH_MAIN] = "{ \"schema_version\": 1, \"run_id\": \"100-7\", \"bound"
	assert_int(_wave_of(Save.load_run())).is_equal(1)
	_fs.files[RunStore.PATH_BAK] = "not json"
	assert_dict(Save.load_run()).is_empty()


func test_a_crash_between_the_two_renames_is_recovered_from_the_temp_file() -> void:
	Save.save_run(_doc("100-7", 1))
	_fs.files[RunStore.PATH_BAK] = _fs.files[RunStore.PATH_MAIN]
	_fs.files.erase(RunStore.PATH_MAIN)
	_fs.files[RunStore.PATH_TMP] = RunStore.encode(_doc("100-7", 2))
	assert_int(_wave_of(Save.load_run())).is_equal(2)


func test_clear_run_removes_the_file_its_temp_and_its_backup() -> void:
	Save.save_run(_doc("100-7", 1))
	Save.save_run(_doc("100-7", 2))
	_fs.files[RunStore.PATH_TMP] = "x"
	Save.clear_run()
	assert_bool(RunStore.exists(_fs)).is_false()
	assert_dict(Save.load_run()).is_empty()


func test_the_run_file_never_touches_the_profile_files() -> void:
	Save.profile.data = 40
	assert_bool(Save.flush()).is_true()
	Save.profile.data = 55
	assert_bool(Save.flush()).is_true()
	var main: String = _fs.read(Save.PATH_MAIN)
	var bak: String = _fs.read(Save.PATH_BAK)
	Save.save_run(_doc())
	Save.save_run(_doc("100-7", 3))
	Save.clear_run()
	assert_str(_fs.read(Save.PATH_MAIN)).is_equal(main)
	assert_str(_fs.read(Save.PATH_BAK)).is_equal(bak)
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(55)


func test_text_that_is_not_a_run_file_decodes_to_nothing() -> void:
	for text: String in ["", "   ", "[1, 2]", "42", "{}", "{\"schema_version\": 1}", "{\"run_id\": \"a\"}",
			"{\"schema_version\": \"1\", \"run_id\": \"a\"}", "{\"schema_version\": 1, \"run_id\": 5}"]:
		assert_dict(RunStore.decode(text)).override_failure_message(text).is_empty()
	assert_dict(RunStore.decode("{\"schema_version\": 9, \"run_id\": \"a\"}")).is_not_empty()  # the game layer judges the version


func test_a_document_that_is_not_a_run_file_is_not_written() -> void:
	Save.save_run(_doc("100-7", 1))
	var bad: Dictionary = _doc("100-7", 2)
	bad.erase("run_id")
	assert_bool(Save.save_run(bad)).is_false()
	assert_bool(Save.save_run({})).is_false()
	assert_int(_wave_of(Save.load_run())).is_equal(1)
	assert_bool(_fs.exists(RunStore.PATH_TMP)).is_false()


func test_the_fixture_run_file_of_another_build_is_readable() -> void:
	var doc: Dictionary = RunStore.decode(SaveTestData.text("run_other_build"))
	assert_dict(doc).is_not_empty()
	assert_str(str(doc["build"])).is_equal("0.0.1")
	assert_int(_wave_of(doc)).is_equal(3)


func test_profile_v2_fields_round_trip_and_unknown_unlock_ids_are_kept() -> void:
	var text: String = ProfileCodec.encode(Profile.defaults())
	var p: Profile = ProfileCodec.decode(text).profile
	assert_int(p.unlocks.size()).is_equal(0)
	assert_str(String(p.kit)).is_equal("k_standard")
	var with_unlocks: String = text.replace("\"unlocks\": [],", "\"unlocks\": [\"u_w_lmg\", \"u_future\", 7, \"u_w_lmg\"],").replace("\"kit\": \"k_standard\"", "\"kit\": \"k_gambler\"")
	var q: Profile = ProfileCodec.decode(with_unlocks).profile
	assert_array(Array(q.unlocks)).is_equal(["u_w_lmg", "u_future"])  # unknown ids are kept, junk and repeats dropped
	assert_str(String(q.kit)).is_equal("k_gambler")
	var again: Profile = ProfileCodec.decode(ProfileCodec.encode(q)).profile
	assert_array(Array(again.unlocks)).is_equal(["u_w_lmg", "u_future"])
	assert_str(String(again.kit)).is_equal("k_gambler")


func test_has_unlock_reads_the_profile() -> void:
	assert_bool(Save.has_unlock(&"u_w_lmg")).is_false()
	Save.profile.unlocks.append("u_w_lmg")
	assert_bool(Save.has_unlock(&"u_w_lmg")).is_true()


func test_the_reward_extras_parameter_is_optional() -> void:
	assert_bool(Save.grant_run_reward("run-x", RunResult.Id.DEFEAT, 30, 0, {"best_wave": 3})).is_true()
	assert_bool(Save.grant_run_reward("run-x", RunResult.Id.DEFEAT, 30, 0, {"best_wave": 3})).is_false()
	assert_bool(Save.grant_run_reward("run-y", RunResult.Id.DEFEAT, 10, 0)).is_true()
	assert_int(Save.profile.data).is_equal(40)
	assert_int(Save.profile.runs_played).is_equal(2)
