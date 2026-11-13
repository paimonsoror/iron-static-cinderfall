extends GdUnitTestSuite
## ProfileCodec for profile v2 (ARCH 7.5): every new field round-trips, damage is sanitized field by field, ids of a
## newer build are kept, and a schema 1 document comes out migrated.


func _full_profile() -> Profile:
	var p: Profile = Profile.defaults()
	p.data = 275
	p.data_lifetime = 1180
	p.unlocks = PackedStringArray(["u_w_lmg", "k_breacher"])
	p.claimed = PackedStringArray(["ms_first_victory"])
	p.kit = &"k_breacher"
	p.codex_seen = PackedStringArray(["enemy.burster"])
	p.best_wave = 11
	p.boss_kills = {"siege_hulk": 2}
	p.victories_by_kit = {"k_standard": 3, "k_breacher": 1}
	p.victory_weapons = PackedStringArray(["arc_projector", "lmg"])
	p.daily = {"date": "2026-11-12", "best_wave": 7, "won": true, "rewarded": true}
	p.settings[&"swap_assist"] = true
	return p


func test_every_v2_field_round_trips() -> void:
	var q: Profile = ProfileCodec.decode(ProfileCodec.encode(_full_profile())).profile
	assert_int(q.data).is_equal(275)
	assert_int(q.data_lifetime).is_equal(1180)
	assert_array(Array(q.unlocks)).is_equal(["u_w_lmg", "k_breacher"])
	assert_array(Array(q.claimed)).is_equal(["ms_first_victory"])
	assert_str(String(q.kit)).is_equal("k_breacher")
	assert_array(Array(q.codex_seen)).is_equal(["enemy.burster"])
	assert_int(q.best_wave).is_equal(11)
	assert_dict(q.boss_kills).is_equal({"siege_hulk": 2})
	assert_dict(q.victories_by_kit).is_equal({"k_standard": 3, "k_breacher": 1})
	assert_array(Array(q.victory_weapons)).is_equal(["arc_projector", "lmg"])
	assert_dict(q.daily).is_equal({"date": "2026-11-12", "best_wave": 7, "won": true, "rewarded": true})
	assert_bool(q.settings[&"swap_assist"]).is_true()


func test_the_encoded_file_is_stable() -> void:
	var once: String = ProfileCodec.encode(_full_profile())
	var twice: String = ProfileCodec.encode(ProfileCodec.decode(once).profile)
	assert_str(twice).is_equal(once)


func test_defaults_are_the_empty_v2_profile() -> void:
	var p: Profile = ProfileCodec.decode(ProfileCodec.encode(Profile.defaults())).profile
	assert_int(p.data_lifetime).is_equal(0)
	assert_int(p.unlocks.size() + p.claimed.size() + p.codex_seen.size() + p.victory_weapons.size()).is_equal(0)
	assert_str(String(p.kit)).is_equal("k_standard")
	assert_int(p.best_wave).is_equal(0)
	assert_int(p.boss_kills.size() + p.victories_by_kit.size()).is_equal(0)
	assert_dict(p.daily).is_equal({"date": "", "best_wave": 0, "won": false, "rewarded": false})
	assert_bool(p.settings[&"swap_assist"]).is_false()


func test_a_v2_fixture_decodes() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode(SaveTestData.text("profile_v2_progress"))
	assert_int(r.schema_version).is_equal(2)
	var p: Profile = r.profile
	assert_int(p.data).is_equal(275)
	assert_int(p.data_lifetime).is_equal(1180)
	assert_array(Array(p.unlocks)).is_equal(["u_w_lmg", "u_w_hornet", "u_p_blast", "k_breacher"])
	assert_array(Array(p.claimed)).is_equal(["ms_first_boss_siege_hulk", "ms_first_victory"])
	assert_str(String(p.kit)).is_equal("k_breacher")
	assert_int(p.best_wave).is_equal(11)
	assert_int(p.boss_kills["siege_hulk"]).is_equal(2)
	assert_int(p.victories_by_kit["k_standard"]).is_equal(3)
	assert_str(p.daily["date"]).is_equal("2026-11-12")
	assert_bool(p.daily["rewarded"] == true).is_true()
	assert_bool(p.settings[&"swap_assist"]).is_true()
	assert_bool(p.settings[&"haptics_on"]).is_false()


