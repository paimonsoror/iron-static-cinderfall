extends GdUnitTestSuite
## Distinct archetype movement (GDD 6, acceptance A08): Rusher, Skitter, Hollow Warden, Siege Hulk.


## Positions of enemy index 0 (T) after `ticks` ticks, optionally with a skitter placed `gap` meters beside it.
func _after(type_index: int, with_neighbor: bool, gap: float, ticks: int) -> Vector2:
	var w: SimWorld = NavTestUtil.world()
	var t: int = w.spawn_enemy(type_index, 3.0, -2.0)
	if with_neighbor:
		w.spawn_enemy(Ids.EN_SKITTER, 3.0, -2.0 + gap)
	NavTestUtil.advance_n(w, ticks)
	return Vector2(w.enemies.x[t], w.enemies.z[t])


func _push_on(type_index: int, gap: float) -> float:
	return (_after(type_index, true, gap, 1) - _after(type_index, false, gap, 1)).length()


func test_the_rusher_arrives_before_the_skitter_and_the_skitter_before_the_hollow_warden() -> void:
	var w: SimWorld = NavTestUtil.world()
	var rusher: int = w.spawn_enemy(Ids.EN_RUSHER, 10.8, 3.0)
	var skitter: int = w.spawn_enemy(Ids.EN_SKITTER, 10.8, 4.4)
	var hollow: int = w.spawn_enemy(Ids.EN_HOLLOW, 10.8, 1.6)
	var arrival: Dictionary = {}
	for n: int in 1500:
		NavTestUtil.advance(w)
		for i: int in [rusher, skitter, hollow]:
			if w.enemies.state[i] == EnemyStore.ST_ATTACKING and not arrival.has(i):
				arrival[i] = n
	assert_int(arrival.size()).is_equal(3)
	var t_rusher: int = arrival[rusher]
	var t_skitter: int = arrival[skitter]
	var t_hollow: int = arrival[hollow]
	assert_int(t_rusher).is_less(t_skitter)
	assert_int(t_skitter).is_less(t_hollow)
	var straight: float = 15.3 / (3.6 * SimWorld.DT)
	assert_float(float(t_rusher)).is_less(straight * 1.1)


func test_the_rusher_runs_straight_at_the_core_when_the_line_is_clear() -> void:
	var w: SimWorld = NavTestUtil.world()
	var i: int = w.spawn_enemy(Ids.EN_RUSHER, 10.8, 3.0)
	for n: int in 100:
		NavTestUtil.advance(w)
		assert_float(w.enemies.z[i]).is_equal_approx(3.0, 0.02)
	assert_float(w.enemies.x[i]).is_less(10.8 - 5.0)


func test_the_rusher_goes_around_a_prop_that_blocks_the_line() -> void:
	var w: SimWorld = NavTestUtil.world()
	var crates: ObstacleDef = w.content.arena.obstacles[2]
	assert_str(String(crates.id)).is_equal("crates")
	var i: int = w.spawn_enemy(Ids.EN_RUSHER, 9.0, crates.z)
	var closest: float = INF
	var arrived: bool = false
	for n: int in 900:
		NavTestUtil.advance(w)
		assert_bool(crates.contains(w.enemies.x[i], w.enemies.z[i], 0.0)).is_false()
		closest = minf(closest, Vector2(w.enemies.x[i] - crates.x, w.enemies.z[i] - crates.z).length())
		if w.enemies.state[i] == EnemyStore.ST_ATTACKING:
			arrived = true
			break
	assert_bool(arrived).is_true()
	assert_float(closest).is_greater(crates.radius + 0.35)


func test_the_skitter_weaves_and_the_hollow_warden_walks_a_steady_line() -> void:
	var spread: Dictionary = {}
	for type_index: int in [Ids.EN_SKITTER, Ids.EN_HOLLOW]:
		var w: SimWorld = NavTestUtil.world()
		var i: int = w.spawn_enemy(type_index, 10.8, 3.0)
		var lo: float = INF
		var hi: float = -INF
		for n: int in 240:
			NavTestUtil.advance(w)
			lo = minf(lo, w.enemies.z[i])
			hi = maxf(hi, w.enemies.z[i])
		spread[type_index] = hi - lo
	var skitter_spread: float = spread[Ids.EN_SKITTER]
	var hollow_spread: float = spread[Ids.EN_HOLLOW]
	assert_float(skitter_spread).is_between(0.6, 1.3)
	assert_float(hollow_spread).is_less(0.25)


