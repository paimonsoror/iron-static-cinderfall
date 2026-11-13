extends GdUnitTestSuite
## The mix of the 60 new sounds: the loudness of each voice class (file level plus the gain of its catalog row) stays in a
## band, the alerts stay above the weapons, and nothing that arrives by the dozen is loud. Levels are RMS in dBFS.

## Band of the effective level per class, in dB RMS (low, high). The frequent shots sit lowest, blasts and alerts highest.
const WEAPON_BAND: Vector2 = Vector2(-27.0, -15.0)
const HELD_BAND: Vector2 = Vector2(-31.0, -23.0)
const BLAST_BAND: Vector2 = Vector2(-21.0, -8.0)
const ALERT_BAND: Vector2 = Vector2(-18.0, -8.0)
const UI_BAND: Vector2 = Vector2(-24.0, -14.0)
const OTHER_BAND: Vector2 = Vector2(-30.0, -8.0)
const FREQUENT_MS: int = 100  ## a sound that may start this often is "frequent"
const FREQUENT_MAX_DB: float = -20.0
const ALERT_OVER_WEAPONS_DB: float = 1.0  ## the quietest alert is at least this much above the loudest weapon sound


func _in_band(id: StringName, band: Vector2) -> void:
	var level: float = VarietyGKit.effective_db(id)
	assert_float(level).override_failure_message("%s is %.1f dB RMS, band %.0f to %.0f" % [String(id), level, band.x, band.y]).is_between(band.x, band.y)


func test_the_weapon_sounds_sit_in_the_weapon_band_and_the_held_loops_under_them() -> void:
	for id: StringName in VarietyGKit.WEAPON_IDS:
		_in_band(id, HELD_BAND if VarietyGKit.LOOP_IDS.has(id) else WEAPON_BAND)


func test_blasts_alerts_and_the_interface_sit_in_their_bands() -> void:
	for id: StringName in VarietyGKit.BLAST_IDS:
		_in_band(id, BLAST_BAND)
	for id: StringName in VarietyGKit.ALERT_IDS:
		_in_band(id, ALERT_BAND)
	for id: StringName in VarietyGKit.UI_IDS:
		_in_band(id, UI_BAND)


func test_the_other_new_sounds_sit_in_the_general_band() -> void:
	for id: StringName in AudioCatalog.VARIETY_IDS:
		if AudioCatalog.voice_class(id) == AudioCatalog.CLASS_OTHER:
			_in_band(id, OTHER_BAND)


func test_every_alert_is_louder_than_every_weapon_sound() -> void:
	var quietest_alert: float = 0.0
	var alert_id: StringName = &""
	for id: StringName in VarietyGKit.ALERT_IDS:
		var level: float = VarietyGKit.effective_db(id)
		if alert_id == &"" or level < quietest_alert:
			quietest_alert = level
			alert_id = id
	var loudest_weapon: float = -99.0
	var weapon_id: StringName = &""
	for id: StringName in VarietyGKit.WEAPON_IDS:
		var level: float = VarietyGKit.effective_db(id)
		if level > loudest_weapon:
			loudest_weapon = level
			weapon_id = id
	assert_float(quietest_alert - loudest_weapon).override_failure_message(
		"%s (%.1f dB) is not %.0f dB above %s (%.1f dB)" % [String(alert_id), quietest_alert, ALERT_OVER_WEAPONS_DB, String(weapon_id), loudest_weapon]
	).is_greater_equal(ALERT_OVER_WEAPONS_DB)


func test_a_sound_that_can_start_every_tenth_of_a_second_is_never_loud() -> void:
	for id: StringName in AudioCatalog.VARIETY_IDS:
		if AudioCatalog.voice_class(id) == AudioCatalog.CLASS_BLAST or AudioCatalog.voice_class(id) == AudioCatalog.CLASS_ALERT:
			continue  # blasts are merged per frame and alerts are rare; the legacy blast_small is the slice's own mix
		if AudioCatalog.min_interval_ms(id) <= FREQUENT_MS:
			var level: float = VarietyGKit.effective_db(id)
			assert_float(level).override_failure_message("%s starts every %d ms and is %.1f dB" % [String(id), AudioCatalog.min_interval_ms(id), level]).is_less_equal(FREQUENT_MAX_DB)


func test_the_motor_and_the_flame_stay_under_the_rounds_they_accompany() -> void:
	assert_float(VarietyGKit.effective_db(&"lmg_spin")).is_less_equal(VarietyGKit.effective_db(&"shot_lmg") - 3.0)
	assert_float(VarietyGKit.effective_db(&"torch_loop")).is_less_equal(-23.0)


func test_no_row_asks_for_more_than_the_file_can_give() -> void:
	# files peak near -1 dBFS and the gain is never positive, so no sound can clip the bus on its own
	for id: StringName in AudioCatalog.VARIETY_IDS:
		assert_float(AudioCatalog.volume_db(id)).override_failure_message(String(id)).is_less_equal(0.0)
		var peak: float = AudioTestKit.peak(AudioTestKit.samples(AudioCatalog.load_sfx(id) as AudioStreamWAV))
		assert_float(20.0 * log(peak) / log(10.0) + AudioCatalog.volume_db(id)).override_failure_message(String(id)).is_less(-0.4)


func test_the_new_sounds_do_not_drown_the_legacy_ones() -> void:
	# the slice mix is the reference: the loudest legacy sound (the boss death) is not passed by more than 3 dB
	var ceiling: float = VarietyGKit.effective_db(&"death_boss") + 3.0
	for id: StringName in AudioCatalog.VARIETY_IDS:
		assert_float(VarietyGKit.effective_db(id)).override_failure_message(String(id)).is_less_equal(ceiling)
