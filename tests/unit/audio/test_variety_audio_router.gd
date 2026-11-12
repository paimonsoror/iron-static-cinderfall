extends GdUnitTestSuite
## AudioEventRouter and AudioVarietyRoutes: which new Events signal makes which sound (VARIETY_SPEC 13.4). A fake source
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


func test_the_arc_projector_has_its_own_shot_and_a_crackle_per_jump() -> void:
	_events.weapon_swapped.emit(1, &"arc_projector")
	assert_that(_last()).is_equal(&"weapon_swap")
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_arc")
	_events.chain_arc.emit(0, 5)
	assert_that(_last()).is_equal(&"arc_chain")
	_events.chain_arc.emit(5, 6)
	_events.chain_arc.emit(6, 7)
	_events.chain_arc.emit(7, 8)  # the fourth jump of one frame: the per-id cap of 3 starts
	assert_int(VarietyGKit.count_id(_dir, &"arc_chain")).is_equal(3)
	_events.shot_fired.emit(DamageSource.Id.TURRET_0, 1)
	assert_that(_last()).is_equal(&"shot_turret")  # a turret keeps its own sound whatever the Warden holds


func test_a_weapon_without_a_sound_yet_fires_the_pistol_shot_and_the_swap_follows_the_slot() -> void:
	_events.weapon_swapped.emit(1, &"scattergun")
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_pistol")
	assert_int(_dir.router.active_slot).is_equal(1)
	assert_that(_dir.router.weapon_id).is_equal(&"scattergun")
	_events.weapon_swapped.emit(0, &"smg")
	assert_int(_dir.router.active_slot).is_equal(0)
	assert_that(_dir.router.offhand_id).is_equal(&"scattergun")  # the weapon put away is the off-hand gun
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_smg")
	_events.shot_fired.emit(DamageSource.Id.WARDEN_OFFHAND, 1)
	assert_that(_last()).is_equal(&"shot_pistol")  # the off-hand scattergun has no sound of its own yet
	var before: int = _dir.started_total
	for source: int in [DamageSource.Id.CORE, DamageSource.Id.STRIKE, DamageSource.Id.HAZARD]:
		_events.shot_fired.emit(source, 1)  # these are no shots
	assert_int(_dir.started_total).is_equal(before)
	_events.run_started.emit("r", 1)
	assert_int(_dir.router.active_slot).is_equal(0)
	assert_that(_dir.router.offhand_id).is_equal(&"")
	await VarietyGKit.settle(self, _dir)


func test_a_strike_is_a_call_a_warning_and_an_impact() -> void:
	_events.event_warned.emit(&"deadfall_strike", 120, 1.0, 2.0)
	assert_that(_last()).is_equal(&"strike_call")
	_events.delayed_hit.emit(HazardState.K_STRIKE, 1.0, 2.0, 60)
	assert_that(_last()).is_equal(&"warn_harm")
	_events.area_blast.emit(HazardState.K_STRIKE, 1.0, 2.0, 4.0)
	assert_that(_last()).is_equal(&"strike_impact")  # at once, not at the end of the frame
	assert_array(_dir.recent_ids).is_equal([&"strike_call", &"warn_harm", &"strike_impact"])


func test_event_warnings_harmful_events_warn_and_the_others_wait_for_their_own_sound() -> void:
	for id: StringName in [&"static_front", &"floor_breach", &"recount", &"runaway_freight"]:
		_dir.gate.clear()
		_events.event_warned.emit(id, 240, 0.0, 0.0)
		assert_that(_last()).override_failure_message(String(id)).is_equal(&"warn_harm")
	var before: int = _dir.started_total
	for id: StringName in [&"supply_drop", &"accord_window", &"power_surge", &"no_such_event"]:
		_events.event_warned.emit(id, 240, 0.0, 0.0)  # helpful events get warn_help in V4-A; unknown ones are silent
	assert_int(_dir.started_total).is_equal(before)
	_events.delayed_hit.emit(HazardState.K_SHELL, 0.0, 0.0, 30)  # a mortar shell is the player's own round
	assert_int(_dir.started_total).is_equal(before)


func test_four_blasts_in_a_frame_become_one_big_blast_and_fewer_stay_small() -> void:
	for i: int in 6:
		_events.area_blast.emit(HazardState.K_BLAST, float(i), 0.0, 2.6)
	assert_int(_dir.started_total).is_equal(0)  # collected until the frame ends
	_dir.advance(0.0)
	assert_array(_dir.recent_ids).is_equal([&"blast_big"])
	_dir.gate.clear()
	for i: int in 3:
		_events.area_blast.emit(HazardState.K_BLAST, float(i), 0.0, 2.6)
	_dir.advance(0.0)
	assert_array(_dir.recent_ids).is_equal([&"blast_big", &"blast_small", &"blast_small", &"blast_small"])
	_dir.advance(0.0)  # nothing is left over for the next frame
	assert_int(_dir.started_total).is_equal(4)


