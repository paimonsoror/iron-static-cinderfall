extends GdUnitTestSuite
## V2-A: the cheap path of the minis in MovementSystem (VARIETY_SPEC 5.4): no slot, no separation, no weave, a stop at the
## core cage. Variety content (TestContent.variety()); the legacy bodies must move exactly as before.

const START_X: float = -1.0  ## 6.5 m from the core at (-7.5, 3.0), inside the approach circle of 9 m
const START_Z: float = 3.0


func _world() -> SimWorld:
	return NavTestUtil.world_with(TestContent.variety())


func _dist(w: SimWorld, i: int, j: int) -> float:
	return Vector2(w.enemies.x[i] - w.enemies.x[j], w.enemies.z[i] - w.enemies.z[j]).length()


func _hold(w: SimWorld) -> float:
	return w.content.arena.core_radius + w.content.enemies[Ids.EN_MOTE].beh(&"burnout_m") - MovementSystem.MINI_HOLD_MARGIN_M


func _to_core(w: SimWorld, i: int) -> float:
	var a: ArenaDef = w.content.arena
	return Vector2(w.enemies.x[i] - a.core_x, w.enemies.z[i] - a.core_z).length()


func test_a_mini_walks_at_full_speed_with_no_weave() -> void:
	var w: SimWorld = _world()
	var i: int = w.spawn_enemy(Ids.EN_MOTE, START_X, START_Z)
	assert_bool(w.ext.has_flag(i, EnemyExtState.F_MINI)).is_true()
	var spd: float = w.nav.t_step[Ids.EN_MOTE]
	assert_float(w.content.enemies[Ids.EN_MOTE].weave_amp_m).is_greater(0.0)  # the data asks for a weave; a mini skips it
	NavTestUtil.advance(w)
	for _n: int in 40:
		var x: float = w.enemies.x[i]
		var z: float = w.enemies.z[i]
		NavTestUtil.advance(w)
		assert_float(Vector2(w.enemies.x[i] - x, w.enemies.z[i] - z).length()).is_equal_approx(spd, 0.000001)


func test_minis_are_not_pushed_apart_but_bodies_are() -> void:
	var w: SimWorld = _world()
	var motes: Array[int] = []
	var skitters: Array[int] = []
	for _k: int in 4:
		motes.append(w.spawn_enemy(Ids.EN_MOTE, START_X, START_Z))
	for _k: int in 4:
		skitters.append(w.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z + 4.0))
	NavTestUtil.advance_n(w, 30)
	var mote_spread: float = 0.0
	var skitter_spread: float = 0.0
	for k: int in range(1, 4):
		mote_spread = maxf(mote_spread, _dist(w, motes[0], motes[k]))
		skitter_spread = maxf(skitter_spread, _dist(w, skitters[0], skitters[k]))
	assert_float(mote_spread).is_less(0.15)  # the same heading, only the steering phase differs by a tick or two
	assert_float(skitter_spread).is_greater(0.4)  # stacked bodies push each other out


func test_a_mini_in_a_crowd_does_not_move_a_body() -> void:
	var alone: SimWorld = _world()
	var crowd: SimWorld = _world()
	var a: int = alone.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z)
	var b: int = crowd.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z)
	for k: int in 8:
		crowd.spawn_enemy(Ids.EN_MOTE, START_X + 0.05 * float(k), START_Z)
	NavTestUtil.advance_n(alone, 90)
	NavTestUtil.advance_n(crowd, 90)
	assert_float(crowd.enemies.x[b]).is_equal(alone.enemies.x[a])
	assert_float(crowd.enemies.z[b]).is_equal(alone.enemies.z[a])


func test_a_mini_never_takes_an_attack_slot_and_stops_at_the_cage() -> void:
	var w: SimWorld = _world()
	var mote: int = w.spawn_enemy(Ids.EN_MOTE, START_X, START_Z)
	var skitter: int = w.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z + 3.0)
	NavTestUtil.advance_n(w, 300)
	assert_int(w.enemies.state[mote]).is_equal(EnemyStore.ST_MOVING)
	assert_int(w.enemies.slot[mote]).is_equal(-1)
	assert_int(w.enemies.state[skitter]).is_equal(EnemyStore.ST_ATTACKING)  # the body took a slot
	var hold: float = _hold(w)
	assert_float(_to_core(w, mote)).is_less_equal(hold + w.nav.t_step[Ids.EN_MOTE])
	assert_float(_to_core(w, mote)).is_greater_equal(w.content.arena.core_radius)
	var x: float = w.enemies.x[mote]
	var z: float = w.enemies.z[mote]
	NavTestUtil.advance_n(w, 120)
	assert_float(w.enemies.x[mote]).is_equal(x)  # it waits at the cage for the core system to burn it out
	assert_float(w.enemies.z[mote]).is_equal(z)
	assert_float(w.enemies.path_dist[mote]).is_equal(0.0)


func test_a_mini_from_the_spawn_edge_reaches_the_cage_along_the_flow_field() -> void:
	var w: SimWorld = _world()
	var mote: int = w.spawn_enemy(Ids.EN_MOTE, 10.5, -6.0)
	var start: float = _to_core(w, mote)
	var hold: float = _hold(w)
	var ticks: int = 0
	while _to_core(w, mote) > hold + 0.06 and ticks < 1200:
		NavTestUtil.advance(w)
		ticks += 1
	assert_int(ticks).is_less(1200)
	assert_float(start).is_greater(18.0)
	assert_float(float(ticks) * w.nav.t_step[Ids.EN_MOTE]).is_greater_equal(start - hold - 0.1)  # it cannot be faster than its speed


func test_a_stunned_mini_does_not_move() -> void:
	var w: SimWorld = _world()
	var mote: int = w.spawn_enemy(Ids.EN_MOTE, START_X, START_Z)
	NavTestUtil.advance_n(w, 5)
	w.enemies.stun_ticks[mote] = 30
	var x: float = w.enemies.x[mote]
	NavTestUtil.advance_n(w, 20)
	assert_float(w.enemies.x[mote]).is_equal(x)


func test_the_legacy_bodies_keep_their_separation_and_weave() -> void:
	var w: SimWorld = NavTestUtil.world()
	var a: int = w.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z + 4.0)
	var b: int = w.spawn_enemy(Ids.EN_SKITTER, START_X, START_Z + 4.0)
	NavTestUtil.advance_n(w, 30)
	assert_float(_dist(w, a, b)).is_greater(0.4)
