extends GdUnitTestSuite
## AudioThreatRoutes: the chaos events, the boss telegraphs, the elites, the wards and the borers as sounds. A fake source
## node stands in for `Events`.

var _events: AudioTestEvents
var _dir: AudioDirector


func before_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	_events = auto_free(AudioTestEvents.new())
	add_child(_events)
	_dir = AudioTestKit.make_routed(self, _events)


func after_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()


func _last() -> StringName:
	return _dir.recent_ids.back() if not _dir.recent_ids.is_empty() else &""


func _boss(kind: StringName) -> void:
	_events.boss_spawned.emit(9, kind)
	_dir.gate.clear()


func test_each_chaos_event_has_its_own_start_sound_and_the_surge_ends_in_a_brownout() -> void:
	var starts: Dictionary[StringName, StringName] = {
		&"static_front": &"static_front", &"power_surge": &"surge_up", &"floor_breach": &"breach_crack",
		&"accord_window": &"relay_window", &"runaway_freight": &"freight_pass",
	}
	for event: StringName in starts:
		_dir.gate.clear()
		_events.event_started.emit(event)
		assert_that(_last()).override_failure_message(String(event)).is_equal(starts[event])
	_dir.gate.clear()
	_events.event_ended.emit(&"power_surge")
	assert_that(_last()).is_equal(&"brownout")
	var before: int = _dir.started_total
	for event: StringName in [&"deadfall_strike", &"core_vent", &"recount", &"supply_drop", &"no_such_event"]:
		_events.event_started.emit(event)  # nothing of their own: the strike and the vent have their blasts, the crate lands
	for event: StringName in [&"static_front", &"accord_window", &"runaway_freight", &"floor_breach"]:
		_events.event_ended.emit(event)
	assert_int(_dir.started_total).is_equal(before)


func test_the_warnings_that_have_a_rhythm_of_their_own() -> void:
	var warn: Dictionary[StringName, StringName] = {
		&"deadfall_strike": &"strike_call", &"runaway_freight": &"freight_horn", &"freight_call": &"freight_horn",
		&"recount": &"recount_tick", &"static_front": &"warn_harm", &"floor_breach": &"warn_harm",
		&"supply_drop": &"warn_help", &"accord_window": &"warn_help", &"power_surge": &"warn_help",
	}
	for event: StringName in warn:
		_dir.gate.clear()
		_events.event_warned.emit(event, 180, 0.0, 0.0)
		assert_that(_last()).override_failure_message(String(event)).is_equal(warn[event])
		assert_int(AudioCatalog.voice_class(_last())).override_failure_message(String(event)).is_equal(AudioCatalog.CLASS_ALERT)
	# five different warning sounds for ten events: the rhythm tells them apart
	var distinct: Dictionary[StringName, bool] = {}
	for sound: StringName in warn.values():
		distinct[sound] = true
	assert_int(distinct.size()).is_equal(5)


func test_a_boss_telegraph_sounds_like_its_boss() -> void:
	var wanted: Dictionary[StringName, StringName] = {
		&"brood_carrier": &"brood_hatch", &"lance_platform": &"lance_charge", &"siege_hulk": &"hulk_charge",
		&"aegis_array": &"warn_harm", &"tremor_rig": &"warn_harm",
	}
	for kind: StringName in wanted:
		_events.run_started.emit("r", 1)
		_boss(kind)
		_events.boss_telegraph.emit(0, 90)
		assert_that(_last()).override_failure_message(String(kind)).is_equal(wanted[kind])
		assert_int(AudioCatalog.voice_class(_last())).is_equal(AudioCatalog.CLASS_ALERT)
	_events.run_started.emit("r", 2)  # no boss alive: a telegraph is still a warning
	_dir.gate.clear()
	_events.boss_telegraph.emit(0, 90)
	assert_that(_last()).is_equal(&"warn_harm")
	await VarietyGKit.settle(self, _dir)