func test_the_hollow_warden_is_pushed_less_than_a_skitter_by_the_same_neighbor() -> void:
	var on_skitter: float = _push_on(Ids.EN_SKITTER, 0.4)
	var on_hollow: float = _push_on(Ids.EN_HOLLOW, 0.4)
	assert_float(on_skitter).is_greater(0.001)
	assert_float(on_hollow).is_greater(0.0)
	assert_float(on_hollow).is_less(on_skitter * 0.5)


func test_the_rusher_almost_ignores_separation() -> void:
	var on_skitter: float = _push_on(Ids.EN_SKITTER, 0.4)
	var on_rusher: float = _push_on(Ids.EN_RUSHER, 0.4)
	assert_float(on_rusher).is_less(on_skitter)


func test_the_hulk_is_never_displaced_by_neighbors_and_shoves_them_aside() -> void:
	var lone: SimWorld = NavTestUtil.world()
	var crowd: SimWorld = NavTestUtil.world()
	var control: SimWorld = NavTestUtil.world()
	var h_lone: int = lone.spawn_enemy(Ids.EN_HULK, 3.0, -2.0)
	var h_crowd: int = crowd.spawn_enemy(Ids.EN_HULK, 3.0, -2.0)
	var offsets: Array[Vector2] = [Vector2(0.9, 0.0), Vector2(-0.8, 0.5), Vector2(0.0, 1.0), Vector2(0.3, -0.9)]
	var skitters: Array[int] = []
	var controls: Array[int] = []
	for o: Vector2 in offsets:
		skitters.append(crowd.spawn_enemy(Ids.EN_SKITTER, 3.0 + o.x, -2.0 + o.y))
		controls.append(control.spawn_enemy(Ids.EN_SKITTER, 3.0 + o.x, -2.0 + o.y))
	for n: int in 40:
		NavTestUtil.advance(lone)
		NavTestUtil.advance(crowd)
		NavTestUtil.advance(control)
		assert_float(crowd.enemies.x[h_crowd]).is_equal(lone.enemies.x[h_lone])
		assert_float(crowd.enemies.z[h_crowd]).is_equal(lone.enemies.z[h_lone])
	var hulk: Vector2 = Vector2(crowd.enemies.x[h_crowd], crowd.enemies.z[h_crowd])
	var shoved: int = 0
	for k: int in 4:
		var with_hulk: Vector2 = Vector2(crowd.enemies.x[skitters[k]], crowd.enemies.z[skitters[k]])
		var without: Vector2 = Vector2(control.enemies.x[controls[k]], control.enemies.z[controls[k]])
		if (with_hulk - hulk).length() > (without - hulk).length() + 0.1:
			shoved += 1
	assert_int(shoved).is_greater_equal(3)


func test_attackers_are_neither_pushed_nor_pushing() -> void:
	var w: SimWorld = NavTestUtil.world()
	var first: int = w.spawn_enemy(Ids.EN_SKITTER, 10.8, 3.0)
	var guard: int = 0
	while w.enemies.state[first] != EnemyStore.ST_ATTACKING and guard < 1500:
		NavTestUtil.advance(w)
		guard += 1
	NavTestUtil.advance_n(w, 10)
	var x0: float = w.enemies.x[first]
	var z0: float = w.enemies.z[first]
	var visitor: int = w.spawn_enemy(Ids.EN_HOLLOW, x0, z0)
	NavTestUtil.advance_n(w, 90)
	assert_float(w.enemies.x[first]).is_equal(x0)
	assert_float(w.enemies.z[first]).is_equal(z0)
	assert_int(w.enemies.state[first]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.enemies.slot[visitor]).is_not_equal(w.enemies.slot[first])
