extends GdUnitTestSuite
## MovementSystem basics: flow following, arrival, stun, bounds and bookkeeping (ARCH 6.6).


func _run_until_attacking(w: SimWorld, index: int, max_ticks: int) -> int:
	var n: int = 0
	while w.enemies.state[index] != EnemyStore.ST_ATTACKING and n < max_ticks:
		NavTestUtil.advance(w)
		n += 1
	return n


func test_a_lone_skitter_reaches_a_slot_within_fifteen_percent_of_straight_line_time() -> void:
	for start: Vector2 in [Vector2(10.8, 3.0), Vector2(10.8, -8.0), Vector2(10.8, 9.0), Vector2(5.0, -16.8), Vector2(10.0, -16.8)]:
		var w: SimWorld = NavTestUtil.world()
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, start.x, start.y)
		var ticks: int = _run_until_attacking(w, i, 1500)
		assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
		var target: Vector2 = w.content.arena.slot_positions[w.enemies.slot[i]]
		var straight: float = Vector2(start.x - target.x, start.y - target.y).length() / (2.3 * SimWorld.DT)
		assert_float(float(ticks)).is_less_equal(straight * 1.15)
		assert_float(float(ticks)).is_greater_equal(straight * 0.9)


func test_arrival_starts_the_attack_timer_reports_the_slot_and_settles_on_it() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 10.8, 3.0)
	var enemy_id: int = w.enemies.id[i]
	_run_until_attacking(w, i, 1500)
	var period: int = w.content.enemies[Ids.EN_SKITTER].attack_period_ticks
	assert_int(period).is_equal(90)
	assert_int(w.enemies.attack_cd[i]).is_equal(period)
	var slot: int = w.enemies.slot[i]
	assert_int(slot).is_greater_equal(0)
	assert_int(w.nav.slots.occupant(slot)).is_equal(enemy_id)
	var reached: Array[SimEvent] = NavTestUtil.events_of(w, SimEventKind.Id.ENEMY_REACHED_SLOT)
	assert_int(reached.size()).is_equal(1)
	assert_int(reached[0].a).is_equal(enemy_id)
	assert_int(reached[0].b).is_equal(slot)
	NavTestUtil.advance_n(w, 12)
	var target: Vector2 = w.content.arena.slot_positions[slot]
	assert_float(w.enemies.x[i]).is_equal(target.x)
	assert_float(w.enemies.z[i]).is_equal(target.y)
	assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.enemies.attack_cd[i]).is_equal(period)
	assert_float(w.enemies.path_dist[i]).is_equal(0.0)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_REACHED_SLOT)).is_equal(1)


func test_every_type_arrives_as_an_attacker_with_its_own_period() -> void:
	var w: SimWorld = NavTestUtil.world()
	var spots: Array[Vector2] = [Vector2(2.0, 0.0), Vector2(2.0, 3.0), Vector2(2.0, 6.0), Vector2(0.0, 9.0)]
	var idx: Array[int] = []
	for type_index: int in 4:
		idx.append(w.spawn_enemy(type_index, spots[type_index].x, spots[type_index].y))
	NavTestUtil.advance_n(w, 1500)
	var used: Dictionary = {}
	for type_index: int in 4:
		var i: int = idx[type_index]
		assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
		assert_int(w.enemies.attack_cd[i]).is_equal(w.content.enemies[type_index].attack_period_ticks)
		var slot: int = w.enemies.slot[i]
		assert_bool(used.has(slot)).is_false()
		used[slot] = true
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_REACHED_SLOT)).is_equal(4)


func test_a_stunned_enemy_does_not_move_and_walks_again_after_the_stun() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 8.0, 3.0)
	NavTestUtil.advance_n(w, 10)
	w.enemies.stun_ticks[i] = 60
	var x0: float = w.enemies.x[i]
	var z0: float = w.enemies.z[i]
	NavTestUtil.advance_n(w, 60)
	assert_float(w.enemies.x[i]).is_equal(x0)
	assert_float(w.enemies.z[i]).is_equal(z0)
	assert_float(w.enemies.prev_x[i]).is_equal(x0)
	w.enemies.stun_ticks[i] = 0
	NavTestUtil.advance_n(w, 30)
	assert_float(w.enemies.x[i]).is_less(x0 - 0.5)


func test_a_stunned_seeker_stays_where_it_is() -> void:
	var w: SimWorld = NavTestUtil.world()
	var seeker: int = w.spawn_enemy(Ids.EN_SKITTER, 0.5, 3.0)
	NavTestUtil.advance_n(w, 30)
	assert_int(w.enemies.state[seeker]).is_equal(EnemyStore.ST_SEEK_SLOT)
	w.enemies.stun_ticks[seeker] = 1000
	var x0: float = w.enemies.x[seeker]
	NavTestUtil.advance_n(w, 100)
	assert_float(w.enemies.x[seeker]).is_equal(x0)
	assert_int(w.enemies.state[seeker]).is_equal(EnemyStore.ST_SEEK_SLOT)


