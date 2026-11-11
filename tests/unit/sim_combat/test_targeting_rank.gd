extends GdUnitTestSuite
## Targeting.pick / compare / is_valid: the rank order of GDD 5.1 (attacking, ETA bucket, Rusher, distance, id).
## Skitter 2.3 m/s = 0.03833 m per tick, Rusher 3.6 m/s = 0.06, Hollow 1.1 m/s = 0.01833, Hulk 0.65 m/s = 0.01083;
## the bucket is 30 ticks, so the path distances below sit well inside their buckets.

const RANGE: float = 25.0


func _pick(w: SimWorld) -> int:
	return Targeting.pick(w, w.warden.x, w.warden.z, RANGE)


func _outranks(w: SimWorld, i: int, j: int) -> bool:
	return Targeting.compare(w, i, j, w.warden.x, w.warden.z)


func test_attacking_beats_moving_even_when_the_mover_is_a_closer_rusher() -> void:
	var w: SimWorld = CombatTestKit.world()
	var mover: int = CombatTestKit.place(w, Ids.EN_RUSHER, 3.0, 0.0, EnemyStore.ST_MOVING, 0.0)
	var attacker: int = CombatTestKit.place(w, Ids.EN_SKITTER, 20.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	assert_int(_pick(w)).is_equal(w.enemies.id[attacker])
	assert_bool(_outranks(w, attacker, mover)).is_true()
	assert_bool(_outranks(w, mover, attacker)).is_false()


func test_seeking_a_slot_does_not_count_as_attacking() -> void:
	var w: SimWorld = CombatTestKit.world()
	var seeker: int = CombatTestKit.place(w, Ids.EN_SKITTER, 3.0, 0.0, EnemyStore.ST_SEEK_SLOT, 0.0)
	var attacker: int = CombatTestKit.place(w, Ids.EN_SKITTER, 20.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	assert_int(_pick(w)).is_equal(w.enemies.id[attacker])
	assert_bool(_outranks(w, seeker, attacker)).is_false()


func test_lower_eta_bucket_beats_higher_even_when_farther_from_the_warden() -> void:
	var w: SimWorld = CombatTestKit.world()
	var soon: int = CombatTestKit.place(w, Ids.EN_SKITTER, 20.0, 0.0, EnemyStore.ST_MOVING, 5.0)
	var later: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0, EnemyStore.ST_MOVING, 15.0)
	assert_int(Targeting.eta_bucket(w, soon)).is_equal(4)
	assert_int(Targeting.eta_bucket(w, later)).is_equal(13)
	assert_int(_pick(w)).is_equal(w.enemies.id[soon])
	assert_bool(_outranks(w, soon, later)).is_true()
	assert_bool(_outranks(w, later, soon)).is_false()


func test_eta_bucket_uses_each_enemys_own_speed() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0, EnemyStore.ST_MOVING, 1.0)
	var rusher: int = CombatTestKit.place(w, Ids.EN_RUSHER, 5.0, 1.0, EnemyStore.ST_MOVING, 3.0)
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 2.0, EnemyStore.ST_MOVING, 1.0)
	var hulk: int = CombatTestKit.place(w, Ids.EN_HULK, 5.0, 3.0, EnemyStore.ST_MOVING, 0.5)
	assert_int(Targeting.eta_bucket(w, skitter)).is_equal(0)  # 26 ticks
	assert_int(Targeting.eta_bucket(w, rusher)).is_equal(1)  # 50 ticks
	assert_int(Targeting.eta_bucket(w, hollow)).is_equal(1)  # 54 ticks
	assert_int(Targeting.eta_bucket(w, hulk)).is_equal(1)  # 46 ticks
	# A slower enemy with a shorter path still arrives later: Skitter (1.0 m) before Hulk (0.5 m).
	assert_bool(_outranks(w, skitter, hulk)).is_true()


