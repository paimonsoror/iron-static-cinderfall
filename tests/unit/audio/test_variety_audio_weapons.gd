extends GdUnitTestSuite
## The ten weapons as sounds: a shot sound each, the two held loops (the LMG's motor under its rounds, the torch's flame),
## the vent, the missiles and the shells. A fake source node stands in for `Events`.

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


func test_every_weapon_of_the_roster_has_a_shot_or_a_held_loop() -> void:
	for weapon: StringName in Ids.WEAPONS:
		var has_shot: bool = AudioEventRouter.SHOT_SOUNDS.has(weapon)
		var has_loop: bool = AudioEventRouter.HELD_BY_WEAPON.has(weapon)
		assert_bool(has_shot or has_loop).override_failure_message("%s makes no sound" % String(weapon)).is_true()


func test_each_weapon_fires_its_own_shot_sound() -> void:
	var wanted: Dictionary[StringName, StringName] = {
		&"pistol": &"shot_pistol", &"smg": &"shot_smg", &"scattergun": &"shot_scattergun", &"assault_rifle": &"shot_rifle",
		&"hornet_rack": &"shot_hornet", &"lmg": &"shot_lmg", &"slag_mortar": &"shot_mortar", &"arc_projector": &"shot_arc",
		&"rail_lance": &"shot_rail",
	}
	for weapon: StringName in wanted:
		_events.weapon_swapped.emit(0, weapon)
		_dir.gate.clear()
		_dir.pool.stop_all()  # the swap and the earlier shots have sounded out; a full weapon class would drop the next one
		_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
		assert_that(_last()).override_failure_message(String(weapon)).is_equal(wanted[weapon])
	# the rail lance is a heavier gun than the pistol and sounds like it: its shot is not the pistol's
	assert_that(AudioEventRouter.SHOT_SOUNDS[&"rail_lance"]).is_not_equal(&"shot_pistol")
	await VarietyGKit.settle(self, _dir)


func test_the_lmg_runs_its_motor_under_its_rounds_and_the_loop_never_flutters_at_the_slowest_rate() -> void:
	_events.weapon_swapped.emit(1, &"lmg")
	_dir.gate.clear()
	var swaps: int = _dir.started_total
	for shot_no: int in 8:  # 4 rounds a second before the spin-up: one every 0.25 s
		_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
		assert_bool(_dir.is_held(1)).override_failure_message("round %d" % shot_no).is_true()
		assert_that(_dir.held_id(1)).is_equal(&"lmg_spin")
		_dir.gate.clear()
		_dir.pool.stop_all()  # 0.25 s later the 0.2 s round has sounded out (the test runs in no time)
		_dir.advance(0.25)
		assert_bool(_dir.is_held(1)).override_failure_message("after round %d" % shot_no).is_true()
	assert_int(_dir.started_total - swaps).is_equal(8)  # every round is a voice of the pool too
	assert_int(VarietyGKit.count_id(_dir, &"shot_lmg")).is_equal(8)
	_dir.advance(0.35)
	assert_bool(_dir.is_held(1)).is_false()  # the gun is silent: the motor winds down
	await VarietyGKit.settle(self, _dir)
	assert_int(_dir.held.sounding_count()).is_equal(0)


func test_the_torch_is_its_flame_alone() -> void:
	_events.weapon_swapped.emit(0, &"cutting_torch")
	_dir.gate.clear()
	var swaps: int = _dir.started_total
	for _hit: int in 20:  # a hit every 6 ticks
		_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
		_dir.advance(0.1)
	assert_that(_dir.held_id(0)).is_equal(&"torch_loop")
	assert_bool(_dir.is_held(0)).is_true()
	assert_int(_dir.started_total).is_equal(swaps)  # no voice of the pool: the flame is the whole sound
	_dir.advance(0.4)
	assert_bool(_dir.is_held(0)).is_false()
	await VarietyGKit.settle(self, _dir)


func test_the_off_hand_lmg_holds_the_other_slot() -> void:
	_events.weapon_swapped.emit(0, &"lmg")
	_events.weapon_swapped.emit(1, &"pistol")  # the LMG is put away: it is the off-hand gun now
	_events.shot_fired.emit(DamageSource.Id.WARDEN_OFFHAND, 1)
	assert_that(_dir.held_id(0)).is_equal(&"lmg_spin")
	assert_bool(_dir.is_held(1)).is_false()
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_pistol")
	await VarietyGKit.settle(self, _dir)


func test_a_vent_ends_the_flame_and_hisses() -> void:
	_events.weapon_swapped.emit(0, &"cutting_torch")
	_dir.gate.clear()
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_bool(_dir.is_held(0)).is_true()
	_events.weapon_vented.emit(0)
	assert_bool(_dir.is_held(0)).is_false()
	assert_that(_last()).is_equal(&"weapon_vent")
	await VarietyGKit.settle(self, _dir)


func test_missiles_pop_and_shells_land_with_a_blast() -> void:
	for i: int in 6:  # a salvo of six
		_events.area_blast.emit(HazardState.K_MISSILE, float(i), 0.0, 1.2)
	assert_int(VarietyGKit.count_id(_dir, &"hornet_pop")).is_equal(AudioVoiceGate.MAX_STARTS_PER_FRAME)  # the per-id cap
	_dir.gate.clear()
	_events.area_blast.emit(HazardState.K_SHELL, 1.0, 1.0, 2.6)
	assert_that(_last()).is_equal(&"mortar_blast")
	assert_int(AudioCatalog.voice_class(&"mortar_blast")).is_equal(AudioCatalog.CLASS_BLAST)
	assert_int(AudioCatalog.voice_class(&"hornet_pop")).is_equal(AudioCatalog.CLASS_WEAPON)


func test_the_rail_wind_up_plays_when_a_weapon_starts_charging() -> void:
	assert_bool(_dir.router.signal_names().has(&"weapon_charging")).is_true()  # wired by V5-A
	assert_bool(Events.has_signal(&"weapon_charging")).is_true()
	_dir.router.variety.on_weapon_charging(0)
	assert_that(_last()).is_equal(&"rail_charge")


func test_swapping_the_weapon_ends_a_held_loop_and_plays_the_swap() -> void:
	_events.weapon_swapped.emit(0, &"cutting_torch")
	_dir.gate.clear()
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_bool(_dir.is_held(0)).is_true()
	_dir.gate.clear()
	_events.weapon_swapped.emit(1, &"pistol")
	assert_bool(_dir.is_held(0)).is_false()
	assert_that(_last()).is_equal(&"weapon_swap")
	await VarietyGKit.settle(self, _dir)
