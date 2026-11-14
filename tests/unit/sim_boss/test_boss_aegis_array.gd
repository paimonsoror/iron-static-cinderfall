extends GdUnitTestSuite
## V4-L: NODE 6 // AEGIS ARRAY (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.aegis_array.attack / .answer).
## Pylons orbit it at 2.2 m and cut its damage taken to a fifth. With all down it is exposed for 10 s (600 ticks), then
## redeploys fewer: 3, 2, 1, then none. The EMP drops all pylon protection for 3 s (180 ticks).

const TYPE: int = Ids.EN_AEGIS_ARRAY
const PYLON: int = Ids.EN_WARD_PYLON
const AT_X: float = 6.0  ## the ring stays inside the yard here
const AT_Z: float = 3.0


func _array(w: SimWorld) -> int:
	return VarietyLKit.place(w, TYPE, AT_X, AT_Z)


func _kill_pylons(w: SimWorld, count: int = 99) -> void:
	var left: int = count
	for j: int in VarietyLKit.living(w, PYLON):
		if left <= 0:
			return
		w.kill_enemy(j, DamageSource.Id.WARDEN)
		left -= 1


func test_first_60_seconds_deployments_of_3_2_1_with_a_600_tick_window_after_each() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	assert_int(w.boss.phase_count).is_equal(4)
	VarietyLKit.run_to(w, 100)
	assert_int(w.boss.parts_alive).is_equal(3)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	_kill_pylons(w)
	VarietyLKit.tick(w)  # 101: the window opens
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_true()
	assert_int(w.boss.exposed_left).is_equal(600)
	assert_int(w.boss.parts_alive).is_equal(0)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	VarietyLKit.run_to(w, 700)
	assert_int(w.boss.exposed_left).is_equal(1)
	assert_int(VarietyLKit.living(w, PYLON).size()).is_equal(0)
	VarietyLKit.tick(w)  # 701: two pylons
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_false()
	assert_int(w.boss.parts_alive).is_equal(2)
	assert_int(w.boss.phase).is_equal(1)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	VarietyLKit.run_to(w, 800)
	_kill_pylons(w)
	VarietyLKit.run_to(w, 1401)  # window 801..1400, one pylon at 1401
	assert_int(w.boss.parts_alive).is_equal(1)
	assert_int(w.boss.phase).is_equal(2)
	VarietyLKit.run_to(w, 1500)
	_kill_pylons(w)
	VarietyLKit.tick(w)  # 1501: nothing left to deploy
	assert_int(w.boss.phase).is_equal(3)
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_true()
	assert_int(w.boss.exposed_left).is_equal(0)
	VarietyLKit.run_to(w, 3600)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	assert_array(VarietyLKit.spawn_ticks(w, PYLON)).is_equal([1, 701, 1401])
	assert_int(w.stats.kills_by_type[PYLON]).is_equal(6)
	# no telegraph event: the audio hears the window in the last pylon's death, the HUD reads exposed_left
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)])
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT).size()).is_equal(0)  # parked pylons never hit


func test_the_pylons_are_parked_bodies_evenly_spaced_on_a_turning_ring_of_2_2_m() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.tick(w)
	var pylons: Array[int] = VarietyLKit.living(w, PYLON)
	assert_int(pylons.size()).is_equal(3)
	var first_angle: float = 0.0
	for tick_count: int in [1, 90]:
		VarietyLKit.run_to(w, tick_count)
		var angles: Array[float] = []
		for j: int in pylons:
			var off: Vector2 = Vector2(w.enemies.x[j] - w.enemies.x[i], w.enemies.z[j] - w.enemies.z[i])
			assert_float(off.length()).is_equal_approx(2.2, 0.0001)
			angles.append(off.angle())
			assert_int(w.enemies.state[j]).is_equal(EnemyStore.ST_ATTACKING)
			assert_int(w.enemies.slot[j]).is_equal(-1)
			assert_float(w.enemies.hp[j]).is_equal(300.0)
		assert_float(wrapf(angles[1] - angles[0], 0.0, TAU)).is_equal_approx(TAU / 3.0, 0.0001)
		assert_float(wrapf(angles[2] - angles[1], 0.0, TAU)).is_equal_approx(TAU / 3.0, 0.0001)
		if tick_count == 1:
			first_angle = angles[0]
		else:
			# one turn per 6 s: 89 ticks later the ring has turned 89 / 360 of a circle
			assert_float(wrapf(angles[0] - first_angle, 0.0, TAU)).is_equal_approx(TAU * 89.0 / 360.0, 0.0001)


