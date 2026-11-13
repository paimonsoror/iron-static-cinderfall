extends GdUnitTestSuite
## V4-L: the FED and OVERCLOCKED variants of Node 9 (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.hulk_fed.* and
## boss.hulk_overclocked.*).
## FED: two reclaimers escort it and are re-sent every 20 s (1200 ticks); it heals 1% of its HP each second while one
## lives. OVERCLOCKED: every 12 s (720 ticks) a 1.5 s (90 tick) wind-up, then a 3 s (180 tick) charge at triple speed;
## an EMP during the charge stops it and stuns it for 2 s.

const TYPE: int = Ids.EN_HULK
const RECLAIMER: int = Ids.EN_RECLAIMER


func _kill(w: SimWorld, indices: Array[int]) -> void:
	for j: int in indices:
		w.kill_enemy(j, DamageSource.Id.WARDEN)


## True when DamageResolver.heal restores hit points in this checkout (it is another task's function).
func _heal_works() -> bool:
	var w: SimWorld = VarietyLKit.world()
	var probe: int = VarietyLKit.place(w, Ids.EN_HOLLOW)
	VarietyLKit.set_hp_frac(w, probe, 0.5)
	return DamageResolver.heal(w, probe, 1.0) > 0.0


func _walked(w: SimWorld, i: int, ticks: int) -> float:
	var from: Vector2 = Vector2(w.enemies.x[i], w.enemies.z[i])
	VarietyLKit.run_move(w, ticks)
	return Vector2(w.enemies.x[i], w.enemies.z[i]).distance_to(from)


func test_fed_first_60_seconds_two_reclaimers_enter_with_it_and_the_dead_are_sent_again_every_1200_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.FED)
	VarietyLKit.tick(w)
	var escorts: Array[int] = VarietyLKit.living(w, RECLAIMER)
	assert_int(escorts.size()).is_equal(2)
	# they enter where the hulk entered, one on each side
	assert_float(w.enemies.x[escorts[0]]).is_equal_approx(VarietyLKit.FAR_X, 0.001)
	assert_float(w.enemies.z[escorts[0]]).is_equal_approx(VarietyLKit.FAR_Z + 1.2, 0.001)
	assert_float(w.enemies.z[escorts[1]]).is_equal_approx(VarietyLKit.FAR_Z - 1.2, 0.001)
	VarietyLKit.run_to(w, 100)
	_kill(w, VarietyLKit.living(w, RECLAIMER))
	VarietyLKit.run_to(w, 1199)
	assert_int(VarietyLKit.living(w, RECLAIMER).size()).is_equal(0)  # not before the 20 s mark
	VarietyLKit.tick(w)  # 1200
	assert_int(VarietyLKit.living(w, RECLAIMER).size()).is_equal(2)
	VarietyLKit.run_to(w, 1300)
	_kill(w, [VarietyLKit.living(w, RECLAIMER)[0]])
	VarietyLKit.run_to(w, 2400)
	assert_int(VarietyLKit.living(w, RECLAIMER).size()).is_equal(2)  # only the dead one was sent again
	VarietyLKit.run_to(w, 3600)
	assert_array(VarietyLKit.spawn_ticks(w, RECLAIMER)).is_equal([1, 1200, 2400])
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_SPAWNED).size()).is_equal(1 + 2 + 2 + 1)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)
	assert_int(w.boss.boss_id).is_equal(w.enemies.id[i])


func test_fed_repairs_1_percent_of_its_maximum_once_a_second_while_a_reclaimer_lives() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.FED)
	var max_hp: float = w.enemies.max_hp[i]
	assert_float(BossSiegeHulk.heal_per_pulse(w, i)).is_equal_approx(max_hp * 0.01, 0.000001)
	VarietyLKit.set_hp_frac(w, i, 0.5)
	VarietyLKit.run_to(w, 59)
	assert_int(w.boss.timers[BossSiegeHulk.T_HEAL]).is_equal(59)
	VarietyLKit.tick(w)  # 60: the first pulse
	assert_int(w.boss.timers[BossSiegeHulk.T_HEAL]).is_equal(0)
	VarietyLKit.run_to(w, 600)
	if _heal_works():
		assert_float(w.enemies.hp[i]).is_equal_approx(max_hp * 0.6, 0.001)  # 10 pulses
		assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_HEALED).size()).is_equal(10)
	_kill(w, [VarietyLKit.living(w, RECLAIMER)[0]])
	VarietyLKit.run_to(w, 630)
	assert_int(w.boss.timers[BossSiegeHulk.T_HEAL]).is_equal(30)  # one reclaimer is enough
	var hp_before: float = w.enemies.hp[i]
	_kill(w, VarietyLKit.living(w, RECLAIMER))
	VarietyLKit.run_to(w, 1000)
	assert_int(w.boss.timers[BossSiegeHulk.T_HEAL]).is_equal(0)
	assert_float(w.enemies.hp[i]).is_equal(hp_before)  # nobody left to repair it


