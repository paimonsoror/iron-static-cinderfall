extends GdUnitTestSuite
## The 14 sounds of the slice (VARIETY_SPEC 12.1): catalog rows, files, formats, voice classes, and the mirrors of the
## enums the audio layer may not read.

const SFX_DIR: String = "res://assets/audio/sfx"


func _wav(id: StringName) -> AudioStreamWAV:
	return load("%s/%s.wav" % [SFX_DIR, String(id)]) as AudioStreamWAV


func test_the_spec_lists_60_new_ids_and_the_slice_is_14_of_them() -> void:
	assert_int(VarietyGKit.SPEC_IDS.size()).is_equal(60)
	assert_int(VarietyGKit.SLICE_IDS.size()).is_equal(14)
	for id: StringName in VarietyGKit.SLICE_IDS:
		assert_bool(VarietyGKit.SPEC_IDS.has(id)).override_failure_message("%s is not a spec id" % String(id)).is_true()
		assert_bool(AudioTestKit.ARCH_IDS.has(id)).override_failure_message("%s is a legacy id" % String(id)).is_false()


func test_the_catalog_lists_exactly_the_14_slice_ids_after_the_29_legacy_ones() -> void:
	assert_array(AudioCatalog.VARIETY_IDS).is_equal(VarietyGKit.SLICE_IDS)
	assert_array(AudioCatalog.IDS).is_equal(AudioTestKit.ARCH_IDS)
	var all: Array[StringName] = AudioCatalog.all_ids()
	assert_int(all.size()).is_equal(43)
	assert_array(all.slice(0, 29)).is_equal(AudioTestKit.ARCH_IDS)
	assert_array(all.slice(29)).is_equal(VarietyGKit.SLICE_IDS)


func test_every_new_id_in_the_catalog_has_a_loadable_file_and_a_mix_row() -> void:
	for id: StringName in AudioCatalog.VARIETY_IDS:
		var label: String = String(id)
		assert_bool(AudioCatalog.has_sound(id)).override_failure_message("no row for %s" % label).is_true()
		assert_bool(FileAccess.file_exists(AudioCatalog.sfx_path(id))).override_failure_message("no file for %s" % label).is_true()
		var stream: AudioStreamWAV = _wav(id)
		assert_object(stream).override_failure_message("%s does not load" % label).is_not_null()
		assert_float(stream.get_length()).override_failure_message("%s is empty" % label).is_greater(0.05)
		assert_float(AudioCatalog.volume_db(id)).override_failure_message(label).is_between(-24.0, 0.0)
		assert_float(AudioCatalog.pitch_jitter(id)).override_failure_message(label).is_between(0.0, 0.1)
		assert_int(AudioCatalog.min_interval_ms(id)).override_failure_message(label).is_between(20, 5000)
		assert_int(AudioCatalog.priority(id)).override_failure_message(label).is_between(AudioCatalog.PRIORITY_LOW, AudioCatalog.PRIORITY_HIGH)


func test_every_catalog_id_has_a_file_and_no_wav_is_left_over() -> void:
	var on_disk: Array[String] = []
	for file: String in DirAccess.get_files_at(SFX_DIR):
		if file.ends_with(".wav"):
			on_disk.append(file.get_basename())
	on_disk.sort()
	var wanted: Array[String] = []
	for id: StringName in AudioCatalog.all_ids():
		wanted.append(String(id))
	wanted.sort()
	assert_array(on_disk).is_equal(wanted)
	assert_int(AudioCatalog.PARAMS.size()).is_equal(43)


func test_the_new_sounds_are_mono_16_bit_short_audible_unclipped_and_click_free() -> void:
	for id: StringName in AudioCatalog.VARIETY_IDS:
		var stream: AudioStreamWAV = _wav(id)
		var label: String = String(id)
		assert_bool(stream.stereo).override_failure_message("%s is stereo" % label).is_false()
		assert_int(stream.format).override_failure_message("%s is not 16-bit PCM: set compress/mode=0 in its .import" % label).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_int(stream.mix_rate).override_failure_message("%s rate" % label).is_equal(22050)
		assert_float(stream.get_length()).override_failure_message("%s is not under 1.5 s" % label).is_less(1.5)
		assert_int(stream.loop_mode).override_failure_message("%s loops" % label).is_equal(AudioStreamWAV.LOOP_DISABLED)
		var x: PackedFloat32Array = AudioTestKit.samples(stream)
		var p: float = AudioTestKit.peak(x)
		assert_float(p).override_failure_message("%s peak %f" % [label, p]).is_between(0.3, 0.95)
		assert_float(absf(x[0])).override_failure_message("%s starts with a click" % label).is_less(0.01)
		assert_float(absf(x[x.size() - 1])).override_failure_message("%s ends with a click" % label).is_less(0.01)


func test_every_new_file_is_imported_as_plain_pcm() -> void:
	# Godot imports a new WAV compressed (compress/mode=2) unless told otherwise; the loops and the pad need raw 16-bit PCM
	for id: StringName in AudioCatalog.VARIETY_IDS:
		var text: String = FileAccess.get_file_as_string(AudioCatalog.sfx_path(id) + ".import")
		assert_str(text).override_failure_message("%s: .import is missing or not PCM" % String(id)).contains("compress/mode=0")
		assert_str(text).contains("edit/loop_mode=0")


