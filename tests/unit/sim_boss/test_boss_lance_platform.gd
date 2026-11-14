extends GdUnitTestSuite
## V4-L: NODE 5 // LANCE PLATFORM (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.lance_platform.attack / .answer).
## Plants 14 m from the core. Cycle 9 s (540 ticks): a 3 s (180 tick) charge, then a beam for 120 (V5-C: was 160). +50% damage taken
## while charging; an EMP during the charge cancels the shot and stuns for 2 s; the Shield absorbs its part.
## Placed 13.5 m from the core between ticks, the platform plants on tick 1 (P = 1).

const TYPE: int = Ids.EN_LANCE_PLATFORM
const NEAR_X: float = 6.0  ## 13.5 m from the core


func _planted(w: SimWorld) -> int:
	var i: int = VarietyLKit.place(w, TYPE, NEAR_X, VarietyLKit.CORE_Z)
	VarietyLKit.tick(w)
	return i


func test_first_60_seconds_charge_at_p_plus_360_and_beam_for_120_at_p_plus_540_every_540_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _planted(w)
	assert_bool(w.boss.has_flag(BossState.F_PLANTED)).is_true()
	VarietyLKit.run_to(w, 3600)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_LANCE)).is_equal([361, 901, 1441, 1981, 2521, 3061])
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([541, 1081, 1621, 2161, 2701, 3241])
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH):
		assert_int(e.b).is_equal(180)
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT):
		assert_int(e.a).is_equal(w.enemies.id[i])
		assert_int(e.b).is_equal(TYPE)
		assert_float(e.f).is_equal(120.0)
		assert_float(e.f + e.g).is_less_equal(0.2 * w.core_max_hp)
	assert_float(w.core_hp).is_equal(1000.0 - 6.0 * 120.0)
	assert_int(w.boss.phase_count).is_equal(1)


func test_the_state_shows_the_charge_counting_down_and_the_vents_open() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _planted(w)
	VarietyLKit.run_to(w, 360)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	VarietyLKit.tick(w)  # 361
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_LANCE)
	assert_int(w.boss.telegraph_left).is_equal(180)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.5)
	VarietyLKit.run_to(w, 540)
	assert_int(w.boss.telegraph_left).is_equal(1)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.5)
	assert_float(w.core_hp).is_equal(1000.0)
	VarietyLKit.tick(w)  # 541: the beam
	assert_float(w.core_hp).is_equal(880.0)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)


func test_an_emp_during_the_charge_cancels_the_shot_and_stuns_for_2_seconds() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _planted(w)
	VarietyLKit.run_to(w, 399)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()
	assert_int(VarietyLKit.tick_with_ability(w, Ids.AB_EMP)).is_equal(Reason.Id.OK)  # tick 400
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	assert_int(w.enemies.stun_ticks[i]).is_equal(119)  # 2 s in all, this tick's one already counted
	assert_int(w.enemies.attack_cd[i]).is_equal(540)
	VarietyLKit.run_to(w, 518)
	assert_int(w.enemies.stun_ticks[i]).is_equal(1)
	VarietyLKit.tick(w)  # 519: free, the usual 5 s of immunity begin
	assert_int(w.enemies.stun_ticks[i]).is_equal(0)
	assert_int(w.enemies.stun_immune_ticks[i]).is_equal(300)
	VarietyLKit.run_to(w, 1100)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_LANCE)).is_equal([361, 878])
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([1058])  # no beam at 541: a whole cycle from the end of the stun


func test_an_emp_before_the_charge_only_delays_the_cycle_by_the_1_second_stun() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _planted(w)
	VarietyLKit.run_to(w, 99)
	VarietyLKit.tick_with_ability(w, Ids.AB_EMP)  # tick 100
	assert_int(w.enemies.stun_ticks[i]).is_equal(59)
	VarietyLKit.run_to(w, 700)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_LANCE)).is_equal([420])
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([600])


func test_an_immune_platform_is_not_interrupted() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _planted(w)
	VarietyLKit.run_to(w, 399)
	w.enemies.stun_immune_ticks[i] = 200  # as after an earlier stun
	w.abilities.cooldown_left[Ids.AB_EMP] = 0
	VarietyLKit.tick_with_ability(w, Ids.AB_EMP)
	assert_int(w.enemies.stun_ticks[i]).is_equal(0)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()
	VarietyLKit.run_to(w, 541)
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([541])


func test_the_shield_absorbs_its_part_of_the_beam() -> void:
	var w: SimWorld = VarietyLKit.world()
	_planted(w)
	VarietyLKit.run_to(w, 499)
	assert_int(VarietyLKit.tick_with_ability(w, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	var absorb: float = w.content.abilities[Ids.AB_SHIELD].absorb
	assert_float(absorb).is_equal(100.0)
	VarietyLKit.run_to(w, 541)
	var hits: Array[SimEvent] = VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0].g).is_equal(100.0)
	assert_float(hits[0].f).is_equal(20.0)
	assert_float(w.core_hp).is_equal(980.0)


func test_it_walks_to_14_m_plants_there_and_never_takes_a_slot() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place(w, TYPE, 8.5, VarietyLKit.CORE_Z)  # 16 m out
	var planted_at: int = -1
	for _n: int in 400:
		VarietyLKit.tick_move(w)
		if w.boss.has_flag(BossState.F_PLANTED):
			planted_at = w.tick
			break
		assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_int(planted_at).is_between(140, 170)  # 2 m at 0.8 m/s
	assert_float(VarietyLKit.dist_to_core(w, i)).is_between(13.9, 14.05)
	assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.enemies.slot[i]).is_equal(-1)
	var x: float = w.enemies.x[i]
	var z: float = w.enemies.z[i]
	VarietyLKit.run_move(w, 700)
	assert_float(w.enemies.x[i]).is_equal(x)
	assert_float(w.enemies.z[i]).is_equal(z)
	assert_int(w.enemies.slot[i]).is_equal(-1)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_STUCK).size()).is_equal(0)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_LANCE)).is_equal([planted_at + 360])
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([planted_at + 540])


func test_a_wave_modifier_on_attack_periods_keeps_the_3_second_charge() -> void:
	var w: SimWorld = VarietyLKit.world()
	w.mods.enemy_attack_period_mul = 0.5  # cycle 270 ticks
	_planted(w)
	VarietyLKit.run_to(w, 600)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_LANCE)).is_equal([91, 361])
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([271, 541])
