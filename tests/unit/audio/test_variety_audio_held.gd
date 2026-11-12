extends GdUnitTestSuite
## Held voices (VARIETY_SPEC 13.7): a looping voice per weapon slot, started and stopped by id, outside the 16-voice pool.
## Every test that starts one ends with the settle of test_game_audio_debug.gd, so no stream is in use when the run ends.

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


func test_hold_starts_a_looping_padded_voice_and_leaves_the_shared_stream_alone() -> void:
	_dir.hold(&"emp", 0)
	assert_bool(_dir.is_held(0)).is_true()
	assert_that(_dir.held_id(0)).is_equal(&"emp")
	assert_bool(_dir.held.players[0].playing).is_true()
	var looped: AudioStreamWAV = _dir.held.players[0].stream as AudioStreamWAV
	assert_int(looped.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(looped.loop_begin).is_equal(0)
	var shared: AudioStreamWAV = AudioCatalog.load_sfx(&"emp") as AudioStreamWAV
	assert_int(looped.loop_end).is_equal(shared.data.size() >> 1)  # the whole sound, mono 16-bit
	# the padding of AudioLoopPad: a wrap must not read past the data (a SIGSEGV on a phone)
	assert_int(looped.data.size()).is_greater_equal((looped.loop_end + AudioLoopPad.PAD_FRAMES) * 2)
	assert_int(shared.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	assert_object(looped).is_not_same(shared)
	await VarietyGKit.settle(self, _dir)


func test_a_held_voice_is_not_one_of_the_16_and_is_not_blocked_by_a_full_pool() -> void:
	VarietyGKit.fill_with_stingers(_dir, 15)
	@warning_ignore("return_value_discarded")
	_dir.try_play(&"ui_tap")
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_bool(_dir.try_hold(&"shot_arc", 0)).is_true()
	assert_bool(_dir.try_hold(&"shot_arc", 1)).is_true()
	assert_int(_dir.pool.active_count()).is_equal(16)  # the pool did not change
	assert_int(_dir.held.sounding_count()).is_equal(2)
	assert_int(_dir.held.players.size()).is_equal(2)  # and there can never be more than two
	await VarietyGKit.settle(self, _dir)


func test_the_alert_starts_while_both_slots_hold_a_loop() -> void:
	@warning_ignore("return_value_discarded")
	_dir.try_hold(&"emp", 0)
	@warning_ignore("return_value_discarded")
	_dir.try_hold(&"emp", 1)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_arc", &"arc_chain", &"blast_small", &"shot_pistol", &"shot_smg", &"hit_armor"], 20)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"warn_harm")).is_true()
	assert_int(_dir.pool.count_of(&"warn_harm")).is_equal(1)
	assert_int(_dir.held.sounding_count()).is_equal(2)
	await VarietyGKit.settle(self, _dir)


func test_holding_the_same_id_keeps_the_voice_and_another_id_replaces_it() -> void:
	_dir.hold(&"emp", 0)
	var first: AudioStream = _dir.held.players[0].stream
	_dir.hold(&"emp", 0)
	_dir.hold(&"emp", 0)
	assert_object(_dir.held.players[0].stream).is_same(first)
	assert_bool(_dir.held.players[0].playing).is_true()
	_dir.hold(&"shot_arc", 0)
	assert_that(_dir.held_id(0)).is_equal(&"shot_arc")
	assert_object(_dir.held.players[0].stream).is_not_same(first)
	assert_bool(_dir.is_held(1)).is_false()  # the other slot is its own voice
	await VarietyGKit.settle(self, _dir)


func test_release_fades_the_voice_out_and_frees_the_slot() -> void:
	_dir.hold(&"emp", 0)
	_dir.release(0)
	assert_bool(_dir.is_held(0)).is_false()  # released at once for the caller
	assert_that(_dir.held_id(0)).is_equal(&"")
	assert_bool(_dir.held.is_sounding(0)).is_true()  # but the loop is still fading, so it does not click
	_dir.advance(AudioHeldVoices.FADE_SECONDS * 0.5)
	assert_bool(_dir.held.is_sounding(0)).is_true()
	assert_float(_dir.held.players[0].volume_db).is_less(AudioCatalog.volume_db(&"emp"))
	_dir.advance(AudioHeldVoices.FADE_SECONDS)
	assert_bool(_dir.held.is_sounding(0)).is_false()
	assert_bool(_dir.held.players[0].playing).is_false()
	_dir.release(0)  # releasing a free slot, a bad slot or twice does nothing
	_dir.release(7)
	_dir.release(-1)
	await VarietyGKit.settle(self, _dir)


func test_holding_again_while_it_fades_takes_the_loop_back() -> void:
	_dir.hold(&"emp", 1)
	_dir.release(1)
	_dir.advance(AudioHeldVoices.FADE_SECONDS * 0.5)
	_dir.hold(&"emp", 1)
	assert_bool(_dir.is_held(1)).is_true()
	assert_float(_dir.held.players[1].volume_db).is_equal_approx(AudioCatalog.volume_db(&"emp"), 0.001)
	_dir.advance(1.0)
	assert_bool(_dir.held.is_sounding(1)).is_true()  # the cancelled fade does not stop it later
	await VarietyGKit.settle(self, _dir)


func test_the_two_slots_are_independent() -> void:
	_dir.hold(&"emp", 0)
	_dir.hold(&"shot_arc", 1)
	_dir.release(0)
	_dir.advance(1.0)
	assert_bool(_dir.held.is_sounding(0)).is_false()
	assert_bool(_dir.is_held(1)).is_true()
	assert_that(_dir.held_id(1)).is_equal(&"shot_arc")
	_dir.release_all_held()
	_dir.advance(1.0)
	assert_int(_dir.held.sounding_count()).is_equal(0)
	await VarietyGKit.settle(self, _dir)


func test_a_bad_slot_or_an_unknown_id_is_refused_and_logged_once() -> void:
	assert_bool(_dir.try_hold(&"emp", 2)).is_false()
	assert_bool(_dir.try_hold(&"emp", -1)).is_false()
	assert_int(_dir.warn_count).is_equal(1)  # the same id logs once
	assert_bool(_dir.try_hold(&"no_such_sound", 0)).is_false()
	assert_bool(_dir.try_hold(&"no_such_sound", 0)).is_false()
	assert_int(_dir.warn_count).is_equal(2)
	assert_int(_dir.held.sounding_count()).is_equal(0)


func test_pause_freezes_a_held_voice_and_resume_lets_it_go_on() -> void:
	_dir.hold(&"emp", 0)
	_dir.pause_all()
	assert_bool(_dir.held.players[0].stream_paused).is_true()
	assert_bool(_dir.held.is_sounding(0)).is_true()  # frozen, not gone
	assert_bool(_dir.try_hold(&"emp", 1)).is_false()  # nothing new starts while paused
	_dir.resume_all()
	assert_bool(_dir.held.players[0].stream_paused).is_false()
	assert_bool(_dir.held.players[0].playing).is_true()
	await VarietyGKit.settle(self, _dir)


func test_a_release_during_a_pause_stops_the_voice_at_once() -> void:
	_dir.hold(&"emp", 0)
	_dir.pause_all()
	_dir.release(0)
	assert_bool(_dir.held.is_sounding(0)).is_false()
	_dir.resume_all()
	assert_bool(_dir.held.players[0].playing).is_false()
	await VarietyGKit.settle(self, _dir)


func test_sound_off_and_mute_stop_a_held_voice_at_once_and_block_new_ones() -> void:
	_dir.hold(&"emp", 0)
	_dir.hold(&"emp", 1)
	Save.set_setting(&"sound_on", false)
	assert_int(_dir.held.sounding_count()).is_equal(0)
	assert_bool(_dir.try_hold(&"emp", 0)).is_false()
	Save.set_setting(&"sound_on", true)
	_dir.hold(&"emp", 0)
	assert_bool(_dir.held.is_sounding(0)).is_true()
	_dir.disabled = true
	assert_int(_dir.held.sounding_count()).is_equal(0)
	assert_bool(_dir.try_hold(&"emp", 0)).is_false()
	await VarietyGKit.settle(self, _dir)


func test_nothing_is_still_playing_after_the_settle() -> void:
	_dir.hold(&"emp", 0)
	_dir.hold(&"shot_arc", 1)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_arc", &"warn_harm", &"blast_big", &"draft_pick"], 3)
	_dir.start_ambience()
	await VarietyGKit.settle(self, _dir)
	assert_int(_dir.pool.active_count()).is_equal(0)
	assert_int(_dir.held.sounding_count()).is_equal(0)
	assert_bool(_dir.loop_ambience.playing).is_false()
	assert_bool(_dir.loop_drone.playing).is_false()
	for p: AudioStreamPlayer in _dir.held.players:
		assert_bool(p.playing).is_false()


func test_a_looped_copy_loops_pads_and_leaves_its_source_alone() -> void:
	var src: AudioStreamWAV = AudioStreamWAV.new()
	src.format = AudioStreamWAV.FORMAT_16_BITS
	var data: PackedByteArray = PackedByteArray()
	data.resize(4000)
	for i: int in data.size():
		data[i] = (i * 5 + 1) % 253
	src.data = data
	var copy: AudioStreamWAV = AudioLoopPad.looped_copy(src)
	assert_int(copy.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(copy.loop_begin).is_equal(0)
	assert_int(copy.loop_end).is_equal(2000)
	assert_int(copy.data.size()).is_greater_equal((2000 + AudioLoopPad.PAD_FRAMES) * 2)
	for i: int in AudioLoopPad.PAD_FRAMES * 2:
		assert_int(copy.data[4000 + i]).is_equal(data[i])  # what the loop plays next
	assert_int(src.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	assert_int(src.data.size()).is_equal(4000)


func test_a_looped_copy_keeps_the_loop_points_of_a_stream_that_already_loops_and_handles_stereo_and_8_bit() -> void:
	var src: AudioStreamWAV = AudioStreamWAV.new()
	src.format = AudioStreamWAV.FORMAT_16_BITS
	src.stereo = true
	var data: PackedByteArray = PackedByteArray()
	data.resize(8000)
	src.data = data
	src.loop_mode = AudioStreamWAV.LOOP_FORWARD
	src.loop_begin = 100
	src.loop_end = 1500
	var copy: AudioStreamWAV = AudioLoopPad.looped_copy(src)
	assert_int(copy.loop_begin).is_equal(100)
	assert_int(copy.loop_end).is_equal(1500)
	var eight: AudioStreamWAV = AudioStreamWAV.new()
	eight.format = AudioStreamWAV.FORMAT_8_BITS
	var small: PackedByteArray = PackedByteArray()
	small.resize(1000)
	eight.data = small
	assert_int(AudioLoopPad.looped_copy(eight).loop_end).is_equal(1000)
	var adpcm: AudioStreamWAV = AudioStreamWAV.new()
	adpcm.format = AudioStreamWAV.FORMAT_IMA_ADPCM
	assert_int(AudioLoopPad.looped_copy(adpcm).loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)  # plays once, never loops unpadded