func test_the_sounds_that_must_stay_short_do_stay_short() -> void:
	# a chain arc and a mote burn-out arrive by the dozen; the crackle must be over before the next jump
	assert_float(_wav(&"arc_chain").get_length()).is_less(0.4)
	assert_float(_wav(&"mote_burn").get_length()).is_less(0.5)
	assert_float(_wav(&"weapon_swap").get_length()).is_less(0.5)
	# the fuse sound lasts as long as the burster's 1.2 s arming (CONTENT 4)
	assert_float(_wav(&"burster_arm").get_length()).is_between(1.1, 1.5)


func test_voice_classes_follow_the_spec_10_5() -> void:
	for id: StringName in [&"warn_harm", &"strike_call", &"core_low"]:
		assert_int(AudioCatalog.voice_class(id)).override_failure_message(String(id)).is_equal(AudioCatalog.CLASS_ALERT)
		assert_int(AudioCatalog.effective_priority(id)).is_equal(AudioCatalog.PRIORITY_ALERT)
	for id: StringName in [&"shot_arc", &"arc_chain", &"weapon_swap"]:
		assert_int(AudioCatalog.voice_class(id)).override_failure_message(String(id)).is_equal(AudioCatalog.CLASS_WEAPON)
	for id: StringName in [&"blast_small", &"blast_big", &"strike_impact"]:
		assert_int(AudioCatalog.voice_class(id)).override_failure_message(String(id)).is_equal(AudioCatalog.CLASS_BLAST)
	for id: StringName in [&"draft_open", &"draft_pick", &"route_pick", &"crate_secured"]:
		assert_int(AudioCatalog.voice_class(id)).override_failure_message(String(id)).is_equal(AudioCatalog.CLASS_UI)
		assert_bool(AudioCatalog.is_ui(id)).is_true()
	# the legacy sounds keep their behaviour: no class but the core alarm and the ui_* family
	for id: StringName in AudioTestKit.ARCH_IDS:
		if id == &"core_low" or String(id).begins_with("ui_"):
			continue
		assert_int(AudioCatalog.voice_class(id)).override_failure_message(String(id)).is_equal(AudioCatalog.CLASS_OTHER)
		assert_int(AudioCatalog.effective_priority(id)).is_equal(AudioCatalog.priority(id))
	for id: StringName in AudioCatalog.CLASSES:
		assert_bool(AudioCatalog.has_sound(id)).override_failure_message("class of unknown id %s" % String(id)).is_true()
	assert_int(AudioCatalog.voice_class(&"no_such_sound")).is_equal(AudioCatalog.CLASS_OTHER)


func test_the_class_limits_are_the_spec_numbers() -> void:
	assert_int(AudioDirector.VOICES).is_equal(16)
	assert_int(AudioVoicePool.ALERT_RESERVED).is_equal(3)
	assert_int(AudioVoicePool.WEAPON_MAX).is_equal(8)
	assert_int(AudioVoicePool.class_cap(AudioCatalog.CLASS_WEAPON)).is_equal(8)
	assert_int(AudioVoicePool.class_cap(AudioCatalog.CLASS_ALERT)).is_equal(3)
	assert_int(AudioVoicePool.class_cap(AudioCatalog.CLASS_BLAST)).is_equal(0)
	assert_int(AudioVoiceGate.MAX_STARTS_PER_FRAME).is_equal(3)  # blasts: at most 3 starts per frame (the per-id cap)
	assert_int(AudioBlastMerge.BIG_AT).is_equal(4)


func test_the_mirrored_enums_match_their_sources() -> void:
	# the audio layer may not read the sim or RunApi, so it mirrors three hazard kinds and one await value
	assert_int(AudioVarietyRoutes.KIND_STRIKE).is_equal(HazardState.K_STRIKE)
	assert_int(AudioVarietyRoutes.KIND_DRUM).is_equal(HazardState.K_DRUM)
	assert_int(AudioVarietyRoutes.KIND_VENT).is_equal(HazardState.K_VENT)
	assert_int(AudioVarietyRoutes.AWAIT_NONE).is_equal(RunApi.AWAIT_NONE)


func test_every_sound_the_router_tables_name_is_in_the_catalog() -> void:
	var named: Array[StringName] = []
	for table: Dictionary in [AudioEventRouter.SHOT_SOUNDS, AudioEventRouter.HELD_BY_WEAPON, AudioVarietyRoutes.AREA_BLAST_SOUNDS,
			AudioVarietyRoutes.DELAYED_HIT_SOUNDS, AudioVarietyRoutes.EVENT_SOUNDS]:
		for key: Variant in table:
			var sound: StringName = table[key]
			named.append(sound)
	named.append(AudioVarietyRoutes.REROLL_SOUND)
	named.append(AudioBlastMerge.SMALL)
	named.append(AudioBlastMerge.BIG)
	for sound: StringName in named:
		assert_bool(AudioCatalog.has_sound(sound)).override_failure_message("router names unknown sound %s" % String(sound)).is_true()
	for weapon: StringName in AudioEventRouter.SHOT_SOUNDS:
		assert_bool(Ids.WEAPONS.has(weapon)).override_failure_message("unknown weapon %s" % String(weapon)).is_true()
	for kind: StringName in AudioEventRouter.ARMORED_KINDS + AudioEventRouter.HEAVY_CORE_KINDS + AudioEventRouter.LIGHT_CORE_KINDS + AudioEventRouter.MINI_KINDS:
		assert_bool(Ids.ENEMIES.has(kind)).override_failure_message("unknown enemy %s" % String(kind)).is_true()
	assert_int(AudioVarietyRoutes.ACT_INTENSITY.size()).is_equal(3)
