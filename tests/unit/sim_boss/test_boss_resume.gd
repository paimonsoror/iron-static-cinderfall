extends GdUnitTestSuite
## V4-L: everything a boss does is carried by the snapshot and the hash (VARIETY_SPEC 9.5): a world restored in the
## middle of a boss fight has the same state hash, and played on next to the original it stays equal, events included.

const AFTER_TICKS: int = 700


## Plays `scenario` to its capture point.
func _setup(scenario: String) -> SimWorld:
	var w: SimWorld = VarietyLKit.world(7)
	var i: int = -1
	match scenario:
		"brood":
			i = VarietyLKit.place(w, Ids.EN_BROOD_CARRIER)
			VarietyLKit.run_move(w, 100)
			VarietyLKit.set_hp_frac(w, i, 0.4)
			VarietyLKit.run_move(w, 150)  # molted, the hatches glow
		"lance":
			VarietyLKit.place(w, Ids.EN_LANCE_PLATFORM, 6.0, VarietyLKit.CORE_Z)
			VarietyLKit.run_move(w, 400)  # planted, charging
		"aegis":
			VarietyLKit.place(w, Ids.EN_AEGIS_ARRAY, 6.0, VarietyLKit.CORE_Z)
			VarietyLKit.run_move(w, 100)
			for j: int in VarietyLKit.living(w, Ids.EN_WARD_PYLON):
				w.kill_enemy(j, DamageSource.Id.WARDEN)
			VarietyLKit.run_move(w, 450)  # exposed, 150 ticks before the next deployment
		"tremor":
			i = VarietyLKit.place(w, Ids.EN_TREMOR_RIG)
			VarietyLKit.run_move(w, 450)
			VarietyLKit.set_hp_frac(w, i, 0.6)
			VarietyLKit.run_move(w, 80)  # the ring shows and two points are cracked
		"plated":
			i = VarietyLKit.place_hulk(w, BossSiegeHulk.PLATED, 9.5, VarietyLKit.CORE_Z)
			VarietyLKit.set_hp_frac(w, i, 0.5)
			VarietyLKit.run_move(w, 200)
		"fed":
			VarietyLKit.place_hulk(w, BossSiegeHulk.FED, 9.5, VarietyLKit.CORE_Z)
			VarietyLKit.run_move(w, 90)
			w.kill_enemy(VarietyLKit.living(w, Ids.EN_RECLAIMER)[0], DamageSource.Id.WARDEN)
			VarietyLKit.run_move(w, 40)
		"overclocked":
			VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED, 9.5, VarietyLKit.CORE_Z)
			VarietyLKit.run_move(w, 850)  # in the charge
	return w


## The same play on any world: whole ticks with movement, an EMP 60 ticks in, a Shield at 300.
func _play_on(w: SimWorld, ticks: int) -> void:
	var emp_at: int = w.tick + 60
	var shield_at: int = w.tick + 300
	for _n: int in ticks:
		if w.tick + 1 == emp_at:
			VarietyLKit.tick_with_ability(w, Ids.AB_EMP, true)
		elif w.tick + 1 == shield_at:
			VarietyLKit.tick_with_ability(w, Ids.AB_SHIELD, true)
		else:
			VarietyLKit.tick_move(w)


func _check(scenario: String) -> void:
	var w: SimWorld = _setup(scenario)
	assert_int(w.boss.boss_id).override_failure_message(scenario + ": no boss").is_not_equal(0)
	var back: SimWorld = VarietyLKit.resumed(w)
	assert_object(back).override_failure_message(scenario + ": restore failed").is_not_null()
	if back == null:
		return
	assert_str(back.state_hash()).override_failure_message(scenario + ": hash after restore").is_equal(w.state_hash())
	assert_array(Array(back.boss.timers)).is_equal(Array(w.boss.timers))
	var twin: SimWorld = _setup(scenario)
	_play_on(w, AFTER_TICKS)
	_play_on(back, AFTER_TICKS)
	_play_on(twin, AFTER_TICKS)
	assert_str(back.state_hash()).override_failure_message(scenario + ": the resumed fight drifted").is_equal(w.state_hash())
	assert_int(back.events.event_hash).override_failure_message(scenario + ": events drifted").is_equal(w.events.event_hash)
	assert_str(twin.state_hash()).override_failure_message(scenario + ": not deterministic").is_equal(w.state_hash())


func test_brood_carrier_resumes_with_the_same_hash() -> void:
	_check("brood")


func test_lance_platform_resumes_with_the_same_hash() -> void:
	_check("lance")


func test_aegis_array_resumes_with_the_same_hash() -> void:
	_check("aegis")


func test_tremor_rig_resumes_with_the_same_hash() -> void:
	_check("tremor")


func test_plated_hulk_resumes_with_the_same_hash() -> void:
	_check("plated")


func test_fed_hulk_resumes_with_the_same_hash() -> void:
	_check("fed")


func test_overclocked_hulk_resumes_with_the_same_hash() -> void:
	_check("overclocked")


func test_a_changed_script_integer_changes_the_world_hash() -> void:
	var w: SimWorld = _setup("tremor")
	var before: String = w.state_hash()
	w.boss.timers[BossTremorRig.T_BREACH] += 1
	assert_str(w.state_hash()).is_not_equal(before)
	w.boss.timers[BossTremorRig.T_BREACH] -= 1
	assert_str(w.state_hash()).is_equal(before)
	w.boss.flags ^= BossState.F_BRACED
	assert_str(w.state_hash()).is_not_equal(before)