func test_ids_of_a_newer_build_are_kept_and_junk_is_dropped() -> void:
	var p: Profile = ProfileCodec.decode(SaveTestData.text("profile_v2_future_ids")).profile
	assert_array(Array(p.unlocks)).is_equal(["u_w_lmg", "u_x_from_a_newer_build"])  # the repeat, the number and "" are dropped
	assert_array(Array(p.claimed)).is_equal(["ms_first_victory", "ms_from_a_newer_build"])
	assert_str(String(p.kit)).is_equal("k_from_a_newer_build")
	assert_int(p.boss_kills["boss_from_a_newer_build"]).is_equal(4)
	assert_array(Array(p.victory_weapons)).is_equal(["weapon_from_a_newer_build"])
	var again: Profile = ProfileCodec.decode(ProfileCodec.encode(p)).profile  # an older build writes them back
	assert_array(Array(again.unlocks)).is_equal(Array(p.unlocks))
	assert_dict(again.boss_kills).is_equal(p.boss_kills)


func test_wrong_types_in_the_v2_fields_fall_back_to_the_defaults() -> void:
	var p: Profile = ProfileCodec.decode(SaveTestData.text("profile_v2_wrong_types")).profile
	assert_int(p.data).is_equal(0)
	assert_int(p.data_lifetime).is_equal(0)  # negative
	assert_int(p.unlocks.size()).is_equal(0)  # not a list
	assert_array(Array(p.claimed)).is_equal(["ms_first_victory"])
	assert_str(String(p.kit)).is_equal("k_standard")  # not a string
	assert_int(p.codex_seen.size()).is_equal(0)
	assert_int(p.best_wave).is_equal(2)  # fractions round down
	assert_dict(p.boss_kills).is_equal({"aegis_array": 2})  # "many", -3 and the empty id are dropped
	assert_int(p.victories_by_kit.size()).is_equal(0)
	assert_array(Array(p.victory_weapons)).is_equal(["lmg"])
	assert_dict(p.daily).is_equal(Profile.empty_daily())  # a date that is not YYYY-MM-DD voids the record
	assert_bool(p.settings[&"swap_assist"]).is_false()  # "yes" is not a bool
	assert_bool(p.settings[&"sound_on"]).is_false()


func test_a_v1_document_is_migrated_by_the_decoder() -> void:
	var r: ProfileDecodeResult = ProfileCodec.decode(SaveTestData.text("profile_v1_tester"))
	assert_int(r.schema_version).is_equal(1)
	var p: Profile = r.profile
	assert_int(p.data).is_equal(413)
	assert_int(p.data_lifetime).is_equal(413)
	assert_int(p.best_wave).is_equal(5)  # a mission was completed in the old five-wave run
	assert_int(p.unlocks.size() + p.claimed.size()).is_equal(0)
	assert_str(String(p.kit)).is_equal("k_standard")
	assert_dict(p.daily).is_equal(Profile.empty_daily())
	assert_bool(p.settings[&"swap_assist"]).is_false()
	assert_bool(p.settings[&"music_on"]).is_false()  # every v1 setting is kept


func test_v2_keys_in_a_v1_document_are_ignored() -> void:
	var p: Profile = ProfileCodec.decode(SaveTestData.text("profile_v1_readahead")).profile
	assert_int(p.data).is_equal(120)
	assert_int(p.unlocks.size()).is_equal(0)  # nothing is unlocked for free
	assert_str(String(p.kit)).is_equal("k_standard")


func test_a_v1_document_without_a_completed_mission_has_best_wave_zero() -> void:
	assert_int(ProfileCodec.decode(SaveTestData.text("profile_v1_fresh")).profile.best_wave).is_equal(0)


func test_tallies_are_capped_and_counters_clamped() -> void:
	var tally: Dictionary = {}
	for i: int in 80:
		tally["boss_%d" % i] = 1
	var text: String = JSON.stringify({"schema_version": 2, "boss_kills": tally, "best_wave": 1e300, "data_lifetime": 99999999999})
	var p: Profile = ProfileCodec.decode(text).profile
	assert_int(p.boss_kills.size()).is_equal(Profile.MAX_TALLY)
	assert_int(p.best_wave).is_equal(Profile.MAX_COUNT)
	assert_int(p.data_lifetime).is_equal(Profile.MAX_COUNT)


func test_the_date_check() -> void:
	assert_bool(Profile.is_date("2026-11-12")).is_true()
	for bad: String in ["", "2026-1-12", "2026/11/12", "26-11-12", "2026-11-1x", "2026-11-123", "yesterday", "2026-11-12 "]:
		assert_bool(Profile.is_date(bad)).is_false()


func test_a_malformed_daily_record_is_not_written_back() -> void:
	var p: Profile = Profile.defaults()
	p.daily = {"date": "someday", "best_wave": 4, "won": true, "rewarded": true}
	var q: Profile = ProfileCodec.decode(ProfileCodec.encode(p)).profile
	assert_dict(q.daily).is_equal(Profile.empty_daily())