func test_drums_and_vents_boom_at_once_and_other_blasts_wait_for_the_frame() -> void:
	_events.area_blast.emit(HazardState.K_DRUM, 0.0, 0.0, 3.0)
	assert_that(_last()).is_equal(&"blast_big")
	_events.area_blast.emit(HazardState.K_VENT, 0.0, 0.0, 6.0)
	assert_int(VarietyGKit.count_id(_dir, &"blast_big")).is_equal(2)
	_events.area_blast.emit(HazardState.K_SHELL, 0.0, 0.0, 2.0)
	assert_int(_dir.started_total).is_equal(2)
	_dir.advance(0.0)
	assert_that(_last()).is_equal(&"blast_small")


func test_blasts_waiting_for_the_frame_are_dropped_by_a_new_run() -> void:
	for i: int in 5:
		_events.area_blast.emit(HazardState.K_BLAST, 0.0, 0.0, 2.0)
	_events.run_started.emit("r", 1)
	_dir.advance(0.0)
	assert_int(_dir.started_total).is_equal(0)
	await VarietyGKit.settle(self, _dir)


func test_the_draft_opens_rerolls_picks_and_closes() -> void:
	var offer: Array[StringName] = [&"hot_loads", &"cyclic_tuning", &"glass_cannon"]
	var rerolled: Array[StringName] = [&"hot_loads", &"emp_capacitor", &"glass_cannon"]
	var empty: Array[StringName] = []
	_events.draft_offered.emit(offer)
	assert_that(_last()).is_equal(&"draft_open")
	_dir.gate.clear()
	_events.draft_offered.emit(rerolled)  # a reroll
	assert_that(_last()).is_equal(AudioVarietyRoutes.REROLL_SOUND)
	_events.directive_picked.emit(&"hot_loads", 1)
	assert_that(_last()).is_equal(&"draft_pick")
	_events.draft_offered.emit(empty)  # the next draft is an opening again
	assert_that(_last()).is_equal(&"draft_open")
	_events.await_changed.emit(RunApi.AWAIT_NONE)  # SKIP: the draft closed without a pick
	_dir.gate.clear()
	_events.draft_offered.emit(empty)
	assert_that(_last()).is_equal(&"draft_open")
	assert_array(_dir.recent_ids).is_equal([
		&"draft_open", AudioVarietyRoutes.REROLL_SOUND, &"draft_pick", &"draft_open", &"draft_open",
	])


func test_route_crate_and_await_sounds() -> void:
	_events.route_offered.emit()
	assert_that(_last()).is_equal(&"draft_open")
	_events.route_picked.emit(1)
	assert_that(_last()).is_equal(&"route_pick")
	_events.crate_secured.emit()
	assert_that(_last()).is_equal(&"crate_secured")
	_events.await_changed.emit(RunApi.AWAIT_DRAFT)  # opening an await is not a sound of its own
	assert_int(_dir.started_total).is_equal(3)


func test_a_mote_burning_out_on_the_cage_is_the_burn_sound_only() -> void:
	_events.core_hit.emit(1, &"mote", 6.0, 0.0)
	assert_array(_dir.recent_ids).is_equal([&"mote_burn"])
	_events.core_hit.emit(2, &"shard", 0.0, 8.0)
	assert_that(_last()).is_equal(&"mote_burn")
	_dir.gate.clear()
	_events.core_hit.emit(3, &"burster", 70.0, 0.0)
	assert_that(_last()).is_equal(&"core_hit_heavy")
	_events.core_hit.emit(4, &"spitter", 18.0, 0.0)
	assert_that(_last()).is_equal(&"core_hit_light")


func test_every_new_enemy_dies_with_a_catalog_sound_and_armored_ones_ring_dull() -> void:
	var id: int = 100
	for kind: StringName in Ids.ENEMIES:
		id += 1
		_dir.pool.stop_all()  # a full pool would drop the quiet hit sound, which is not what this test is about
		_dir.gate.clear()
		_events.enemy_spawned.emit(id, kind)
		_events.enemy_damaged.emit(id, 10.0, 0)
		var armored: bool = AudioEventRouter.ARMORED_KINDS.has(kind)
		assert_that(_last()).override_failure_message(String(kind)).is_equal(&"hit_armor" if armored else &"hit_ceramic")
		_dir.gate.clear()
		_events.enemy_killed.emit(id, 0)
		assert_that(_last()).override_failure_message(String(kind)).is_equal(AudioEventRouter.DEATH_SOUNDS[kind])
		_dir.gate.clear()
	assert_bool(AudioEventRouter.ARMORED_KINDS.has(&"burster")).is_false()  # CONTENT 4: armor 0
	assert_bool(AudioEventRouter.ARMORED_KINDS.has(&"shieldbearer")).is_true()


