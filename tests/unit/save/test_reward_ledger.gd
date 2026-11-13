extends GdUnitTestSuite
## B10: what a run adds to the profile beyond its Data (the `extras` of grant_run_reward): milestones are claimed once
## per profile in the same flush as the run that earned them, boss kills, victories per kit and per primary weapon, the
## best wave and the Daily Run record. The Data amount of the run is the caller's; milestones come from the content table.

var fs: MemorySaveFs
var cs: ContentSet


func before_test() -> void:
	cs = ArchiveTestTree.content()
	fs = MemorySaveFs.new()
	SaveTestData.boot_with(fs, cs)


func after_test() -> void:
	SaveTestData.reset()


func _extras(waves: int, bosses: Array = [], kit: String = "k_standard", weapon: String = "pistol") -> Dictionary:
	return {"best_wave": waves, "boss_kills": bosses, "kit": kit, "primary_weapon": weapon}


func _win(id: String, data: int, extras: Dictionary) -> bool:
	return Save.grant_run_reward(id, RunResult.Id.VICTORY, data, 500, extras)


func _lose(id: String, data: int, extras: Dictionary) -> bool:
	return Save.grant_run_reward(id, RunResult.Id.DEFEAT, data, 0, extras)


func _milestone_ids() -> Array:
	var ids: Array = []
	var rows: Array = Save.last_reward["milestones"]
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		ids.append(row["id"])
	return ids


func _total() -> int:
	var total: int = Save.last_reward["total"]
	return total


# --- milestones, once ---


func test_a_first_boss_kill_pays_its_milestone_once() -> void:
	assert_bool(_lose("r1", 30, _extras(5, ["siege_hulk"]))).is_true()
	assert_int(Save.profile.data).is_equal(80)  # 30 for the run + 50
	assert_array(_milestone_ids()).is_equal(["ms_first_boss_siege_hulk"])
	assert_array(Array(Save.profile.claimed)).is_equal(["ms_first_boss_siege_hulk"])
	_lose("r2", 30, _extras(5, ["siege_hulk"]))
	assert_int(Save.profile.data).is_equal(110)  # 30 only: the milestone is gone
	assert_array(_milestone_ids()).is_equal([])
	assert_int(Save.profile.boss_kills["siege_hulk"]).is_equal(2)


func test_the_first_victory_pays_200_once() -> void:
	_win("r1", 100, _extras(5, [], "k_standard", "pistol"))
	assert_int(Save.profile.data).is_equal(100 + 200 + 75)  # + the standard kit's first victory
	assert_array(_milestone_ids()).is_equal(["ms_first_victory", "ms_victory_kit_k_standard"])
	_win("r2", 100, _extras(5, [], "k_standard", "pistol"))
	assert_int(Save.profile.data).is_equal(375 + 100)
	assert_int(Save.profile.missions_completed).is_equal(2)


func test_the_boss_milestone_comes_before_the_victory_ones() -> void:
	_win("r1", 100, _extras(15, ["siege_hulk"]))
	assert_array(_milestone_ids()).is_equal(["ms_first_boss_siege_hulk", "ms_first_victory", "ms_victory_kit_k_standard"])
	assert_int(_total()).is_equal(100 + 50 + 200 + 75)
	assert_int(Save.last_reward["milestone_data"]).is_equal(325)


func test_a_defeat_pays_no_victory_milestone() -> void:
	_lose("r1", 40, _extras(6, [], "k_gunline"))
	assert_int(Save.profile.data).is_equal(40)
	assert_int(Save.profile.claimed.size()).is_equal(0)
	assert_int(Save.profile.victories_by_kit.size()).is_equal(0)
	assert_int(Save.profile.victory_weapons.size()).is_equal(0)


func test_each_kit_pays_its_first_victory_once() -> void:
	_win("r1", 0, _extras(15, [], "k_breacher"))
	assert_array(_milestone_ids()).is_equal(["ms_first_victory", "ms_victory_kit_k_breacher"])
	_win("r2", 0, _extras(15, [], "k_ledger"))
	assert_array(_milestone_ids()).is_equal(["ms_victory_kit_k_ledger"])  # the first victory is not paid again
	_win("r3", 0, _extras(15, [], "k_breacher"))
	assert_array(_milestone_ids()).is_equal([])
	assert_dict(Save.profile.victories_by_kit).is_equal({"k_breacher": 2, "k_ledger": 1})
	assert_int(Save.profile.data).is_equal(200 + 75 + 75)