func test_fed_an_escort_that_finds_its_type_cap_full_is_owed_until_there_is_room() -> void:
	var w: SimWorld = VarietyLKit.world()
	var cap: int = w.content.enemies[RECLAIMER].alive_cap
	assert_int(cap).is_equal(4)
	var strangers: Array[int] = []
	for k: int in cap - 1:
		strangers.append(VarietyLKit.place(w, RECLAIMER, 0.0, 8.0 + float(k)))
	VarietyLKit.place_hulk(w, BossSiegeHulk.FED)
	VarietyLKit.run_to(w, 50)
	assert_int(VarietyLKit.living(w, RECLAIMER).size()).is_equal(cap)
	assert_int(w.boss.timers[BossSiegeHulk.T_ESCORT]).is_greater(0)
	assert_int(w.boss.timers[BossSiegeHulk.T_ESCORT + 1]).is_equal(BossSiegeHulk.OWED)
	_kill(w, [strangers[0]])
	VarietyLKit.tick(w)
	assert_int(w.boss.timers[BossSiegeHulk.T_ESCORT + 1]).is_greater(0)
	assert_int(VarietyLKit.living(w, RECLAIMER).size()).is_equal(cap)


func test_overclocked_first_60_seconds_a_wind_up_every_720_ticks_and_a_180_tick_charge_90_ticks_later() -> void:
	var w: SimWorld = VarietyLKit.world()
	VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED)
	var charging: Array[int] = []  # first and last tick of every charge
	var was: bool = false
	for _n: int in 3600:
		VarietyLKit.tick(w)
		var now: bool = w.boss.has_flag(BossState.F_CHARGING)
		if now != was:
			charging.append(w.tick)
			was = now
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_CHARGE)).is_equal([720, 1440, 2160, 2880, 3600])
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH):
		assert_int(e.b).is_equal(90)
	# the flag rises on the tick the wind-up ends and falls after the 180th tick of the charge
	assert_array(charging).is_equal([810, 990, 1530, 1710, 2250, 2430, 2970, 3150])
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_PHASE).size()).is_equal(0)


func test_overclocked_charges_at_three_times_its_speed() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED, 9.5, VarietyLKit.CORE_Z)
	VarietyLKit.run_move(w, 100)
	var plain: float = _walked(w, i, 60)
	assert_float(plain).is_equal_approx(0.65, 0.02)
	VarietyLKit.run_move(w, 810 - w.tick)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()
	assert_float(BossSiegeHulk.speed_mult(w)).is_equal(3.0)
	assert_float(_walked(w, i, 60) / plain).is_equal_approx(3.0, 0.1)
	assert_int(w.enemies.state[i]).is_not_equal(EnemyStore.ST_ATTACKING)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_STUCK).size()).is_equal(0)


func test_overclocked_an_emp_during_the_charge_stops_it_and_stuns_it_for_2_seconds() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED, 9.5, VarietyLKit.CORE_Z)
	VarietyLKit.run_move(w, 829)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()
	assert_int(VarietyLKit.tick_with_ability(w, Ids.AB_EMP, true)).is_equal(Reason.Id.OK)  # tick 830
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(w.boss.timers[BossSiegeHulk.T_CHARGE]).is_equal(0)
	assert_int(w.enemies.stun_ticks[i]).is_equal(119)
	var x: float = w.enemies.x[i]
	VarietyLKit.run_move(w, 118)
	assert_float(w.enemies.x[i]).is_equal(x)  # stunned: it stands
	assert_int(w.enemies.stun_ticks[i]).is_equal(1)
	VarietyLKit.tick_move(w)
	assert_int(w.enemies.stun_immune_ticks[i]).is_equal(300)
	assert_float(_walked(w, i, 60)).is_equal_approx(0.65, 0.03)  # and walks on at its own speed
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()


func test_overclocked_a_stun_during_the_wind_up_only_holds_it() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED)
	VarietyLKit.run_to(w, 749)
	assert_int(w.boss.telegraph_left).is_equal(61)
	VarietyLKit.tick_with_ability(w, Ids.AB_EMP)  # tick 750
	assert_int(w.enemies.stun_ticks[i]).is_equal(59)  # the plain 1 s boss stun
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_CHARGE)
	assert_int(w.boss.telegraph_left).is_equal(61)
	VarietyLKit.run_to(w, 868)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	VarietyLKit.tick(w)  # 869 = 810 + 59
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_true()


func test_overclocked_at_the_cage_there_is_nothing_left_to_charge() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED, VarietyLKit.CORE_X + 3.6, VarietyLKit.CORE_Z)
	w.enemies.state[i] = EnemyStore.ST_ATTACKING
	w.enemies.attack_cd[i] = 150
	VarietyLKit.run_to(w, 1600)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(VarietyLKit.core_hit_ticks(w).size()).is_equal(10)


func test_overclocked_a_charge_ends_when_the_hulk_takes_its_slot() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.OVERCLOCKED, 7.0, VarietyLKit.CORE_Z)  # 14.5 m out
	VarietyLKit.run_move(w, 1300)
	assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.enemies.slot[i]).is_greater_equal(0)
	assert_bool(w.boss.has_flag(BossState.F_CHARGING)).is_false()
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_CHARGE)).is_equal([720])
