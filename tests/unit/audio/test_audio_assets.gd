extends GdUnitTestSuite
## The generated sound files: all ARCH 10 ids load, formats and lengths are in spec, the loops loop seamlessly.

const SFX_DIR: String = "res://assets/audio/sfx"
const LOOPS: Array[String] = ["ambience", "combat_drone"]
const STINGERS: Array[StringName] = [&"boss_stinger", &"victory", &"defeat"]


func _wav(id: StringName) -> AudioStreamWAV:
	return load("%s/%s.wav" % [SFX_DIR, String(id)]) as AudioStreamWAV


func _loop(name_of_loop: String) -> AudioStreamWAV:
	return load("res://assets/audio/loops/%s.wav" % name_of_loop) as AudioStreamWAV


func test_arch_10_lists_29_ids() -> void:
	assert_int(AudioTestKit.ARCH_IDS.size()).is_equal(29)


func test_every_arch_10_id_has_a_loadable_stream() -> void:
	for id: StringName in AudioTestKit.ARCH_IDS:
		var stream: AudioStreamWAV = _wav(id)
		assert_object(stream).override_failure_message("no loadable stream for %s" % String(id)).is_not_null()
		assert_float(stream.get_length()).override_failure_message("%s is empty" % String(id)).is_greater(0.05)


func test_the_catalog_lists_the_arch_ids_in_order_and_the_folder_holds_nothing_else() -> void:
	assert_array(AudioCatalog.IDS).is_equal(AudioTestKit.ARCH_IDS)
	var on_disk: Array[String] = []
	for file: String in DirAccess.get_files_at(SFX_DIR):
		if file.ends_with(".wav"):
			on_disk.append(file.get_basename())
	on_disk.sort()
	var wanted: Array[String] = []
	for id: StringName in AudioTestKit.ARCH_IDS:
		wanted.append(String(id))
	wanted.sort()
	assert_array(on_disk).is_equal(wanted)


func test_every_id_has_mix_parameters() -> void:
	for id: StringName in AudioTestKit.ARCH_IDS:
		assert_bool(AudioCatalog.has_sound(id)).is_true()
		assert_float(AudioCatalog.volume_db(id)).is_between(-24.0, 0.0)
		assert_float(AudioCatalog.pitch_jitter(id)).is_between(0.0, 0.1)
		assert_int(AudioCatalog.min_interval_ms(id)).is_between(20, 5000)
		assert_int(AudioCatalog.priority(id)).is_between(AudioCatalog.PRIORITY_LOW, AudioCatalog.PRIORITY_HIGH)
	assert_int(AudioCatalog.PARAMS.size()).is_equal(29)


func test_sfx_are_mono_16_bit_at_22050_or_44100_and_under_1_5_s_except_stingers() -> void:
	for id: StringName in AudioTestKit.ARCH_IDS:
		var stream: AudioStreamWAV = _wav(id)
		var label: String = String(id)
		assert_bool(stream.stereo).override_failure_message("%s is stereo" % label).is_false()
		assert_int(stream.format).override_failure_message("%s is not 16-bit" % label).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_bool(stream.mix_rate == 22050 or stream.mix_rate == 44100).override_failure_message("%s rate %d" % [label, stream.mix_rate]).is_true()
		if STINGERS.has(id):
			assert_float(stream.get_length()).override_failure_message(label).is_between(1.0, 4.0)
		else:
			assert_float(stream.get_length()).override_failure_message(label).is_less(1.5)


func test_sfx_are_loud_enough_never_clipped_and_start_and_end_at_silence() -> void:
	for id: StringName in AudioTestKit.ARCH_IDS:
		var x: PackedFloat32Array = AudioTestKit.samples(_wav(id))
		var label: String = String(id)
		var p: float = AudioTestKit.peak(x)
		assert_float(p).override_failure_message("%s peak %f" % [label, p]).is_between(0.3, 0.95)
		assert_float(absf(x[0])).override_failure_message("%s starts with a click" % label).is_less(0.01)
		assert_float(absf(x[x.size() - 1])).override_failure_message("%s ends with a click" % label).is_less(0.01)


func test_the_two_loops_are_12_to_24_s_mono_16_bit_and_loop_forward() -> void:
	for loop_name: String in LOOPS:
		var stream: AudioStreamWAV = _loop(loop_name)
		assert_object(stream).override_failure_message("loop %s missing" % loop_name).is_not_null()
		assert_float(stream.get_length()).override_failure_message(loop_name).is_between(12.0, 24.0)
		assert_bool(stream.stereo).is_false()
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_int(stream.loop_mode).override_failure_message("%s does not loop" % loop_name).is_equal(AudioStreamWAV.LOOP_FORWARD)
		assert_int(stream.loop_begin).is_equal(0)
		assert_int(stream.loop_end).is_equal(stream.data.size() >> 1)


func test_the_loops_are_continuous_across_the_wrap_point() -> void:
	for loop_name: String in LOOPS:
		var x: PackedFloat32Array = AudioTestKit.samples(_loop(loop_name))
		var ratio: float = AudioTestKit.seam_ratio(x)
		assert_float(ratio).override_failure_message("%s seam ratio %f" % [loop_name, ratio]).is_less(3.0)
		assert_float(AudioTestKit.peak(x)).is_between(0.3, 0.7)


func test_every_sound_the_hud_plays_is_in_the_catalog() -> void:
	var found: Dictionary[StringName, bool] = {}
	_scan_play_calls("res://src/ui", found)
	assert_bool(found.has(&"ui_tap")).is_true()
	assert_bool(found.has(&"ui_deny")).is_true()
	assert_bool(found.has(&"ui_purchase")).is_true()
	assert_bool(found.has(&"ui_drawer")).is_true()
	for id: StringName in found:
		assert_bool(AudioCatalog.has_sound(id)).override_failure_message("UI plays unknown sound %s" % String(id)).is_true()


func test_the_audio_license_says_everything_is_generated() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/audio/LICENSE.md")
	assert_str(text).contains("generated by the project script")
	assert_str(text).contains("tools/audio_gen/gen.py")


## Collects the ids of every `Sfx.play(&"...")` call under `dir`.
func _scan_play_calls(dir: String, found: Dictionary[StringName, bool]) -> void:
	var regex: RegEx = RegEx.new()
	@warning_ignore("return_value_discarded")
	regex.compile("Sfx\\.play\\(&\"(\\w+)\"\\)")
	for sub: String in DirAccess.get_directories_at(dir):
		_scan_play_calls(dir + "/" + sub, found)
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(dir + "/" + file)
		for m: RegExMatch in regex.search_all(source):
			found[StringName(m.get_string(1))] = true
