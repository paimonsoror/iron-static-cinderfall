extends GdUnitTestSuite
## The target lock (GDD 5.1, ARCH 6.6): kept for lock_ticks (0.4 s = 24 ticks) while valid, dropped the tick it
## dies or leaves range, re-picked when it expires. A pick on tick T holds the target on ticks T .. T + 23.

const RANGE: float = 25.0


func test_a_target_is_kept_for_24_ticks_even_when_a_better_one_appears() -> void:
	var w: SimWorld = CombatTestKit.world()
	var first: int = CombatTestKit.place(w, Ids.EN_SKITTER, 18.0, 0.0, EnemyStore.ST_MOVING, 20.0)
	CombatTestKit.make_tough(w, first)
	var first_id: int = w.enemies.id[first]
	CombatTestKit.warden_tick(w)  # tick 1: picks and starts the lock
	assert_int(w.warden.target_id).is_equal(first_id)
	assert_int(w.warden.lock_ticks_left).is_equal(24)
	var better: int = CombatTestKit.place(w, Ids.EN_RUSHER, 2.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	CombatTestKit.make_tough(w, better)
	for n: int in 23:  # ticks 2..24
		CombatTestKit.warden_tick(w)
		assert_int(w.warden.target_id).is_equal(first_id)
	assert_int(w.tick).is_equal(24)
	assert_int(w.warden.lock_ticks_left).is_equal(1)
	CombatTestKit.warden_tick(w)  # tick 25: the lock has expired, so the better enemy is picked
	assert_int(w.warden.target_id).is_equal(w.enemies.id[better])
	assert_int(w.warden.lock_ticks_left).is_equal(24)


func test_the_lock_counts_down_one_per_tick() -> void:
	var w: SimWorld = CombatTestKit.world()
	var e: int = CombatTestKit.place(w, Ids.EN_SKITTER, 10.0, 0.0)
	CombatTestKit.make_tough(w, e)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.lock_ticks_left).is_equal(24)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.lock_ticks_left).is_equal(23)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.lock_ticks_left).is_equal(22)


func test_an_expired_lock_repicks_and_restarts_even_when_the_target_is_unchanged() -> void:
	var w: SimWorld = CombatTestKit.world()
	var e: int = CombatTestKit.place(w, Ids.EN_SKITTER, 10.0, 0.0)
	CombatTestKit.make_tough(w, e)
	CombatTestKit.run_warden(w, 24)
	assert_int(w.warden.lock_ticks_left).is_equal(1)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[e])
	assert_int(w.warden.lock_ticks_left).is_equal(24)


func test_the_target_is_dropped_the_tick_it_dies_and_a_new_one_is_picked_at_once() -> void:
	var w: SimWorld = CombatTestKit.world()
	var first: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	var second: int = CombatTestKit.place(w, Ids.EN_SKITTER, 12.0, 0.0)
	CombatTestKit.make_tough(w, first)
	CombatTestKit.make_tough(w, second)
	CombatTestKit.run_warden(w, 5)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[first])
	assert_int(w.warden.lock_ticks_left).is_greater(0)
	w.kill_enemy(first, DamageSource.Id.TURRET_0)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[second])
	assert_int(w.warden.lock_ticks_left).is_equal(24)


func test_with_nothing_left_the_dead_target_is_dropped_to_none() -> void:
	var w: SimWorld = CombatTestKit.world()
	var only: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	CombatTestKit.make_tough(w, only)
	CombatTestKit.run_warden(w, 3)
	w.kill_enemy(only, DamageSource.Id.WARDEN)
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.target_id).is_equal(0)
	assert_int(w.warden.lock_ticks_left).is_equal(0)


func test_a_target_that_leaves_range_is_dropped_at_once_despite_the_lock() -> void:
	var w: SimWorld = CombatTestKit.world()
	var runner: int = CombatTestKit.place(w, Ids.EN_SKITTER, 10.0, 0.0)
	var stayer: int = CombatTestKit.place(w, Ids.EN_SKITTER, 0.0, 15.0)
	CombatTestKit.make_tough(w, runner)
	CombatTestKit.make_tough(w, stayer)
	CombatTestKit.run_warden(w, 3)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[runner])
	w.enemies.x[runner] = w.warden.x + 40.0
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[stayer])
	assert_int(w.warden.lock_ticks_left).is_equal(24)


func test_the_warden_repicks_the_same_tick_its_own_shot_kills_the_target() -> void:
	var w: SimWorld = CombatTestKit.world()
	var weak: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	var next_one: int = CombatTestKit.place(w, Ids.EN_SKITTER, 12.0, 0.0)
	CombatTestKit.make_tough(w, next_one)
	w.enemies.hp[weak] = 10.0
	w.warden.fire_acc_milli = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.warden_tick(w)
	assert_int(w.warden.shots_fired).is_equal(1)
	assert_int(w.enemies.index_of(w.enemies.id[weak])).is_equal(-1)
	assert_int(w.warden.target_id).is_equal(w.enemies.id[next_one])
	assert_int(w.warden.lock_ticks_left).is_equal(24)
	assert_float(w.warden.aim_x).is_equal(w.enemies.x[next_one])
	assert_float(w.warden.aim_z).is_equal(w.enemies.z[next_one])


func test_turrets_keep_their_own_24_tick_lock() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var first: int = CombatTestKit.place_abs(w, Ids.EN_SKITTER, w.turrets.x[0] + 8.0, w.turrets.z[0], EnemyStore.ST_MOVING, 20.0)
	CombatTestKit.make_tough(w, first)
	var first_id: int = w.enemies.id[first]
	CombatTestKit.turret_tick(w)
	assert_int(w.turrets.target_id[0]).is_equal(first_id)
	assert_int(w.turrets.lock_ticks_left[0]).is_equal(24)
	var better: int = CombatTestKit.place_abs(w, Ids.EN_SKITTER, w.turrets.x[0] + 14.0, w.turrets.z[0], EnemyStore.ST_ATTACKING, 0.0)
	CombatTestKit.make_tough(w, better)
	for n: int in 23:
		CombatTestKit.turret_tick(w)
		assert_int(w.turrets.target_id[0]).is_equal(first_id)
	CombatTestKit.turret_tick(w)
	assert_int(w.turrets.target_id[0]).is_equal(w.enemies.id[better])


func test_refresh_lock_drops_a_stale_id_and_reports_none_when_nothing_is_in_range() -> void:
	var w: SimWorld = CombatTestKit.world()
	var stale: PackedInt32Array = Targeting.refresh_lock(w, 77, 10, w.warden.x, w.warden.z, RANGE, 24)
	assert_int(stale[0]).is_equal(0)
	assert_int(stale[1]).is_equal(0)
	var e: int = CombatTestKit.place(w, Ids.EN_SKITTER, 6.0, 0.0)
	var fresh: PackedInt32Array = Targeting.refresh_lock(w, 77, 10, w.warden.x, w.warden.z, RANGE, 24)
	assert_int(fresh[0]).is_equal(w.enemies.id[e])
	assert_int(fresh[1]).is_equal(24)
	var kept: PackedInt32Array = Targeting.refresh_lock(w, w.enemies.id[e], 10, w.warden.x, w.warden.z, RANGE, 24)
	assert_int(kept[0]).is_equal(w.enemies.id[e])
	assert_int(kept[1]).is_equal(9)