func test_one_living_pylon_is_enough_protection() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.run_to(w, 10)
	_kill_pylons(w, 2)
	VarietyLKit.run_to(w, 700)
	assert_int(w.boss.parts_alive).is_equal(1)
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_false()
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	assert_bool(BossAegisArray.is_protected(w)).is_true()
	assert_int(VarietyLKit.living(w, PYLON).size()).is_equal(1)  # a fallen pylon is not replaced inside a deployment


func test_the_emp_drops_the_protection_for_180_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.run_to(w, 49)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	VarietyLKit.tick_with_ability(w, Ids.AB_EMP)  # tick 50
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	assert_int(w.boss.parts_alive).is_equal(3)
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_false()
	VarietyLKit.run_to(w, 229)  # hits of ticks 51..230 meet no protection
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	VarietyLKit.tick(w)  # 230
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)


func test_another_ability_does_not_drop_the_protection() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.run_to(w, 49)
	VarietyLKit.tick_with_ability(w, Ids.AB_SHIELD)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)


func test_the_pylons_follow_the_walking_boss() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	var start_x: float = w.enemies.x[i]
	VarietyLKit.run_move(w, 300)
	assert_float(w.enemies.x[i]).is_less(start_x - 2.0)  # 5 s at 0.6 m/s
	for j: int in VarietyLKit.living(w, PYLON):
		var off: Vector2 = Vector2(w.enemies.x[j] - w.enemies.x[i], w.enemies.z[j] - w.enemies.z[i])
		assert_float(off.length()).is_equal_approx(2.2, 0.0001)
	assert_int(VarietyLKit.living(w, PYLON).size()).is_equal(3)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_STUCK).size()).is_equal(0)


func test_a_pylon_that_finds_its_type_cap_full_is_owed_and_sent_later() -> void:
	var w: SimWorld = VarietyLKit.world()
	assert_int(w.content.enemies[PYLON].alive_cap).is_equal(3)
	var strangers: Array[int] = [VarietyLKit.place(w, PYLON, 0.0, 8.0), VarietyLKit.place(w, PYLON, 0.0, 9.0)]
	var i: int = _array(w)
	VarietyLKit.run_to(w, 20)
	assert_int(w.boss.parts_alive).is_equal(1)
	assert_int(w.boss.timers[BossAegisArray.T_PENDING]).is_equal(2)
	assert_bool(w.boss.has_flag(BossState.F_EXPOSED)).is_false()
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(0.2)
	for j: int in strangers:
		w.kill_enemy(j, DeathHooks.SOURCE_SELF)
	VarietyLKit.tick(w)
	assert_int(w.boss.parts_alive).is_equal(3)
	assert_int(w.boss.timers[BossAegisArray.T_PENDING]).is_equal(0)


func test_the_pylons_die_with_the_boss_and_the_state_returns_to_neutral() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.run_to(w, 30)
	var scrap_before: int = w.scrap
	w.kill_enemy(i, DeathHooks.SOURCE_SELF)
	VarietyLKit.tick(w)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.scrap).is_equal(scrap_before)
	var neutral: StateHasher = StateHasher.new()
	BossState.new().hash_into(neutral)
	var now: StateHasher = StateHasher.new()
	w.boss.hash_into(now)
	assert_str(now.finish()).is_equal(neutral.finish())
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)


## V5-A: the pylons are the priority targets of CONTENT 5. A pylon has speed 0 (its boss carries it), so it once had the
## last ETA bucket and the Warden shot the Array at a fifth of its damage; now a pylon takes its boss's urgency and its
## priority class puts it first, while the Array walks in and once it strikes the core.
func test_the_warden_and_the_turrets_shoot_the_pylons_before_the_array() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _array(w)
	VarietyLKit.run_to(w, 100)
	var pylons: Array[int] = VarietyLKit.living(w, PYLON)
	assert_int(pylons.size()).is_equal(3)
	var x: float = w.warden.x
	var z: float = w.warden.z
	assert_bool(Targeting.compare(w, pylons[0], i, x, z)).is_true()
	assert_bool(Targeting.compare(w, i, pylons[0], x, z)).is_false()
	var picked: int = Targeting.pick(w, x, z, 60.0)
	assert_int(w.enemies.type[w.enemies.index_of(picked)]).is_equal(PYLON)
	w.enemies.state[i] = EnemyStore.ST_ATTACKING  # the Array strikes the core
	picked = Targeting.pick(w, x, z, 60.0)
	assert_int(w.enemies.type[w.enemies.index_of(picked)]).is_equal(PYLON)
	_kill_pylons(w)
	assert_int(Targeting.pick(w, x, z, 60.0)).is_equal(w.enemies.id[i])  # exposed: the Array itself