func test_the_tremor_stomp_lands_when_the_telegraph_ends_and_waits_with_the_pause() -> void:
	_boss(&"tremor_rig")
	_events.boss_telegraph.emit(0, 90)  # 1.5 s
	assert_that(_last()).is_equal(&"warn_harm")
	assert_int(_dir.router.variety.threat.pending()).is_equal(1)
	_dir.advance(1.4)
	assert_int(VarietyGKit.count_id(_dir, &"tremor_stomp")).is_equal(0)
	_dir.pause_all()
	_dir.advance(5.0)  # a paused game does not advance the audio clock
	_dir.resume_all()
	assert_int(_dir.router.variety.threat.pending()).is_equal(1)
	_dir.advance(0.2)
	assert_that(_last()).is_equal(&"tremor_stomp")
	assert_int(_dir.router.variety.threat.pending()).is_equal(0)
	_dir.advance(5.0)
	assert_int(VarietyGKit.count_id(_dir, &"tremor_stomp")).is_equal(1)  # once
	await VarietyGKit.settle(self, _dir)


func test_a_new_run_forgets_a_stomp_that_was_still_to_come() -> void:
	_boss(&"tremor_rig")
	_events.boss_telegraph.emit(0, 600)
	assert_int(_dir.router.variety.threat.pending()).is_equal(1)
	_events.run_started.emit("r", 3)
	assert_int(_dir.router.variety.threat.pending()).is_equal(0)
	assert_that(_dir.router.variety.threat.boss_kind).is_equal(&"")
	_dir.advance(20.0)
	assert_int(VarietyGKit.count_id(_dir, &"tremor_stomp")).is_equal(0)
	await VarietyGKit.settle(self, _dir)


func test_the_lance_beam_is_heard_when_it_hits_the_core_and_not_when_the_charge_was_cancelled() -> void:
	_boss(&"lance_platform")
	_events.boss_telegraph.emit(0, 180)  # the 3 s charge
	assert_that(_last()).is_equal(&"lance_charge")
	var before: int = _dir.started_total
	_dir.advance(4.0)  # an EMP cancelled the shot: no core hit arrives and nothing else plays
	assert_int(_dir.started_total).is_equal(before)
	_dir.gate.clear()
	_events.core_hit.emit(9, &"lance_platform", 160.0, 0.0)
	assert_array(_dir.recent_ids.slice(-2)).contains_exactly([&"lance_fire", &"core_hit_heavy"])
	await VarietyGKit.settle(self, _dir)


func test_every_boss_blow_on_the_core_is_a_stomp_except_the_lance() -> void:
	for kind: StringName in [&"siege_hulk", &"brood_carrier", &"aegis_array", &"tremor_rig"]:
		_dir.gate.clear()
		_events.core_hit.emit(9, kind, 70.0, 0.0)
		assert_int(VarietyGKit.count_id(_dir, &"boss_stomp")).override_failure_message(String(kind)).is_greater(0)
		_dir.recent_ids.clear()
	_dir.gate.clear()
	_events.core_hit.emit(9, &"lance_platform", 160.0, 0.0)
	assert_int(VarietyGKit.count_id(_dir, &"boss_stomp")).is_equal(0)


func test_a_boss_phase_is_a_hit_and_the_start_of_the_fight_is_not() -> void:
	_events.boss_phase.emit(0)
	assert_int(_dir.started_total).is_equal(0)
	_events.boss_phase.emit(1)
	assert_that(_last()).is_equal(&"boss_phase")
	assert_int(AudioCatalog.voice_class(&"boss_phase")).is_equal(AudioCatalog.CLASS_OTHER)


func test_the_aegis_array_opens_when_the_last_pylon_falls() -> void:
	_boss(&"aegis_array")
	for id: int in [21, 22, 23]:
		_events.enemy_spawned.emit(id, &"ward_pylon")
	_events.enemy_killed.emit(21, 0)
	_events.enemy_killed.emit(22, 0)
	assert_int(VarietyGKit.count_id(_dir, &"aegis_exposed")).is_equal(0)
	_events.enemy_killed.emit(23, 0)
	assert_int(VarietyGKit.count_id(_dir, &"aegis_exposed")).is_equal(1)
	assert_array(_dir.recent_ids.slice(-2)).contains_exactly([&"aegis_exposed", &"death_heavy"])
	# the array redeploys two pylons and opens again
	_dir.gate.clear()
	for id: int in [31, 32]:
		_events.enemy_spawned.emit(id, &"ward_pylon")
	_events.enemy_killed.emit(31, 0)
	_events.enemy_killed.emit(32, 0)
	assert_int(VarietyGKit.count_id(_dir, &"aegis_exposed")).is_equal(2)


