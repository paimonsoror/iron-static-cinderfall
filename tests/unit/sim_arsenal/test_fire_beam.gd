extends GdUnitTestSuite
## V4-W: the cutting torch (firing kind B, VARIETY_SPEC 3.3). One hit every 6 ticks (10 a second); the damage starts at 12
## and gains 1.2 per hit in a row on one target, up to 28 (34 at level 3), before the level multiplier; armor is ignored
## (V5-C numbers: was 4, 0.5, 16 and 22). Heat: 2 a hit, a cap of 100, a vent of 120 ticks at the cap (the 50th hit, on
## tick 300), cooling 25 a second while it holds no target. A new target, a vent, a swap and a pause with no target
## restart the ramp. Siege Hulk: armor 12.


func _torch(level: int = 1) -> SimWorld:
	return ArsenalWKit.world(Ids.WP_CUTTING_TORCH, level)


func _ramp(k: int, cap: float = 28.0) -> float:
	return minf(cap, 12.0 + 1.2 * float(k))


func test_the_damage_ramps_1_2_a_hit_to_28_and_armor_is_ignored() -> void:
	var w: SimWorld = _torch()
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 204)
	assert_int(ticks.size()).is_equal(34)
	assert_int(ticks[0]).is_equal(6)
	assert_int(ticks[33]).is_equal(204)
	var dealt: Array[float] = ArsenalWKit.dealt(w)
	assert_int(dealt.size()).is_equal(34)
	for k: int in 34:
		assert_float(dealt[k]).is_equal_approx(_ramp(k), 1e-5)
	assert_float(dealt[0]).is_equal(12.0)  # armor 12 did not take a point of it
	assert_float(dealt[24]).is_equal(28.0)
	assert_float(dealt[33]).is_equal(28.0)


func test_heat_two_a_hit_a_vent_of_120_ticks_and_a_fresh_ramp_after_it() -> void:
	var w: SimWorld = _torch()
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(w, 6)
	assert_int(w.arsenal.slot_heat[0]).is_equal(2)
	ArsenalWKit.run_both(w, 294)  # tick 300
	assert_int(w.arsenal.slot_heat[0]).is_equal(100)
	assert_int(w.arsenal.slot_vent_left[0]).is_equal(120)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_VENTING)
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.WEAPON_VENTED)).is_equal([300])
	assert_int(w.arsenal.beam_hits).is_equal(0)  # the vent broke the ramp at once
	ArsenalWKit.run_both(w, 119)  # tick 419: silent
	assert_int(w.warden.shots_fired).is_equal(50)
	ArsenalWKit.run_both(w, 1)  # tick 420: the first hit of the new ramp
	assert_int(w.warden.shots_fired).is_equal(51)
	assert_float(ArsenalWKit.dealt(w)[50]).is_equal(12.0)
	assert_int(w.arsenal.slot_heat[0]).is_equal(2)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_equal(0)  # a heat weapon never reloads
	assert_int(ArsenalSystem.magazine_size_of(w, 0)).is_equal(0)


func test_a_new_target_starts_the_ramp_over() -> void:
	var w: SimWorld = _torch()
	var first: int = ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_HULK, 12.0, 0.0)
	ArsenalWKit.run_both(w, 60)  # ten hits on the first
	assert_int(w.warden.shots_fired).is_equal(10)
	assert_float(ArsenalWKit.dealt(w)[9]).is_equal_approx(22.8, 1e-5)
	w.kill_enemy(first, DamageSource.Id.WARDEN)
	ArsenalWKit.run_both(w, 6)  # the next hit is on the other one
	var dealt: Array[float] = ArsenalWKit.dealt(w)
	assert_int(dealt.size()).is_equal(11)
	assert_float(dealt[10]).is_equal(12.0)
	ArsenalWKit.run_both(w, 6)
	assert_float(ArsenalWKit.dealt(w)[11]).is_equal_approx(13.2, 1e-5)


func test_an_idle_torch_cools_25_heat_a_second_and_the_ramp_is_lost() -> void:
	var w: SimWorld = _torch()
	var target: int = ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0)
	ArsenalWKit.run_both(w, 90)  # fifteen hits of 2 heat
	assert_int(w.arsenal.slot_heat[0]).is_equal(30)
	w.kill_enemy(target, DamageSource.Id.WARDEN)
	ArsenalWKit.run_both(w, 60)
	assert_int(w.arsenal.slot_heat[0]).is_equal(5)
	assert_int(w.arsenal.beam_hits).is_equal(0)
	assert_int(w.arsenal.beam_target).is_equal(0)


func test_a_swap_breaks_the_ramp() -> void:
	var w: SimWorld = _torch()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_PISTOL)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(w, 30)
	assert_int(w.arsenal.beam_hits).is_equal(5)
	assert_int(VarietyCKit.swap_on_next_tick(w, 1)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.beam_hits).is_equal(0)


func test_levels_scale_the_hit_and_level_three_lifts_the_ramp_cap_to_34() -> void:
	var two: SimWorld = _torch(2)
	ArsenalWKit.foe(two, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(two, 6)
	assert_float(ArsenalWKit.dealt(two)[0]).is_equal_approx(15.0, 1e-5)  # 12 x 1.25
	var three: SimWorld = _torch(3)
	three.mods.w_heat_cap_mul = 1.5  # extended_feed: 150 heat, 75 hits before the vent
	ArsenalWKit.foe(three, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(three, 6 * 41)
	var dealt: Array[float] = ArsenalWKit.dealt(three)
	assert_int(dealt.size()).is_equal(41)
	for k: int in 41:
		assert_float(dealt[k]).is_equal_approx(_ramp(k, 34.0) * 1.55, 1e-3)
	assert_float(dealt[18]).is_equal_approx(33.6 * 1.55, 1e-3)  # still climbing
	assert_float(dealt[19]).is_equal_approx(34.0 * 1.55, 1e-3)  # the cap: 12 + 1.2 x 19 = 34.8
	assert_float(dealt[40]).is_equal_approx(34.0 * 1.55, 1e-3)
