extends GdUnitTestSuite
## Warden fire cadence, magazine and reload (ARCH 6.5 "Fire cadence", GDD 5.1). Rate is an integer accumulator:
## each tick acc += sps_milli, a shot costs 60000, and with no shot allowed the accumulator clamps at 60000.
## Pistol 2000 -> a shot every 30 ticks. Hand-derived pistol timeline with an always-present target:
## shots at 30, 60 .. 360 (12 rounds), reload 75 ticks, next shot at 435 (clamped acc), then 464, 494 ...


func _world_with_target(type_index: int = Ids.EN_HULK) -> SimWorld:
	var w: SimWorld = CombatTestKit.world()
	var e: int = CombatTestKit.place(w, type_index, 10.0, 0.0)
	CombatTestKit.make_tough(w, e)
	return w


func test_pistol_shot_count_over_3600_ticks_matches_the_cadence_rule() -> void:
	var w: SimWorld = _world_with_target()
	CombatTestKit.run_warden(w, 3600)
	var expected: int = CombatTestKit.model_shots(2000, 12, 75, 3600)
	assert_int(expected).is_equal(108)  # nine full magazines, hand-derived
	assert_int(w.warden.shots_fired).is_equal(expected)
	assert_int(w.combat.shots_by_source[DamageSource.Id.WARDEN]).is_equal(expected)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(expected)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_equal(9)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_FINISHED)).is_equal(8)


func test_pistol_shot_ticks_follow_the_timeline() -> void:
	var w: SimWorld = _world_with_target()
	var ticks: PackedInt32Array = CombatTestKit.warden_shot_ticks(w, 900)
	assert_int(ticks[0]).is_equal(30)
	assert_int(ticks[1]).is_equal(60)
	assert_int(ticks[11]).is_equal(360)  # 12th round
	assert_int(ticks[12]).is_equal(435)  # 360 + 75 ticks of reload, first shot after a pause is immediate
	assert_int(ticks[13]).is_equal(464)  # leftover 2000 milli, so 29 ticks, not 30
	assert_int(ticks[14]).is_equal(494)
	assert_int(ticks[23]).is_equal(764)  # 24th round
	assert_int(ticks[24]).is_equal(839)


func test_magazine_of_12_then_a_75_tick_reload() -> void:
	var w: SimWorld = _world_with_target()
	CombatTestKit.run_warden(w, 360)
	assert_int(w.warden.shots_fired).is_equal(12)
	assert_int(w.warden.magazine).is_equal(0)
	assert_int(w.warden.reload_ticks_left).is_equal(75)
	var started: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)
	assert_int(started.size()).is_equal(1)
	assert_int(started[0].a).is_equal(75)
	assert_int(started[0].tick).is_equal(360)
	CombatTestKit.run_warden(w, 74)  # ticks 361..434: reloading, no shots
	assert_int(w.warden.shots_fired).is_equal(12)
	assert_int(w.warden.reload_ticks_left).is_equal(1)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_FINISHED)).is_equal(0)
	CombatTestKit.warden_tick(w)  # tick 435: reload ends, magazine full, the pent-up shot goes out
	var finished: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.RELOAD_FINISHED)
	assert_int(finished.size()).is_equal(1)
	assert_int(finished[0].tick).is_equal(435)
	assert_int(w.warden.reload_ticks_left).is_equal(0)
	assert_int(w.warden.shots_fired).is_equal(13)
	assert_int(w.warden.magazine).is_equal(11)


func test_smg_fires_6_per_second_30_rounds_then_a_96_tick_reload() -> void:
	var w: SimWorld = _world_with_target()
	w.warden.weapon_index = Ids.weapon_index(&"smg")
	w.warden.magazine = 30
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(6000)
	var ticks: PackedInt32Array = CombatTestKit.warden_shot_ticks(w, 600)
	assert_int(ticks[0]).is_equal(10)
	assert_int(ticks[1]).is_equal(20)
	assert_int(ticks[29]).is_equal(300)  # 30th round
	assert_int(ticks[30]).is_equal(396)  # 300 + 96
	assert_int(ticks[31]).is_equal(405)
	var started: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)
	assert_int(started[0].a).is_equal(96)
	assert_int(started[0].tick).is_equal(300)


func test_smg_shot_count_over_3600_ticks() -> void:
	var w: SimWorld = _world_with_target()
	w.warden.weapon_index = Ids.weapon_index(&"smg")
	w.warden.magazine = 30
	CombatTestKit.run_warden(w, 3600)
	var expected: int = CombatTestKit.model_shots(6000, 30, 96, 3600)
	assert_int(expected).is_equal(283)  # nine full magazines of 30 plus 13 rounds, hand-derived
	assert_int(w.warden.shots_fired).is_equal(expected)


