extends GdUnitTestSuite
## AudioDirector: play, caps, pool, toggles, pause. Each test builds its own director (no Events router).

var _dir: AudioDirector


func before_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	_dir = AudioTestKit.make_director(self)


func after_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()


func test_play_starts_a_voice_for_a_known_id() -> void:
	assert_bool(_dir.try_play(&"shot_pistol")).is_true()
	assert_int(_dir.started_total).is_equal(1)
	assert_int(_dir.pool.active_count()).is_equal(1)
	assert_int(_dir.pool.count_of(&"shot_pistol")).is_equal(1)


func test_play_of_an_unknown_id_logs_once_and_does_not_crash() -> void:
	_dir.play(&"no_such_sound")
	_dir.play(&"no_such_sound")
	_dir.play(&"no_such_sound")
	assert_int(_dir.warn_count).is_equal(1)
	assert_int(_dir.started_total).is_equal(0)
	assert_int(_dir.pool.active_count()).is_equal(0)
	_dir.play(&"another_missing_sound")
	assert_int(_dir.warn_count).is_equal(2)


func test_100_plays_of_shot_smg_in_one_frame_start_at_most_3_voices() -> void:
	for i: int in 100:
		_dir.play(&"shot_smg")
	assert_int(_dir.started_total).is_equal(3)
	assert_int(_dir.pool.count_of(&"shot_smg")).is_less_equal(3)


func test_with_the_real_interval_on_the_same_burst_starts_even_fewer() -> void:
	_dir.gate.intervals_enabled = true
	for i: int in 100:
		_dir.play(&"shot_smg")
	assert_int(_dir.started_total).is_between(1, 3)


func test_disabled_plays_nothing() -> void:
	_dir.disabled = true
	for id: StringName in AudioTestKit.ARCH_IDS:
		assert_bool(_dir.try_play(id)).is_false()
	assert_int(_dir.started_total).is_equal(0)
	assert_int(_dir.pool.active_count()).is_equal(0)
	_dir.start_ambience()
	assert_bool(_dir.loop_ambience.playing).is_false()


func test_disabling_stops_what_is_already_playing() -> void:
	assert_bool(_dir.try_play(&"victory")).is_true()
	_dir.start_ambience()
	assert_bool(_dir.loop_ambience.playing).is_true()
	_dir.disabled = true
	assert_int(_dir.pool.active_count()).is_equal(0)
	assert_bool(_dir.loop_ambience.playing).is_false()
	assert_bool(_dir.loop_drone.playing).is_false()


func test_sound_off_silences_effects_and_stops_voices_at_once() -> void:
	assert_bool(_dir.try_play(&"victory")).is_true()
	_dir.sound_on = false
	assert_bool(_dir.try_play(&"ui_tap")).is_false()
	assert_bool(_dir.try_play(&"shot_pistol")).is_false()
	_dir.apply_settings()  # Save still says sound_on = true, so this turns it back on
	assert_bool(_dir.sound_on).is_true()
	Save.set_setting(&"sound_on", false)
	assert_bool(_dir.sound_on).is_false()
	assert_int(_dir.pool.active_count()).is_equal(0)
	assert_bool(_dir.try_play(&"ui_tap")).is_false()
	Save.set_setting(&"sound_on", true)
	assert_bool(_dir.try_play(&"ui_tap")).is_true()


func test_music_off_stops_the_beds_and_blocks_new_ones_while_effects_still_play() -> void:
	_dir.start_ambience()
	assert_bool(_dir.loop_ambience.playing).is_true()
	Save.set_setting(&"music_on", false)
	assert_bool(_dir.music_on).is_false()
	assert_bool(_dir.loop_ambience.playing).is_false()
	assert_bool(_dir.loop_drone.playing).is_false()
	_dir.start_ambience()
	assert_bool(_dir.loop_ambience.playing).is_false()
	assert_bool(_dir.try_play(&"ui_tap")).is_true()
	Save.set_setting(&"music_on", true)
	assert_bool(_dir.loop_ambience.playing).is_true()


func test_apply_settings_reads_both_toggles_from_save() -> void:
	Save.set_setting(&"sound_on", false)
	Save.set_setting(&"music_on", false)
	var fresh: AudioDirector = AudioTestKit.make_director(self)
	assert_bool(fresh.sound_on).is_true()  # make_director forces them on
	fresh.apply_settings()
	assert_bool(fresh.sound_on).is_false()
	assert_bool(fresh.music_on).is_false()


func test_pitch_jitter_stays_inside_the_catalog_range_and_repeats_for_one_seed() -> void:
	var jitter: float = AudioCatalog.pitch_jitter(&"hit_ceramic")
	assert_float(jitter).is_greater(0.0)
	var first: Array[float] = []
	_dir.seed_rng(1234)
	for i: int in 3:
		assert_bool(_dir.try_play(&"hit_ceramic")).is_true()
		first.append(_dir.last_pitch)
		assert_float(_dir.last_pitch).is_between(1.0 - jitter, 1.0 + jitter)
	var again: AudioDirector = AudioTestKit.make_director(self)
	again.seed_rng(1234)
	for i: int in 3:
		assert_bool(again.try_play(&"hit_ceramic")).is_true()
		assert_float(again.last_pitch).is_equal(first[i])
	assert_bool(first[0] == first[1] and first[1] == first[2]).is_false()


func test_ids_without_jitter_play_at_exactly_pitch_1() -> void:
	assert_bool(_dir.try_play(&"victory")).is_true()
	assert_float(_dir.last_pitch).is_equal(1.0)


func test_the_pool_has_16_voices_and_never_more() -> void:
	assert_int(_dir.pool.players.size()).is_equal(16)
	var ids: Array[StringName] = [&"victory", &"defeat", &"boss_stinger", &"wave_start", &"wave_clear", &"core_low"]
	for id: StringName in ids:
		for i: int in 3:
			@warning_ignore("return_value_discarded")
			_dir.try_play(id)
	assert_int(_dir.pool.active_count()).is_equal(16)


func test_when_full_a_low_priority_sound_is_dropped_and_a_high_priority_one_takes_the_oldest_voice() -> void:
	var ids: Array[StringName] = [&"victory", &"defeat", &"boss_stinger", &"wave_start", &"wave_clear"]
	for id: StringName in ids:
		for i: int in 3:
			assert_bool(_dir.try_play(id)).is_true()
	assert_bool(_dir.try_play(&"core_low")).is_true()  # the 16th voice
	assert_bool(_dir.try_play(&"shot_pistol")).is_false()
	assert_bool(_dir.try_play(&"death_small")).is_false()
	assert_bool(_dir.try_play(&"ui_tap")).is_true()
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_int(_dir.pool.count_of(&"ui_tap")).is_equal(1)


func test_when_full_a_mid_priority_sound_takes_a_low_priority_voice() -> void:
	var low: Array[StringName] = [&"shot_pistol", &"shot_smg", &"shot_turret", &"hit_ceramic", &"hit_armor"]
	for id: StringName in low:
		for i: int in 3:
			assert_bool(_dir.try_play(id)).is_true()
	assert_bool(_dir.try_play(&"emp")).is_true()  # the 16th voice, mid priority
	assert_bool(_dir.try_play(&"death_small")).is_true()  # steals the oldest low voice
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_int(_dir.pool.count_of(&"shot_pistol")).is_equal(2)
	assert_int(_dir.pool.count_of(&"death_small")).is_equal(1)
