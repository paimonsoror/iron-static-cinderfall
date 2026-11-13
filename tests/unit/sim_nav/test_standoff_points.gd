extends GdUnitTestSuite
## V4-N: the standoff points of arena.json schema 2 (VARIETY_SPEC 5.1) and how standoff enemies take them. Variety
## fixture. Standoff points never overlap attack slots; a point has one holder; a full ring parks the enemy in place.

const EPS: float = 0.000001


func _world() -> SimWorld:
	var w: SimWorld = TestContent.variety_world()
	w.phase = GameState.Id.SPAWNING
	return w


func _tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick
	StatusSystem.step(w)
	MovementSystem.step(w)


func _core_dist(w: SimWorld, x: float, z: float) -> float:
	return Vector2(x - w.content.arena.core_x, z - w.content.arena.core_z).length()


func test_standoff_points_never_overlap_attack_slots_props_or_the_bounds() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	assert_int(a.standoff_points.size()).is_greater(20)
	var outer_slot: float = 0.0
	for s: Vector2 in a.slot_positions:
		outer_slot = maxf(outer_slot, _core_dist(w, s.x, s.y))
	var nearest: float = INF
	for k: int in a.standoff_points.size():
		var p: Vector2 = a.standoff_points[k]
		var radius: float = a.standoff_radii[a.standoff_ring[k]]
		assert_float(_core_dist(w, p.x, p.y)).is_equal_approx(radius, 0.0001)
		assert_float(radius).is_greater(a.approach_radius)  # every slot lies inside the approach circle
		assert_bool(p.x > a.min_x and p.x < a.max_x and p.y > a.min_z and p.y < a.max_z).is_true()
		assert_bool(NavGeometry.inside_any(a.obstacles, p.x, p.y, 0.55)).is_false()  # room for the widest standoff body
		assert_bool(is_inf(w.nav.flow.sample_cost(p.x, p.y))).is_false()  # reachable
		for s: Vector2 in a.slot_positions:
			nearest = minf(nearest, Vector2(p.x - s.x, p.y - s.y).length())
	assert_float(nearest).is_greater(3.0)  # the closest point is more than 3 m from the closest slot
	assert_float(outer_slot).is_less(a.approach_radius)
	for def: EnemyDef in w.content.enemies:
		if def.standoff_m > 0.0:
			var ring: int = StandoffPoints.ring_of(a, def.standoff_m)
			assert_int(ring).is_greater_equal(0)
			assert_int(StandoffPoints.free_count(w, ring)).is_greater_equal(def.alive_cap)  # every one of the type can park
	assert_int(StandoffPoints.ring_of(a, 0.0)).is_equal(-1)
	assert_int(StandoffPoints.ring_of(a, 11.11)).is_equal(-1)


func test_points_of_one_ring_are_far_enough_apart_for_two_bodies() -> void:
	var a: ArenaDef = _world().content.arena
	for i: int in a.standoff_points.size():
		for j: int in range(i + 1, a.standoff_points.size()):
			if a.standoff_ring[i] == a.standoff_ring[j]:
				assert_float(a.standoff_points[i].distance_to(a.standoff_points[j])).is_greater(0.9)


func test_a_standoff_enemy_claims_the_nearest_free_point_and_a_second_one_takes_another() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	var first: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 12.0, a.core_z)
	var second: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 12.0, a.core_z)
	_tick(w)
	var p1: int = w.ext.anchor_point[first]
	var p2: int = w.ext.anchor_point[second]
	assert_int(p1).is_greater_equal(0)
	assert_int(p2).is_greater_equal(0)
	assert_int(p1).is_not_equal(p2)
	assert_int(StandoffPoints.holder(w, p1)).is_equal(first)
	assert_int(w.enemies.state[first]).is_equal(EnemyStore.ST_SEEK_SLOT)
	assert_int(w.enemies.slot[first]).is_equal(-1)
	# the lower id chose first and got the nearest point of ring 0
	var best: float = INF
	for k: int in a.standoff_points.size():
		if a.standoff_ring[k] == 0:
			best = minf(best, a.standoff_points[k].distance_to(Vector2(a.core_x + 12.0, a.core_z)))
	assert_float(a.standoff_points[p1].distance_to(Vector2(a.core_x + 12.0, a.core_z))).is_equal_approx(best, 0.001)
	assert_int(StandoffPoints.claim(w, first)).is_equal(p1)  # a holder keeps its point


