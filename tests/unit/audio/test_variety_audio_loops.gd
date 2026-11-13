extends GdUnitTestSuite
## Every looping stream of the game is padded by AudioLoopPad (a mixer over-read at the wrap was a SIGSEGV on the phone with
## the hardened allocator): the two beds and the held weapon loops. The loop files themselves wrap without a seam.

const LOOPS_DIR: String = "res://assets/audio/loops"
const SRC_DIR: String = "res://src"

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


func _padded(w: AudioStreamWAV) -> bool:
	return w.data.size() >= (w.loop_end + AudioLoopPad.PAD_FRAMES) * 2  # 16-bit mono


func test_the_loop_list_of_the_catalog_is_the_two_held_sounds_the_router_holds() -> void:
	assert_array(AudioCatalog.LOOP_IDS).is_equal(VarietyGKit.LOOP_IDS)
	var held: Array[StringName] = []
	for weapon: StringName in AudioEventRouter.HELD_BY_WEAPON:
		var loop_id: StringName = AudioEventRouter.HELD_BY_WEAPON[weapon]
		held.append(loop_id)
		assert_bool(AudioCatalog.LOOP_IDS.has(loop_id)).override_failure_message("%s is held but not a catalog loop" % String(loop_id)).is_true()
	held.sort()
	var listed: Array[StringName] = AudioCatalog.LOOP_IDS.duplicate()
	listed.sort()
	assert_array(held).is_equal(listed)  # every catalog loop is held by a weapon: no loop waits unused


func test_every_loop_stream_of_the_catalog_is_padded_when_it_starts() -> void:
	for slot: int in AudioHeldVoices.SLOTS:
		var id: StringName = AudioCatalog.LOOP_IDS[slot]
		assert_bool(_dir.try_hold(id, slot)).is_true()
		var looped: AudioStreamWAV = _dir.held.players[slot].stream as AudioStreamWAV
		var label: String = String(id)
		assert_int(looped.loop_mode).override_failure_message("%s does not loop" % label).is_equal(AudioStreamWAV.LOOP_FORWARD)
		assert_int(looped.loop_begin).is_equal(0)
		assert_bool(_padded(looped)).override_failure_message("%s is not padded: the mixer would read past the data at the wrap" % label).is_true()
		var shared: AudioStreamWAV = AudioCatalog.load_sfx(id) as AudioStreamWAV
		assert_int(shared.loop_mode).override_failure_message("%s: the shared resource was touched" % label).is_equal(AudioStreamWAV.LOOP_DISABLED)
		assert_int(shared.data.size()).override_failure_message("%s: the shared resource was padded" % label).is_less(looped.data.size())
	_dir.start_ambience()
	for p: AudioStreamPlayer in [_dir.loop_ambience, _dir.loop_drone]:
		var bed: AudioStreamWAV = p.stream as AudioStreamWAV
		assert_bool(_padded(bed)).override_failure_message("a bed is not padded").is_true()
	await VarietyGKit.settle(self, _dir)


func test_the_padding_of_a_held_loop_is_what_the_loop_plays_next() -> void:
	for id: StringName in AudioCatalog.LOOP_IDS:
		var copy: AudioStreamWAV = AudioLoopPad.looped_copy(AudioCatalog.load_sfx(id) as AudioStreamWAV)
		for i: int in AudioLoopPad.PAD_FRAMES * 2:
			assert_int(copy.data[copy.loop_end * 2 + i]).override_failure_message("%s byte %d" % [String(id), i]).is_equal(copy.data[i])


func test_a_loop_reaches_the_mixer_padded_whichever_way_the_weapon_starts_it() -> void:
	# the way the game does it: the router holds the loop of the weapon on the first round
	var events: AudioTestEvents = auto_free(AudioTestEvents.new())
	add_child(events)
	var routed: AudioDirector = AudioTestKit.make_routed(self, events)
	events.weapon_swapped.emit(0, &"cutting_torch")
	events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	var torch: AudioStreamWAV = routed.held.players[0].stream as AudioStreamWAV
	assert_bool(_padded(torch)).is_true()
	events.weapon_swapped.emit(1, &"lmg")
	events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	var motor: AudioStreamWAV = routed.held.players[1].stream as AudioStreamWAV
	assert_bool(_padded(motor)).is_true()
	await VarietyGKit.settle(self, routed)


func test_only_the_padding_class_turns_a_stream_into_a_loop_and_the_loops_folder_holds_the_two_beds() -> void:
	# nothing in src/ may set a stream to loop forward by hand: a loop made that way would skip the padding
	var offenders: Array[String] = []
	_scan_for_loops(SRC_DIR, offenders)
	assert_array(offenders).is_empty()
	var beds: Array[String] = []
	for file: String in DirAccess.get_files_at(LOOPS_DIR):
		if file.ends_with(".wav"):
			beds.append("%s/%s" % [LOOPS_DIR, file])
	beds.sort()
	var wanted: Array[String] = [AudioCatalog.LOOP_AMBIENCE, AudioCatalog.LOOP_DRONE]
	wanted.sort()
	assert_array(beds).is_equal(wanted)


func test_the_held_loops_wrap_without_a_seam_and_have_no_dip() -> void:
	for id: StringName in AudioCatalog.LOOP_IDS:
		var x: PackedFloat32Array = AudioTestKit.samples(AudioCatalog.load_sfx(id) as AudioStreamWAV)
		var label: String = String(id)
		assert_float(AudioTestKit.seam_ratio(x)).override_failure_message("%s seam ratio" % label).is_less(3.0)
		# the level of the first and the last tenth of a second is the level of the middle: no fade-in or fade-out at the edges
		var edge: int = 2205
		var mid: float = _rms(x, 10000, edge)
		assert_float(_rms(x, 0, edge)).override_failure_message("%s: dip at the start" % label).is_greater(mid * 0.5)
		assert_float(_rms(x, x.size() - edge, edge)).override_failure_message("%s: dip at the end" % label).is_greater(mid * 0.5)
		assert_float(x.size() / 22050.0).is_between(0.9, 1.1)


func _rms(x: PackedFloat32Array, from: int, count: int) -> float:
	var sum: float = 0.0
	for i: int in count:
		sum += x[from + i] * x[from + i]
	return sqrt(sum / float(count))


func _scan_for_loops(dir: String, offenders: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_scan_for_loops(dir + "/" + sub, offenders)
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd") or file == "audio_loop_pad.gd":
			continue
		var text: String = FileAccess.get_file_as_string(dir + "/" + file)
		if text.contains("LOOP_FORWARD") or text.contains("LOOP_PINGPONG") or text.contains("LOOP_BACKWARD"):
			offenders.append(dir + "/" + file)
