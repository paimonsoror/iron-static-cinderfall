extends GdUnitTestSuite
## AudioDirector beds and pause: ambience and drone, intensity, pause_all / resume_all.

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


func test_start_ambience_starts_both_beds_and_stop_ambience_fades_them_out() -> void:
	assert_bool(_dir.loop_ambience.playing).is_false()
	_dir.start_ambience()
	assert_bool(_dir.is_ambience_wanted()).is_true()
	assert_bool(_dir.loop_ambience.playing).is_true()
	assert_bool(_dir.loop_drone.playing).is_true()
	_dir.advance(2.0)  # fully faded in
	assert_float(_dir.loop_ambience.volume_db).is_equal_approx(AudioDirector.AMBIENCE_DB, 0.1)
	_dir.stop_ambience()
	_dir.advance(0.3)
	assert_bool(_dir.loop_ambience.playing).is_true()  # still fading
	_dir.advance(2.0)
	assert_bool(_dir.loop_ambience.playing).is_false()
	assert_bool(_dir.loop_drone.playing).is_false()


func test_the_beds_are_the_looping_streams() -> void:
	_dir.start_ambience()
	var amb: AudioStreamWAV = _dir.loop_ambience.stream as AudioStreamWAV
	var drone: AudioStreamWAV = _dir.loop_drone.stream as AudioStreamWAV
	assert_object(amb).is_not_null()
	assert_object(drone).is_not_null()
	assert_int(amb.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(drone.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)


func test_set_intensity_clamps_to_0_1() -> void:
	_dir.set_intensity(3.0)
	assert_float(_dir.intensity()).is_equal(1.0)
	_dir.set_intensity(-2.0)
	assert_float(_dir.intensity()).is_equal(0.0)
	_dir.set_intensity(0.4)
	assert_float(_dir.intensity()).is_equal_approx(0.4, 0.0001)


func test_the_drone_rises_with_intensity_and_is_silent_at_zero() -> void:
	_dir.start_ambience()
	_dir.set_intensity(0.0)
	_dir.advance(3.0)
	assert_float(_dir.loop_drone.volume_db).is_equal(AudioDirector.SILENT_DB)
	_dir.set_intensity(0.4)
	_dir.advance(5.0)
	var mid: float = _dir.loop_drone.volume_db
	_dir.set_intensity(1.0)
	_dir.advance(5.0)
	var full: float = _dir.loop_drone.volume_db
	assert_float(mid).is_greater(AudioDirector.SILENT_DB)
	assert_float(full).is_greater(mid)
	assert_float(full).is_equal_approx(AudioDirector.DRONE_DB_MAX, 0.1)


func test_the_drone_follows_a_new_level_smoothly_not_in_one_step() -> void:
	_dir.start_ambience()
	_dir.advance(2.0)
	_dir.set_intensity(1.0)
	_dir.advance(0.1)
	assert_float(_dir.drone_level()).is_between(0.01, 0.5)
	_dir.advance(5.0)
	assert_float(_dir.drone_level()).is_equal(1.0)


func test_pause_all_freezes_the_beds_and_the_fades() -> void:
	_dir.start_ambience()
	_dir.set_intensity(1.0)
	_dir.advance(0.2)
	var level: float = _dir.drone_level()
	_dir.pause_all()
	assert_bool(_dir.is_paused()).is_true()
	assert_bool(_dir.loop_ambience.stream_paused).is_true()
	assert_bool(_dir.loop_drone.stream_paused).is_true()
	_dir.advance(5.0)
	assert_float(_dir.drone_level()).is_equal(level)
	_dir.resume_all()
	assert_bool(_dir.loop_ambience.stream_paused).is_false()
	_dir.advance(5.0)
	assert_float(_dir.drone_level()).is_equal(1.0)


func test_while_paused_gameplay_sounds_are_dropped_but_ui_sounds_still_play() -> void:
	_dir.pause_all()
	assert_bool(_dir.try_play(&"shot_pistol")).is_false()
	assert_bool(_dir.try_play(&"wave_start")).is_false()
	assert_bool(_dir.try_play(&"ui_tap")).is_true()
	assert_bool(_dir.pool.players[0].stream_paused).is_false()  # a sound started during pause is not frozen
	_dir.resume_all()
	assert_bool(_dir.try_play(&"shot_pistol")).is_true()


## Waits `ms` of wall-clock time frame by frame. (GdUnit's await_millis can fire early on the first frame after a
## slow one, and the dummy audio driver mixes in blocks of about 93 ms, so the checks below use generous settle times.)
func _wait_wall(ms: int) -> void:
	var until: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await await_idle_frame()


func test_pause_all_stops_the_playback_position_and_resume_all_moves_it_again() -> void:
	assert_bool(_dir.try_play(&"victory")).is_true()  # 3.2 s long
	var voice: AudioStreamPlayer = _dir.pool.players[0]
	await _wait_wall(400)
	var running: float = voice.get_playback_position()
	assert_float(running).override_failure_message("the voice never advanced (audio driver?)").is_greater(0.1)
	_dir.pause_all()
	await _wait_wall(250)  # at least two mix blocks, so the mixer has seen the pause
	var frozen: float = voice.get_playback_position()
	await _wait_wall(400)
	assert_float(voice.get_playback_position()).is_equal_approx(frozen, 0.002)
	assert_bool(voice.playing).is_false()  # Godot reports a paused player as not playing ...
	assert_bool(voice.stream_paused).is_true()
	assert_int(_dir.pool.active_count()).is_equal(1)  # ... the pool still counts it as busy
	_dir.resume_all()
	await _wait_wall(500)
	assert_float(voice.get_playback_position()).is_greater(frozen + 0.1)
	assert_bool(voice.playing).is_true()