func test_three_different_primary_weapons_pay_150_once() -> void:
	_win("r1", 0, _extras(15, [], "k_standard", "pistol"))
	_win("r2", 0, _extras(15, [], "k_standard", "pistol"))  # the same weapon again is not a new build
	_win("r3", 0, _extras(15, [], "k_standard", "arc_projector"))
	assert_array(_milestone_ids()).is_equal([])
	assert_array(Array(Save.profile.victory_weapons)).is_equal(["pistol", "arc_projector"])
	_win("r4", 0, _extras(15, [], "k_standard", "lmg"))
	assert_array(_milestone_ids()).is_equal(["ms_three_builds"])
	_win("r5", 0, _extras(15, [], "k_standard", "rail_lance"))
	assert_array(_milestone_ids()).is_equal([])  # once
	assert_int(Save.profile.victory_weapons.size()).is_equal(4)
	assert_int(Save.profile.data).is_equal(200 + 75 + 150)


func test_a_defeat_does_not_count_as_a_build() -> void:
	_lose("r1", 10, _extras(8, [], "k_standard", "lmg"))
	assert_int(Save.profile.victory_weapons.size()).is_equal(0)


func test_the_milestones_and_the_run_are_one_flush() -> void:
	fs.fail_writes = true
	_win("r1", 100, _extras(15, ["siege_hulk"]))
	assert_bool(Save.profile_dirty()).is_true()
	assert_bool(fs.exists(SaveTestData.MAIN)).is_false()
	fs.fail_writes = false
	Save.flush()
	var disk: Profile = ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile
	assert_int(disk.data).is_equal(100 + 50 + 200 + 75)
	assert_bool(disk.claimed.has("ms_first_victory")).is_true()
	assert_bool(disk.awarded_run_ids.has("r1")).is_true()


func test_a_run_that_was_rewarded_pays_nothing_again_not_even_a_milestone() -> void:
	_win("r1", 100, _extras(15, ["siege_hulk"]))
	var before: int = Save.profile.data
	assert_bool(_win("r1", 100, _extras(15, ["siege_hulk"]))).is_false()  # a resumed run keeps its id
	assert_int(Save.profile.data).is_equal(before)
	assert_int(Save.profile.boss_kills["siege_hulk"]).is_equal(1)
	assert_int(Save.profile.victories_by_kit["k_standard"]).is_equal(1)


func test_a_milestone_a_restart_forgot_to_remember_is_remembered() -> void:
	_lose("r1", 0, _extras(5, ["siege_hulk"]))
	Save.load_profile()  # a restart: claimed comes back from the file
	_lose("r2", 0, _extras(5, ["siege_hulk"]))
	assert_int(Save.profile.data).is_equal(50)


func test_an_id_the_milestone_table_does_not_list_pays_nothing_and_is_not_claimed() -> void:
	_lose("r1", 0, _extras(5, ["boss_from_a_newer_build"]))
	assert_int(Save.profile.data).is_equal(0)
	assert_int(Save.profile.claimed.size()).is_equal(0)
	assert_int(Save.profile.boss_kills["boss_from_a_newer_build"]).is_equal(1)  # the kill itself is remembered


func test_with_no_milestone_table_the_run_still_pays() -> void:
	SaveTestData.boot_with(fs, ContentSet.new())  # no run definition: the legacy content has no milestones
	_win("r1", 100, _extras(5))
	assert_int(Save.profile.data).is_equal(100)
	assert_int(Save.profile.claimed.size()).is_equal(0)


# --- records ---


func test_the_best_wave_only_goes_up() -> void:
	_lose("r1", 0, _extras(7))
	_lose("r2", 0, _extras(4))
	assert_int(Save.profile.best_wave).is_equal(7)
	_lose("r3", 0, _extras(9))
	assert_int(Save.profile.best_wave).is_equal(9)


func test_data_lifetime_counts_the_run_and_its_milestones() -> void:
	_win("r1", 100, _extras(15))
	assert_int(Save.profile.data_lifetime).is_equal(375)
	Save.purchase_unlock(&"u_w_lmg")
	_lose("r2", 20, _extras(3))
	assert_int(Save.profile.data_lifetime).is_equal(395)
	assert_int(Save.profile.data).is_equal(395 - 120)


func test_last_reward_names_what_the_results_screen_shows() -> void:
	_win("r1", 100, _extras(15, ["siege_hulk"]))
	assert_str(Save.last_reward["run_id"]).is_equal("r1")
	assert_int(Save.last_reward["run_data"]).is_equal(100)
	assert_str(Save.last_reward["daily"]).is_equal("")
	var rows: Array = Save.last_reward["milestones"]
	var first: Dictionary = rows[0]
	assert_str(first["id"]).is_equal("ms_first_boss_siege_hulk")
	assert_int(first["data"]).is_equal(50)
	Save.load_profile()
	assert_dict(Save.last_reward).is_empty()  # only the latest grant of this session


