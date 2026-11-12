extends GdUnitTestSuite
## AudioLoopPad: a looping WAV gets frames behind its loop end so the mixer's read at the wrap stays inside the buffer.
## (A real phone crashed 16 s into a run, at the second wrap of the 8 s drone loop, before this existed.)


func _wav(frames: int, stereo: bool = false, loop_begin: int = 0, loop_end: int = -1, width: int = 2) -> AudioStreamWAV:
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS if width == 2 else AudioStreamWAV.FORMAT_8_BITS
	w.stereo = stereo
	var frame_bytes: int = width * (2 if stereo else 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * frame_bytes)
	for i: int in data.size():
		data[i] = (i * 7 + 3) % 251  # a recognisable, non-repeating pattern
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = loop_begin
	w.loop_end = frames if loop_end < 0 else loop_end
	return w


func test_a_loop_that_ends_at_the_end_of_the_data_gets_the_loop_start_appended() -> void:
	var w: AudioStreamWAV = _wav(1000)
	var before: PackedByteArray = w.data.duplicate()
	assert_bool(AudioLoopPad.pad(w)).is_true()
	assert_int(w.loop_end).is_equal(1000)  # the loop points do not move
	assert_int(w.loop_begin).is_equal(0)
	assert_int(w.data.size()).is_greater_equal((1000 + AudioLoopPad.PAD_FRAMES) * 2)
	for i: int in AudioLoopPad.PAD_FRAMES * 2:
		assert_int(w.data[1000 * 2 + i]).is_equal(before[i])  # the padding is what the loop plays next


func test_padding_is_done_once() -> void:
	var w: AudioStreamWAV = _wav(1000)
	assert_bool(AudioLoopPad.pad(w)).is_true()
	var size_after: int = w.data.size()
	assert_bool(AudioLoopPad.pad(w)).is_false()
	assert_int(w.data.size()).is_equal(size_after)


func test_a_loop_start_inside_the_data_is_copied_from_there() -> void:
	var w: AudioStreamWAV = _wav(2000, false, 100, 2000)
	var before: PackedByteArray = w.data.duplicate()
	assert_bool(AudioLoopPad.pad(w)).is_true()
	for i: int in AudioLoopPad.PAD_FRAMES * 2:
		assert_int(w.data[2000 * 2 + i]).is_equal(before[100 * 2 + i])


func test_stereo_and_8_bit_use_the_right_frame_size() -> void:
	var s: AudioStreamWAV = _wav(1000, true)
	assert_bool(AudioLoopPad.pad(s)).is_true()
	assert_int(s.data.size()).is_greater_equal((1000 + AudioLoopPad.PAD_FRAMES) * 4)
	var e: AudioStreamWAV = _wav(1000, false, 0, -1, 1)
	assert_bool(AudioLoopPad.pad(e)).is_true()
	assert_int(e.data.size()).is_greater_equal(1000 + AudioLoopPad.PAD_FRAMES)


func test_streams_that_do_not_loop_or_are_unknown_are_left_alone() -> void:
	var w: AudioStreamWAV = _wav(1000)
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var size_before: int = w.data.size()
	assert_bool(AudioLoopPad.pad(w)).is_false()
	assert_int(w.data.size()).is_equal(size_before)
	assert_bool(AudioLoopPad.pad(null)).is_false()


func test_data_that_already_extends_behind_the_loop_end_is_left_alone() -> void:
	var w: AudioStreamWAV = _wav(2000, false, 0, 1000)  # the loop ends well inside the data
	assert_bool(AudioLoopPad.pad(w)).is_false()


func test_a_loop_too_short_to_copy_from_is_left_alone() -> void:
	var w: AudioStreamWAV = _wav(100)  # fewer frames than the padding
	assert_bool(AudioLoopPad.pad(w)).is_false()


func test_the_shipped_beds_are_padded_when_they_start() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	var dir: AudioDirector = AudioTestKit.make_director(self)
	dir.start_ambience()
	for p: AudioStreamPlayer in [dir.loop_ambience, dir.loop_drone]:
		var w: AudioStreamWAV = p.stream as AudioStreamWAV
		assert_int(w.data.size()).is_greater_equal((w.loop_end + AudioLoopPad.PAD_FRAMES) * 2)
	dir.stop_ambience()
	dir.advance(2.0)
	await get_tree().create_timer(0.3).timeout
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()
