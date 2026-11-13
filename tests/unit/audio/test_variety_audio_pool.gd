extends GdUnitTestSuite
## Voice classes (VARIETY_SPEC 10.5): a flood of weapon sounds or blasts must not starve the warning that matters.

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


func test_a_flood_of_weapon_sounds_holds_at_most_8_voices() -> void:
	var weapons: Array[StringName] = [&"shot_arc", &"arc_chain", &"weapon_swap"]
	var started: int = VarietyGKit.flood(_dir, weapons, 12)
	assert_int(started).is_greater(8)  # the later ones recycled the oldest weapon voices
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_WEAPON)).is_equal(8)
	assert_int(_dir.pool.active_count()).is_equal(8)
	assert_int(_dir.pool.active_count()).is_less_equal(AudioDirector.VOICES - AudioVoicePool.ALERT_RESERVED)


func test_a_weapon_flood_never_takes_the_voice_of_another_class_or_the_reserve() -> void:
	VarietyGKit.fill_with_stingers(_dir, 6)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_arc", &"arc_chain"], 20)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_OTHER)).is_equal(6)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_WEAPON)).is_between(7, 8)
	assert_int(_dir.pool.active_count()).is_equal(13)  # 16 voices minus the 3 reserved for alerts


func test_the_alert_still_starts_when_weapon_sounds_flood_the_pool() -> void:
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_arc", &"arc_chain", &"weapon_swap"], 20)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"blast_small", &"blast_big", &"strike_impact"], 20)
	assert_int(_dir.pool.active_count()).is_less_equal(AudioDirector.VOICES - AudioVoicePool.ALERT_RESERVED)
	# the legacy shots and hits have no class, so they may fill the reserve: the alert must still get in
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_pistol", &"shot_smg", &"shot_turret", &"hit_ceramic", &"hit_armor"], 6)
	assert_int(_dir.pool.active_count()).is_equal(AudioDirector.VOICES)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"warn_harm")).is_true()
	assert_int(_dir.pool.count_of(&"warn_harm")).is_equal(1)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(1)


func test_the_alert_starts_even_when_sixteen_top_priority_voices_are_busy() -> void:
	VarietyGKit.fill_with_stingers(_dir, 15)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"ui_tap")).is_true()  # the 16th voice, priority 2, takes the last free one
	assert_int(_dir.pool.active_count()).is_equal(16)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"warn_harm")).is_true()  # a stinger of the same priority class loses its voice to the alert
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_int(_dir.pool.count_of(&"warn_harm")).is_equal(1)
	# and nothing but an alert can take an alert's voice
	for id: StringName in [&"victory", &"ui_tap", &"death_boss", &"blast_big", &"draft_open", &"shot_pistol"]:
		_dir.gate.clear()
		@warning_ignore("return_value_discarded")
		_dir.try_play(id)
	assert_int(_dir.pool.count_of(&"warn_harm")).is_equal(1)


func test_weapons_and_blasts_leave_the_last_three_voices_to_the_alerts() -> void:
	VarietyGKit.fill_with_stingers(_dir, 13)
	assert_int(_dir.pool.active_count()).is_equal(13)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"shot_arc")).is_false()  # three free voices, but they are the alerts' (a stinger outranks it)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"blast_small")).is_false()
	assert_int(_dir.pool.active_count()).is_equal(13)  # the pool did not grow into the reserve
	for id: StringName in [&"warn_harm", &"strike_call", &"core_low"]:
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message(String(id)).is_true()
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(3)


func test_a_fourth_alert_takes_the_oldest_alert_and_never_another_class() -> void:
	VarietyGKit.fill_with_stingers(_dir, 13)
	for id: StringName in [&"warn_harm", &"strike_call", &"core_low"]:
		_dir.gate.clear()
		@warning_ignore("return_value_discarded")
		_dir.try_play(id)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_OTHER)).is_equal(13)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"warn_harm")).is_true()
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(3)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_OTHER)).is_equal(13)
	assert_int(_dir.pool.active_count()).is_equal(16)


func test_a_blast_does_not_take_a_reserved_voice_from_a_quiet_pool() -> void:
	# 13 voices busy with sounds of priority 2: the blast (priority 2) recycles one of them instead of using the reserve
	VarietyGKit.fill_with_stingers(_dir, 13)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"strike_impact")).is_true()
	assert_int(_dir.pool.active_count()).is_equal(13)
	assert_int(_dir.pool.count_of(&"strike_impact")).is_equal(1)