func test_the_burster_fuse_has_a_door_but_no_signal_yet() -> void:
	_dir.router.variety.on_burster_armed(7)
	assert_that(_last()).is_equal(&"burster_arm")
	# no Events signal says "a burster armed" (ENEMY_REACHED_SLOT is dropped by GameEventRelay): nothing may be wired for it
	for sig: StringName in _dir.router.signal_names():
		assert_str(String(sig)).is_not_equal("enemy_reached_slot")


func test_the_drone_follows_the_act_and_the_place_of_the_wave_in_it() -> void:
	_events.run_started.emit("r", 1)
	_events.act_started.emit(1)
	_events.wave_started.emit(1)
	assert_float(_dir.intensity()).is_equal_approx(0.20, 0.0001)
	_events.wave_started.emit(5)
	assert_float(_dir.intensity()).is_equal_approx(0.40, 0.0001)
	_events.act_started.emit(2)
	_events.wave_started.emit(6)
	assert_float(_dir.intensity()).is_equal_approx(0.45, 0.0001)
	_events.wave_started.emit(8)
	assert_float(_dir.intensity()).is_equal_approx(0.55, 0.0001)
	_events.act_started.emit(3)
	_events.wave_started.emit(15)
	assert_float(_dir.intensity()).is_equal_approx(0.90, 0.0001)
	_events.boss_spawned.emit(9, &"siege_hulk")
	assert_float(_dir.intensity()).is_equal(1.0)  # a boss still takes the drone to full
	_events.run_started.emit("r2", 2)  # a run without acts goes back to the wave number
	_events.wave_started.emit(3)
	assert_float(_dir.intensity()).is_equal_approx(0.6, 0.0001)
	assert_float(AudioVarietyRoutes.intensity_for_act(2, 3)).is_equal_approx(0.45, 0.0001)  # clamped into the act
	assert_float(AudioVarietyRoutes.intensity_for_act(9, 99)).is_equal_approx(0.90, 0.0001)
	await VarietyGKit.settle(self, _dir)


func test_the_intensity_never_drops_inside_an_act_and_rises_from_act_to_act() -> void:
	var previous: float = 0.0
	for wave: int in range(1, 16):
		var act: int = clampi(floori(float(wave - 1) / 5.0) + 1, 1, 3)
		var level: float = AudioVarietyRoutes.intensity_for_act(act, wave)
		assert_float(level).override_failure_message("wave %d" % wave).is_greater_equal(previous)
		assert_float(level).is_between(0.0, 1.0)
		previous = level


func test_a_held_weapon_loop_lives_as_long_as_the_shots_and_a_little_more() -> void:
	_dir.router.held_sounds[&"arc_projector"] = &"emp"  # any catalog sound can be held; V4-A fills the real table
	_events.weapon_swapped.emit(1, &"arc_projector")
	var swaps: int = _dir.started_total
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_bool(_dir.is_held(1)).is_true()
	assert_that(_dir.held_id(1)).is_equal(&"emp")
	assert_int(_dir.started_total).is_equal(swaps)  # a held shot starts no voice of the pool
	_dir.advance(0.1)
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	_dir.advance(0.1)
	assert_bool(_dir.is_held(1)).is_true()  # the second shot kept it alive
	_dir.advance(0.2)
	assert_bool(_dir.is_held(1)).is_false()  # 0.18 s without a shot: released (and fading)
	await VarietyGKit.settle(self, _dir)
	assert_int(_dir.held.sounding_count()).is_equal(0)


func test_a_swap_a_reload_and_the_end_of_a_run_release_the_held_loop() -> void:
	_dir.router.held_sounds[&"smg"] = &"emp"
	_events.weapon_changed.emit(&"smg")
	for ending: int in 3:
		_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
		assert_bool(_dir.is_held(0)).is_true()
		match ending:
			0:
				_events.weapon_swapped.emit(0, &"pistol")
			1:
				_events.weapon_changed.emit(&"pistol")
			2:
				_events.run_finished.emit(RunResult.Id.ABANDONED, "r")
		assert_bool(_dir.is_held(0)).override_failure_message("ending %d" % ending).is_false()
		_dir.advance(0.2)
		_events.weapon_changed.emit(&"smg")
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	_events.reload_started.emit(90)
	assert_bool(_dir.is_held(0)).is_false()
	await VarietyGKit.settle(self, _dir)