func test_pylons_that_die_with_their_boss_or_without_one_open_nothing() -> void:
	_boss(&"aegis_array")
	for id: int in [21, 22]:
		_events.enemy_spawned.emit(id, &"ward_pylon")
	_events.enemy_killed.emit(9, 0)  # the boss dies first (its kind was learned from boss_spawned)
	_events.enemy_killed.emit(21, 0)
	_events.enemy_killed.emit(22, 0)
	assert_int(VarietyGKit.count_id(_dir, &"aegis_exposed")).is_equal(0)
	_events.enemy_spawned.emit(41, &"ward_pylon")  # no Aegis Array alive
	_events.enemy_killed.emit(41, 0)
	assert_int(VarietyGKit.count_id(_dir, &"aegis_exposed")).is_equal(0)


func test_a_ward_hums_when_it_comes_up_and_breaks_once_when_it_goes_down() -> void:
	_events.ward_changed.emit(5, 1.0)
	assert_that(_last()).is_equal(&"ward_hum")
	var after_hum: int = _dir.started_total
	_events.ward_changed.emit(5, 0.6)  # draining is silent
	_events.ward_changed.emit(5, 0.2)
	assert_int(_dir.started_total).is_equal(after_hum)
	_events.ward_changed.emit(5, 0.0)
	assert_that(_last()).is_equal(&"ward_break")
	var after_break: int = _dir.started_total
	_events.ward_changed.emit(5, 0.0)  # WARD_BROKEN and WARD_CHANGED both report the empty ward
	assert_int(_dir.started_total).is_equal(after_break)
	_dir.gate.clear()
	_events.ward_changed.emit(5, 1.0)  # it regenerates
	assert_that(_last()).is_equal(&"ward_hum")
	_events.enemy_spawned.emit(5, &"shieldbearer")
	_events.enemy_killed.emit(5, 0)  # the store reuses ids: a new enemy 5 starts without a ward
	_dir.gate.clear()
	_events.ward_changed.emit(5, 0.7)
	assert_int(VarietyGKit.count_id(_dir, &"ward_hum")).is_equal(3)


func test_an_elite_a_borer_a_split_and_a_jammer_each_announce_themselves() -> void:
	_events.elite_spawned.emit(3, &"hollow_warden", 5)
	assert_that(_last()).is_equal(&"elite_spawn")
	_events.enemy_spawned.emit(4, &"borer")
	assert_that(_last()).is_equal(&"borer_emerge")
	var before: int = _dir.started_total
	_events.enemy_spawned.emit(5, &"skitter")  # a spawn is silent
	assert_int(_dir.started_total).is_equal(before)
	_events.enemy_spawned.emit(6, &"splitter")
	_events.enemy_killed.emit(6, 0)
	assert_that(_last()).is_equal(&"splitter_split")
	_events.enemy_spawned.emit(7, &"jammer")
	_events.enemy_killed.emit(7, 0)
	assert_that(_last()).is_equal(&"jammer_pop")


func test_a_spitter_spits_with_the_bolt_and_the_bolt_strikes_the_cage() -> void:
	_events.delayed_hit.emit(HazardState.K_BOLT, 0.0, 0.0, 48)
	assert_that(_last()).is_equal(&"spitter_shot")
	_dir.gate.clear()
	_events.core_hit.emit(4, &"spitter", 18.0, 0.0)
	assert_int(VarietyGKit.count_id(_dir, &"bolt_impact")).is_equal(1)
	assert_int(VarietyGKit.count_id(_dir, &"core_hit_light")).is_equal(1)


func test_the_threat_routes_know_every_signal_they_wire_and_no_more() -> void:
	var names: Array[String] = []
	for sig: StringName in _dir.router.variety.threat.wiring():
		names.append(String(sig))
		assert_bool(_dir.router.signal_names().has(sig)).override_failure_message(String(sig)).is_true()
	names.sort()
	assert_array(names).is_equal([
		"boss_phase", "boss_telegraph", "elite_spawned", "event_ended", "event_started", "event_warned", "ward_changed",
	])