func test_fire_rate_level_1_gives_2_3_shots_per_second_exactly() -> void:
	var w: SimWorld = _world_with_target()
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 1
	w.warden.magazine = 1000000  # isolate the rate from the magazine
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(2300)
	CombatTestKit.run_warden(w, 6000)
	assert_int(w.warden.shots_fired).is_equal(230)  # 6000 ticks x 2300 / 60000


func test_current_sps_milli_golden_values() -> void:
	var w: SimWorld = CombatTestKit.world()
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(2000)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 2
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(2600)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 5
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(3500)
	w.warden.weapon_index = Ids.weapon_index(&"smg")
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(10500)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 0
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(6000)


func test_overdrive_doubles_the_rate() -> void:
	var w: SimWorld = _world_with_target()
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 100000
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(4000)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 1
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(4600)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 0
	var ticks: PackedInt32Array = CombatTestKit.warden_shot_ticks(w, 200)
	assert_int(ticks[0]).is_equal(15)
	assert_int(ticks[1]).is_equal(30)
	assert_int(ticks[11]).is_equal(180)


func test_overdrive_still_reloads() -> void:
	var w: SimWorld = _world_with_target()
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 100000
	CombatTestKit.run_warden(w, 600)
	assert_int(w.warden.shots_fired).is_equal(CombatTestKit.model_shots(4000, 12, 75, 600))
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_greater_equal(2)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_FINISHED)).is_greater_equal(2)
	var started: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)
	assert_int(started[0].tick).is_equal(180)
	assert_int(started[0].a).is_equal(75)


func test_no_target_means_no_shots_and_the_accumulator_clamps_to_one_shot() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.run_warden(w, 200)
	assert_int(w.warden.shots_fired).is_equal(0)
	assert_int(w.warden.fire_acc_milli).is_equal(CombatTestKit.MILLI_PER_SHOT)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(0)


func test_the_first_shot_after_a_pause_is_immediate_but_never_a_burst() -> void:
	var w: SimWorld = CombatTestKit.world()
	w.warden.weapon_index = Ids.weapon_index(&"smg")
	w.warden.magazine = 30
	CombatTestKit.run_warden(w, 100)
	var e: int = CombatTestKit.place(w, Ids.EN_HULK, 10.0, 0.0)
	CombatTestKit.make_tough(w, e)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.shots_fired).is_equal(1)  # one shot at once, not 100 ticks' worth
	CombatTestKit.run_warden(w, 8)
	assert_int(w.warden.shots_fired).is_equal(1)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.shots_fired).is_equal(2)


func test_the_accumulator_also_clamps_during_a_reload() -> void:
	var w: SimWorld = _world_with_target()
	CombatTestKit.run_warden(w, 400)  # reload runs from 360 to 435
	assert_int(w.warden.reload_ticks_left).is_greater(0)
	assert_int(w.warden.fire_acc_milli).is_equal(CombatTestKit.MILLI_PER_SHOT)


func test_a_shot_uses_the_damage_level_the_weapon_damage_and_pushes_shot_fired() -> void:
	var w: SimWorld = CombatTestKit.world()
	var e: int = CombatTestKit.place(w, Ids.EN_SKITTER, 10.0, 0.0)
	w.upgrade_levels[Ids.UP_DAMAGE] = 2  # 30 x 1.4 = 42 against 0 armor
	w.warden.fire_acc_milli = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.warden_tick(w)
	assert_float(w.enemies.hp[e]).is_equal_approx(3.0, 0.000001)
	var shots: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.SHOT_FIRED)
	assert_int(shots.size()).is_equal(1)
	assert_int(shots[0].a).is_equal(DamageSource.Id.WARDEN)
	assert_int(shots[0].b).is_equal(w.enemies.id[e])
	assert_int(w.warden.magazine).is_equal(11)
	assert_float(w.warden.aim_x).is_equal(w.enemies.x[e])


func test_an_enemy_out_of_range_is_not_shot() -> void:
	var w: SimWorld = CombatTestKit.world()
	var e: int = CombatTestKit.place(w, Ids.EN_RUSHER, 0.0, 25.01, EnemyStore.ST_ATTACKING, 0.0)
	CombatTestKit.run_warden(w, 120)
	assert_int(w.warden.shots_fired).is_equal(0)
	assert_int(w.warden.target_id).is_equal(0)
	assert_float(w.enemies.hp[e]).is_equal(65.0)