func test_a_point_is_free_again_when_its_holder_dies() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	var free_before: int = StandoffPoints.free_count(w, 0)
	var s: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 12.0, a.core_z)
	_tick(w)
	var point: int = w.ext.anchor_point[s]
	assert_int(StandoffPoints.free_count(w, 0)).is_equal(free_before - 1)
	w.kill_enemy(s, DamageSource.Id.WARDEN)
	assert_int(StandoffPoints.holder(w, point)).is_equal(-1)
	assert_int(StandoffPoints.free_count(w, 0)).is_equal(free_before)
	var next: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 12.0, a.core_z)
	_tick(w)
	assert_int(w.ext.anchor_point[next]).is_equal(point)


func test_twelve_spitters_park_on_twelve_different_points_and_never_take_a_slot() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	var rows: Array[int] = []
	for k: int in 12:
		rows.append(w.spawn_enemy(Ids.EN_SPITTER, 10.5, -7.0 + 1.2 * float(k)))
	assert_int(w.spawn_enemy(Ids.EN_SPITTER, 10.5, 8.0)).is_equal(-1)  # the type cap of 12
	for _n: int in 2400:
		_tick(w)
	var seen: Dictionary[int, bool] = {}
	for i: int in rows:
		assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
		assert_int(w.enemies.slot[i]).is_equal(-1)
		var point: int = w.ext.anchor_point[i]
		assert_int(point).is_greater_equal(0)
		assert_bool(seen.has(point)).is_false()
		seen[point] = true
		assert_float(w.enemies.x[i]).is_equal_approx(a.standoff_points[point].x, EPS)
		assert_float(w.enemies.z[i]).is_equal_approx(a.standoff_points[point].y, EPS)
	for k: int in w.nav.slots.slot_count():
		assert_int(w.nav.slots.occupant(k)).is_equal(0)


func test_a_standoff_enemy_that_finds_its_ring_full_parks_inside_its_standoff_distance() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	# hold every point of ring 0 with a stand-in
	for k: int in a.standoff_points.size():
		if a.standoff_ring[k] == 0:
			var holder: int = w.spawn_enemy(Ids.EN_SKITTER, 9.5, 11.0)
			w.enemies.stun_ticks[holder] = 100000
			w.ext.anchor_point[holder] = k
	assert_int(StandoffPoints.free_count(w, 0)).is_equal(0)
	var s: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 13.0, a.core_z)
	for _n: int in 400:
		_tick(w)
	assert_int(w.enemies.state[s]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.ext.anchor_point[s]).is_equal(-1)
	var d: float = _core_dist(w, w.enemies.x[s], w.enemies.z[s])
	assert_float(d).is_less_equal(10.5)
	assert_float(d).is_greater(10.5 - 0.1)
	var x: float = w.enemies.x[s]
	for _n: int in 120:
		_tick(w)
	assert_float(w.enemies.x[s]).is_equal(x)


func test_a_stuck_standoff_seeker_is_moved_onto_its_point() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	var s: int = w.spawn_enemy(Ids.EN_SPITTER, a.core_x + 12.0, a.core_z)
	_tick(w)
	var point: int = w.ext.anchor_point[s]
	assert_float(StuckRecovery.force_move(w, s, 5.0)).is_equal(0.0)
	assert_float(w.enemies.x[s]).is_equal_approx(a.standoff_points[point].x, EPS)
	assert_float(w.enemies.z[s]).is_equal_approx(a.standoff_points[point].y, EPS)


func test_standoff_movement_is_deterministic() -> void:
	var hashes: Array[String] = []
	for _run: int in 2:
		var w: SimWorld = _world()
		for k: int in 6:
			w.spawn_enemy(Ids.EN_SPITTER, 10.5, -6.0 + 2.0 * float(k))
			w.spawn_enemy(Ids.EN_SKITTER, 10.5, -5.0 + 2.0 * float(k))
			w.spawn_enemy(Ids.EN_MOTE, 4.0 + float(k), -16.0)
		for k: int in 3:
			w.spawn_enemy(Ids.EN_RECLAIMER, 10.5, 6.0 + float(k))
		for _n: int in 900:
			_tick(w)
		hashes.append(w.state_hash())
	assert_str(hashes[0]).is_equal(hashes[1])