func test_wrong_types_in_the_extras_are_ignored() -> void:
	var junk: Dictionary = {"best_wave": "ten", "boss_kills": "siege_hulk", "kit": 7, "primary_weapon": [1], "daily": 5}
	assert_bool(_win("r1", 100, junk)).is_true()
	assert_int(Save.profile.data).is_equal(300)  # the run and the first victory
	assert_int(Save.profile.best_wave).is_equal(0)
	assert_int(Save.profile.victories_by_kit.size()).is_equal(0)
	assert_bool(_win("r2", 100, {"boss_kills": [5, "", "x".repeat(200)]})).is_true()
	assert_int(Save.profile.boss_kills.size()).is_equal(0)


# --- the Daily Run ---


func test_the_first_daily_attempt_of_a_day_pays_in_full() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "2026-11-12"}})
	assert_int(Save.profile.data).is_equal(72)
	assert_str(Save.last_reward["daily"]).is_equal("rewarded")
	assert_dict(Save.profile.daily).is_equal({"date": "2026-11-12", "best_wave": 8, "won": false, "rewarded": true})


func test_further_attempts_of_the_same_day_pay_half() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "2026-11-12"}})
	_lose("d2", 31, {"best_wave": 4, "daily": {"date": "2026-11-12"}})
	assert_str(Save.last_reward["daily"]).is_equal("practice")
	assert_int(Save.last_reward["run_data"]).is_equal(15)  # floor of half of 31
	assert_int(Save.profile.data).is_equal(72 + 15)
	assert_int(Save.profile.daily["best_wave"]).is_equal(8)  # the best of the day stays
	_lose("d3", 100, {"best_wave": 10, "daily": {"date": "2026-11-12"}})
	assert_int(Save.profile.daily["best_wave"]).is_equal(10)
	assert_int(Save.profile.data).is_equal(72 + 15 + 50)


func test_a_win_is_remembered_for_the_day() -> void:
	_lose("d1", 60, {"best_wave": 10, "daily": {"date": "2026-11-12"}})
	Save.grant_run_reward("d2", RunResult.Id.VICTORY, 100, 400, {"best_wave": 15, "kit": "k_standard", "daily": {"date": "2026-11-12"}})
	assert_bool(Save.profile.daily["won"] == true).is_true()
	_lose("d3", 10, {"best_wave": 3, "daily": {"date": "2026-11-12"}})
	assert_bool(Save.profile.daily["won"] == true).is_true()  # a later loss does not take it back


func test_a_new_day_starts_a_new_record_and_pays_in_full_again() -> void:
	Save.grant_run_reward("d1", RunResult.Id.VICTORY, 100, 400, {"best_wave": 15, "daily": {"date": "2026-11-12"}})
	_lose("d2", 40, {"best_wave": 6, "daily": {"date": "2026-11-13"}})
	assert_str(Save.last_reward["daily"]).is_equal("rewarded")
	assert_int(Save.last_reward["run_data"]).is_equal(40)
	assert_dict(Save.profile.daily).is_equal({"date": "2026-11-13", "best_wave": 6, "won": false, "rewarded": true})


func test_a_plain_run_does_not_touch_the_daily_record() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "2026-11-12"}})
	_lose("p1", 50, _extras(12))
	assert_str(Save.last_reward["daily"]).is_equal("")
	assert_int(Save.last_reward["run_data"]).is_equal(50)
	assert_int(Save.profile.daily["best_wave"]).is_equal(8)


func test_a_daily_date_that_is_not_a_date_is_a_plain_run() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "today"}})
	assert_str(Save.last_reward["daily"]).is_equal("")
	assert_dict(Save.profile.daily).is_equal(Profile.empty_daily())


func test_the_daily_record_survives_a_restart() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "2026-11-12"}})
	Save.load_profile()
	_lose("d2", 30, {"best_wave": 3, "daily": {"date": "2026-11-12"}})
	assert_str(Save.last_reward["daily"]).is_equal("practice")


func test_practice_pays_half_but_milestones_stay_whole() -> void:
	_lose("d1", 72, {"best_wave": 8, "daily": {"date": "2026-11-12"}})
	_lose("d2", 40, {"best_wave": 5, "boss_kills": ["siege_hulk"], "daily": {"date": "2026-11-12"}})
	assert_int(Save.last_reward["run_data"]).is_equal(20)
	assert_int(Save.last_reward["milestone_data"]).is_equal(50)


func test_a_grant_without_extras_is_the_plain_data_grant() -> void:
	assert_bool(Save.grant_run_reward("plain", RunResult.Id.VICTORY, 140, 400)).is_true()
	assert_int(Save.profile.data).is_equal(140)  # no milestone: nothing was said about the run
	assert_int(Save.profile.claimed.size()).is_equal(0)
	assert_int(Save.profile.best_wave).is_equal(0)