func test_the_ui_and_the_legacy_sounds_still_use_every_voice() -> void:
	VarietyGKit.fill_with_stingers(_dir, 15)
	_dir.gate.clear()
	assert_bool(_dir.try_play(&"draft_open")).is_true()
	assert_int(_dir.pool.active_count()).is_equal(16)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_UI)).is_equal(1)


func test_class_counts_are_zero_once_the_pool_is_stopped() -> void:
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_arc", &"warn_harm", &"blast_big", &"draft_pick"], 2)
	assert_int(_dir.pool.active_count()).is_greater(0)
	_dir.pool.stop_all()
	assert_int(_dir.pool.active_count()).is_equal(0)
	for cls: int in [AudioCatalog.CLASS_OTHER, AudioCatalog.CLASS_WEAPON, AudioCatalog.CLASS_BLAST, AudioCatalog.CLASS_ALERT, AudioCatalog.CLASS_UI]:
		assert_int(_dir.pool.count_of_class(cls)).is_equal(0)
	await VarietyGKit.settle(self, _dir)


func _pooled_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in VarietyGKit.WEAPON_IDS:
		if not VarietyGKit.LOOP_IDS.has(id):  # a held loop is no voice of the pool
			ids.append(id)
	return ids


func _weapons_and_blasts() -> Array[StringName]:
	var ids: Array[StringName] = _pooled_weapon_ids()
	ids.append_array(VarietyGKit.BLAST_IDS)
	return ids


func test_a_flood_of_every_weapon_sound_of_the_catalog_holds_at_most_8_voices() -> void:
	var weapons: Array[StringName] = _pooled_weapon_ids()
	assert_int(weapons.size()).is_equal(12)
	var started: int = VarietyGKit.flood(_dir, weapons, 10)
	assert_int(started).is_greater(8)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_WEAPON)).is_equal(8)
	assert_int(_dir.pool.active_count()).is_equal(8)
	await VarietyGKit.settle(self, _dir)


func test_every_alert_of_the_catalog_starts_after_a_flood_of_weapons_blasts_and_held_loops() -> void:
	@warning_ignore("return_value_discarded")
	_dir.try_hold(&"lmg_spin", 0)
	@warning_ignore("return_value_discarded")
	_dir.try_hold(&"torch_loop", 1)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, _pooled_weapon_ids(), 10)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, VarietyGKit.BLAST_IDS, 10)
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, [&"shot_pistol", &"shot_smg", &"shot_turret", &"hit_armor", &"death_heavy", &"spitter_shot", &"bolt_impact"], 6)
	assert_int(_dir.pool.active_count()).is_equal(AudioDirector.VOICES)  # the legacy sounds fill what the classes leave
	assert_int(_dir.held.sounding_count()).is_equal(2)
	for id: StringName in VarietyGKit.ALERT_IDS:
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message("%s was starved" % String(id)).is_true()
		assert_int(_dir.pool.count_of(id)).override_failure_message(String(id)).is_equal(1)
	assert_int(_dir.pool.active_count()).is_equal(AudioDirector.VOICES)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(AudioVoicePool.ALERT_RESERVED)
	await VarietyGKit.settle(self, _dir)


func test_the_last_three_voices_are_free_for_any_alert_while_weapons_and_blasts_flood() -> void:
	@warning_ignore("return_value_discarded")
	VarietyGKit.flood(_dir, _weapons_and_blasts(), 12)
	assert_int(_dir.pool.active_count()).is_less_equal(AudioDirector.VOICES - AudioVoicePool.ALERT_RESERVED)
	for id: StringName in VarietyGKit.ALERT_IDS.slice(0, 3):
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message(String(id)).is_true()
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(3)
	await VarietyGKit.settle(self, _dir)


func test_all_the_alerts_together_never_hold_more_than_three_voices() -> void:
	for id: StringName in VarietyGKit.ALERT_IDS:
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message(String(id)).is_true()
		assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_less_equal(AudioVoicePool.ALERT_RESERVED)
	assert_int(_dir.pool.count_of_class(AudioCatalog.CLASS_ALERT)).is_equal(3)  # the newest three, the older ones were taken
	await VarietyGKit.settle(self, _dir)