func test_prev_position_is_the_position_one_tick_ago() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.fill_mixed(w, 12)
	for n: int in 120:
		var before_x: PackedFloat64Array = w.enemies.x.duplicate()
		var before_z: PackedFloat64Array = w.enemies.z.duplicate()
		NavTestUtil.advance(w)
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] == 1:
				assert_float(w.enemies.prev_x[i]).is_equal(before_x[i])
				assert_float(w.enemies.prev_z[i]).is_equal(before_z[i])


func test_displacement_per_tick_is_bounded_by_one_and_a_half_times_speed() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.fill_mixed(w, 30)
	var worst: float = 0.0
	for n: int in 900:
		NavTestUtil.advance(w)
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] == 0:
				continue
			var speed: float = w.content.enemies[w.enemies.type[i]].speed_mps
			var dx: float = w.enemies.x[i] - w.enemies.prev_x[i]
			var dz: float = w.enemies.z[i] - w.enemies.prev_z[i]
			var moved: float = sqrt(dx * dx + dz * dz)
			assert_float(moved).is_less_equal(1.5 * speed * SimWorld.DT + 0.000000001)
			worst = maxf(worst, moved / (speed * SimWorld.DT))
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_STUCK)).is_equal(0)
	assert_float(worst).is_greater(0.99)


func test_an_enemy_claims_its_slot_when_it_crosses_the_approach_circle() -> void:
	var w: SimWorld = NavTestUtil.world()
	var arena: ArenaDef = w.content.arena
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 3.0, 3.0)
	assert_int(w.enemies.slot[i]).is_equal(-1)
	var crossed_at: int = -1
	for n: int in 400:
		NavTestUtil.advance(w)
		var d: float = Vector2(w.enemies.x[i] - arena.core_x, w.enemies.z[i] - arena.core_z).length()
		if w.enemies.state[i] != EnemyStore.ST_MOVING and crossed_at < 0:
			crossed_at = n
			assert_float(d).is_less_equal(arena.approach_radius + 0.2)
			assert_int(w.enemies.slot[i]).is_greater_equal(0)
			assert_int(w.nav.slots.occupant(w.enemies.slot[i])).is_equal(w.enemies.id[i])
	assert_int(crossed_at).is_between(0, 120)


func test_path_distance_shrinks_while_walking_and_is_zero_for_attackers() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 10.8, 3.0)
	NavTestUtil.advance(w)
	var last: float = w.enemies.path_dist[i]
	assert_float(last).is_greater(9.0)
	for n: int in 25:
		NavTestUtil.advance_n(w, 20)
		assert_float(w.enemies.path_dist[i]).is_less(last)
		last = w.enemies.path_dist[i]
	_run_until_attacking(w, i, 3000)
	assert_float(w.enemies.path_dist[i]).is_equal(0.0)


func test_facing_is_a_unit_vector_pointing_the_way_it_walks() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 10.8, 3.0)
	NavTestUtil.advance_n(w, 20)
	assert_float(Vector2(w.enemies.face_x[i], w.enemies.face_z[i]).length()).is_equal_approx(1.0, 0.0001)
	assert_float(w.enemies.face_x[i]).is_less(-0.9)
	_run_until_attacking(w, i, 3000)
	var core: Vector2 = Vector2(w.content.arena.core_x - w.enemies.x[i], w.content.arena.core_z - w.enemies.z[i]).normalized()
	assert_float(core.dot(Vector2(w.enemies.face_x[i], w.enemies.face_z[i]))).is_greater(0.99)


func test_externally_spawned_enemies_are_tracked_and_moved_without_the_spawn_system() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 9.0, 5.0)
	assert_int(w.nav.track_id[i]).is_equal(0)
	NavTestUtil.advance(w)
	assert_int(w.nav.track_id[i]).is_equal(w.enemies.id[i])
	assert_float(w.enemies.path_dist[i]).is_greater(5.0)
	assert_float(w.enemies.x[i]).is_less(9.0)


func test_a_wanderer_outside_the_grid_is_pulled_back_in() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 40.0, -40.0)
	NavTestUtil.advance(w)
	assert_float(w.enemies.x[i]).is_less_equal(w.nav.bound_max_x)
	assert_float(w.enemies.z[i]).is_greater_equal(w.nav.bound_min_z)
	NavTestUtil.advance_n(w, 20)
	assert_bool(is_finite(w.enemies.x[i]) and is_finite(w.enemies.z[i])).is_true()