func test_rusher_beats_non_rusher_in_the_same_bucket() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 4.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	var rusher: int = CombatTestKit.place(w, Ids.EN_RUSHER, 12.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	assert_int(Targeting.eta_bucket(w, skitter)).is_equal(Targeting.eta_bucket(w, rusher))
	assert_int(_pick(w)).is_equal(w.enemies.id[rusher])
	assert_bool(_outranks(w, rusher, skitter)).is_true()
	assert_bool(_outranks(w, skitter, rusher)).is_false()


func test_a_rusher_in_a_later_bucket_does_not_beat_an_earlier_bucket() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 12.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	var rusher: int = CombatTestKit.place(w, Ids.EN_RUSHER, 4.0, 0.0, EnemyStore.ST_MOVING, 10.0)
	assert_int(_pick(w)).is_equal(w.enemies.id[skitter])
	assert_bool(_outranks(w, skitter, rusher)).is_true()


func test_nearer_beats_farther_when_everything_else_ties() -> void:
	var w: SimWorld = CombatTestKit.world()
	var far_one: int = CombatTestKit.place(w, Ids.EN_SKITTER, 15.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	var near_one: int = CombatTestKit.place(w, Ids.EN_SKITTER, 0.0, 6.0, EnemyStore.ST_MOVING, 0.5)
	assert_int(_pick(w)).is_equal(w.enemies.id[near_one])
	assert_bool(_outranks(w, near_one, far_one)).is_true()
	assert_bool(_outranks(w, far_one, near_one)).is_false()


func test_lower_id_wins_a_full_tie() -> void:
	var w: SimWorld = CombatTestKit.world()
	var first: int = CombatTestKit.place(w, Ids.EN_SKITTER, 8.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	var second: int = CombatTestKit.place(w, Ids.EN_SKITTER, 8.0, 0.0, EnemyStore.ST_MOVING, 0.5)
	assert_int(w.enemies.id[first]).is_less(w.enemies.id[second])
	assert_int(_pick(w)).is_equal(w.enemies.id[first])
	assert_bool(_outranks(w, first, second)).is_true()
	assert_bool(_outranks(w, second, first)).is_false()


func test_id_decides_not_store_index_after_a_slot_is_reused() -> void:
	var w: SimWorld = CombatTestKit.world()
	var gone: int = CombatTestKit.place(w, Ids.EN_SKITTER, 8.0, 0.0)
	var keeper: int = CombatTestKit.place(w, Ids.EN_SKITTER, 8.0, 0.0)
	w.kill_enemy(gone, DamageSource.Id.WARDEN)
	var newcomer: int = CombatTestKit.place(w, Ids.EN_SKITTER, 8.0, 0.0)
	assert_int(newcomer).is_equal(gone)  # the freed low index is reused
	assert_int(w.enemies.id[newcomer]).is_greater(w.enemies.id[keeper])
	assert_int(_pick(w)).is_equal(w.enemies.id[keeper])
	assert_bool(_outranks(w, keeper, newcomer)).is_true()


func test_exactly_one_of_every_pair_outranks_the_other() -> void:
	var w: SimWorld = CombatTestKit.world()
	var all: PackedInt32Array = PackedInt32Array()
	all.append(CombatTestKit.place(w, Ids.EN_SKITTER, 4.0, 0.0, EnemyStore.ST_ATTACKING, 0.0))
	all.append(CombatTestKit.place(w, Ids.EN_RUSHER, 9.0, 2.0, EnemyStore.ST_MOVING, 3.0))
	all.append(CombatTestKit.place(w, Ids.EN_SKITTER, 9.0, 2.0, EnemyStore.ST_MOVING, 3.0))
	all.append(CombatTestKit.place(w, Ids.EN_HOLLOW, 2.0, 8.0, EnemyStore.ST_SEEK_SLOT, 1.0))
	all.append(CombatTestKit.place(w, Ids.EN_HULK, 6.0, 6.0, EnemyStore.ST_MOVING, 40.0))
	all.append(CombatTestKit.place(w, Ids.EN_SKITTER, 9.0, 2.0, EnemyStore.ST_MOVING, 3.0))
	for i: int in all:
		assert_bool(_outranks(w, i, i)).is_false()
		for j: int in all:
			if i != j:
				assert_bool(_outranks(w, i, j) != _outranks(w, j, i)).is_true()


func test_pick_returns_the_enemy_that_outranks_all_others() -> void:
	var w: SimWorld = CombatTestKit.world()
	var all: PackedInt32Array = PackedInt32Array()
	all.append(CombatTestKit.place(w, Ids.EN_SKITTER, 4.0, 0.0, EnemyStore.ST_MOVING, 20.0))
	all.append(CombatTestKit.place(w, Ids.EN_RUSHER, 9.0, 2.0, EnemyStore.ST_MOVING, 3.0))
	all.append(CombatTestKit.place(w, Ids.EN_SKITTER, 9.0, 2.0, EnemyStore.ST_MOVING, 3.0))
	all.append(CombatTestKit.place(w, Ids.EN_HOLLOW, 2.0, 8.0, EnemyStore.ST_MOVING, 1.0))
	var picked: int = _pick(w)
	var picked_index: int = w.enemies.index_of(picked)
	assert_int(picked_index).is_greater_equal(0)
	for j: int in all:
		if j != picked_index:
			assert_bool(_outranks(w, picked_index, j)).is_true()


func test_out_of_range_enemies_are_never_picked_and_the_boundary_is_inclusive() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.place(w, Ids.EN_SKITTER, 0.0, 25.5, EnemyStore.ST_ATTACKING, 0.0)
	assert_int(_pick(w)).is_equal(0)
	var edge: int = CombatTestKit.place(w, Ids.EN_SKITTER, 0.0, 25.0, EnemyStore.ST_MOVING, 90.0)
	assert_int(_pick(w)).is_equal(w.enemies.id[edge])
	assert_bool(Targeting.is_valid(w, w.enemies.id[edge], w.warden.x, w.warden.z, RANGE)).is_true()


func test_range_is_measured_from_the_shooter_not_the_warden() -> void:
	var w: SimWorld = CombatTestKit.world()
	var pad_x: float = w.turrets.x[0]
	var pad_z: float = w.turrets.z[0]
	var inside: int = CombatTestKit.place_abs(w, Ids.EN_SKITTER, pad_x, pad_z + 17.0)
	CombatTestKit.place_abs(w, Ids.EN_SKITTER, pad_x, pad_z - 17.5, EnemyStore.ST_ATTACKING, 0.0)
	assert_int(Targeting.pick(w, pad_x, pad_z, 17.0)).is_equal(w.enemies.id[inside])
	assert_bool(Targeting.is_valid(w, w.enemies.id[inside], pad_x, pad_z, 16.9)).is_false()


func test_dead_enemies_are_never_picked_or_valid() -> void:
	var w: SimWorld = CombatTestKit.world()
	var best: int = CombatTestKit.place(w, Ids.EN_RUSHER, 3.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	var other: int = CombatTestKit.place(w, Ids.EN_SKITTER, 10.0, 0.0)
	var best_id: int = w.enemies.id[best]
	assert_int(_pick(w)).is_equal(best_id)
	w.kill_enemy(best, DamageSource.Id.WARDEN)
	assert_int(_pick(w)).is_equal(w.enemies.id[other])
	assert_bool(Targeting.is_valid(w, best_id, w.warden.x, w.warden.z, RANGE)).is_false()
	w.kill_enemy(other, DamageSource.Id.WARDEN)
	assert_int(_pick(w)).is_equal(0)


func test_pick_with_no_enemies_returns_zero() -> void:
	var w: SimWorld = CombatTestKit.world()
	assert_int(_pick(w)).is_equal(0)
	assert_bool(Targeting.is_valid(w, 0, w.warden.x, w.warden.z, RANGE)).is_false()
	assert_bool(Targeting.is_valid(w, 99, w.warden.x, w.warden.z, RANGE)).is_false()
