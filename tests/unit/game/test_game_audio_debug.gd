extends GdUnitTestSuite
## The audio debug switches (GameAudioDebug + DebugArgs): off by default, parsed from the arguments, applied to a director.

var _dir: AudioDirector
var _orig_amb_end: int = 0
var _orig_drone_end: int = 0


func before_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	_dir = AudioTestKit.make_director(self)
	# The beds are shared cached resources: remember their loop points and put them back after the test.
	_orig_amb_end = (load(AudioCatalog.LOOP_AMBIENCE) as AudioStreamWAV).loop_end
	_orig_drone_end = (load(AudioCatalog.LOOP_DRONE) as AudioStreamWAV).loop_end


func after_test() -> void:
	_restore(load(AudioCatalog.LOOP_AMBIENCE) as AudioStreamWAV, _orig_amb_end)
	_restore(load(AudioCatalog.LOOP_DRONE) as AudioStreamWAV, _orig_drone_end)
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()


func _restore(wav: AudioStreamWAV, loop_end: int) -> void:
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = loop_end
	if wav.has_meta(&"loop_tuned"):
		wav.remove_meta(&"loop_tuned")


func test_every_switch_is_off_by_default() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray())
	assert_int(a.sfx).is_equal(-1)
	assert_int(a.music).is_equal(-1)
	assert_int(a.loop_trim).is_equal(0)
	assert_bool(a.loop_off).is_false()
	assert_bool(a.audio_trace).is_false()


func test_the_flags_are_parsed() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray(["--sfx=0", "--music=1", "--loop-trim=64", "--loop-off", "--audio-trace"]))
	assert_int(a.sfx).is_equal(0)
	assert_int(a.music).is_equal(1)
	assert_int(a.loop_trim).is_equal(64)
	assert_bool(a.loop_off).is_true()
	assert_bool(a.audio_trace).is_true()


func test_bad_values_are_ignored() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray(["--sfx=2", "--music=x", "--loop-trim=-5"]))
	assert_int(a.sfx).is_equal(-1)
	assert_int(a.music).is_equal(-1)
	assert_int(a.loop_trim).is_equal(0)


func test_apply_to_sets_the_director_and_the_forced_settings_beat_the_saved_ones() -> void:
	GameAudioDebug.apply_to(_dir, DebugArgs.parse(PackedStringArray(["--sfx=0", "--music=0", "--audio-trace"])))
	assert_bool(_dir.trace).is_true()
	_dir.apply_settings()
	assert_bool(_dir.sound_on).is_false()
	assert_bool(_dir.music_on).is_false()
	assert_bool(_dir.try_play(&"ui_tap")).is_false()
	GameAudioDebug.apply_to(_dir, DebugArgs.parse(PackedStringArray(["--sfx=1", "--music=1"])))
	_dir.apply_settings()
	assert_bool(_dir.sound_on).is_true()
	assert_bool(_dir.music_on).is_true()


func test_loop_trim_pulls_the_loop_end_of_both_beds_back_once() -> void:
	GameAudioDebug.apply_to(_dir, DebugArgs.parse(PackedStringArray(["--loop-trim=100"])))
	_dir.start_ambience()
	_dir.start_ambience()  # a second start must not trim again
	var amb: AudioStreamWAV = _dir.loop_ambience.stream as AudioStreamWAV
	var drone: AudioStreamWAV = _dir.loop_drone.stream as AudioStreamWAV
	assert_int(amb.loop_end).is_equal(_orig_amb_end - 100)
	assert_int(drone.loop_end).is_equal(_orig_drone_end - 100)
	await _stop_beds()


func test_loop_off_makes_the_beds_play_once() -> void:
	GameAudioDebug.apply_to(_dir, DebugArgs.parse(PackedStringArray(["--loop-off"])))
	_dir.start_ambience()
	var amb: AudioStreamWAV = _dir.loop_ambience.stream as AudioStreamWAV
	assert_int(amb.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	await _stop_beds()


func test_without_the_switches_the_beds_are_untouched() -> void:
	GameAudioDebug.apply_to(_dir, DebugArgs.parse(PackedStringArray()))
	_dir.start_ambience()
	var amb: AudioStreamWAV = _dir.loop_ambience.stream as AudioStreamWAV
	assert_int(amb.loop_end).is_equal(_orig_amb_end)
	assert_int(amb.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	await _stop_beds()


## Stops the beds and lets the audio server drop its playbacks, so no stream is still in use when the run ends.
func _stop_beds() -> void:
	_dir.stop_ambience()
	_dir.advance(2.0)
	await get_tree().create_timer(0.3).timeout
