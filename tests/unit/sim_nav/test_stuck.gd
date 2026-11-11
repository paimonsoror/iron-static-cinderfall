extends GdUnitTestSuite
## Stuck detection and deterministic recovery (ARCH 6.6, GDD 7): the enemy is reported, moved, and never removed.


## A world with a short wall across the yard at x = 5 (z 2..6) whose east side is steered straight west in one flow
## cell, so an enemy standing there presses into the wall, cannot make progress, and finds a way around it once the
## recovery moves it to a cell with a lower flow cost.
func _walled_world() -> SimWorld:
	var content: ContentSet = TestContent.baseline()
	var wall: ObstacleDef = ObstacleDef.new()
	wall.id = &"test_wall"
	wall.shape = ObstacleDef.Shape.BOX
	wall.x = 5.0
	wall.z = 4.0
	wall.size_x = 0.6
	wall.size_z = 4.0
	content.arena.obstacles.append(wall)
	var w: SimWorld = NavTestUtil.world_with(content)
	var flow: FlowField = w.nav.flow
	var pin: int = flow.grid.cell_of(6.5, 4.5)
	flow.dir_x[pin] = -1.0
	flow.dir_z[pin] = 0.0
	return w


func test_a_pinned_enemy_is_reported_stuck_and_then_resumes_progress() -> void:
	var w: SimWorld = _walled_world()
	var wall: ObstacleDef = w.content.arena.obstacles[w.content.arena.obstacles.size() - 1]
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 6.4, 4.5)
	var enemy_id: int = w.enemies.id[i]
	var stuck_tick: int = -1
	var start_path: float = 0.0
	for n: int in 1300:
		NavTestUtil.advance(w)
		if n == 0:
			start_path = w.enemies.path_dist[i]
		assert_bool(wall.contains(w.enemies.x[i], w.enemies.z[i], 0.0)).is_false()
		assert_int(w.enemies.alive[i]).is_equal(1)
		if stuck_tick < 0 and NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_STUCK) > 0:
			stuck_tick = n
			assert_float(w.enemies.x[i]).is_greater(wall.x)
	var stuck: Array[SimEvent] = NavTestUtil.events_of(w, SimEventKind.Id.ENEMY_STUCK)
	assert_int(stuck.size()).is_greater_equal(1)
	assert_int(stuck[0].a).is_equal(enemy_id)
	assert_int(stuck[0].b).is_equal(1)
	assert_int(stuck_tick).is_between(200, 300)
	assert_int(w.stats.stuck_recoveries).is_equal(stuck.size())
	assert_float(w.enemies.x[i]).is_less(wall.x - 0.3)
	assert_float(w.enemies.path_dist[i]).is_less(start_path - 1.0)
	assert_int(w.enemies.id[i]).is_equal(enemy_id)


func test_recovery_ignores_separation_before_it_moves_the_enemy() -> void:
	var w: SimWorld = _walled_world()
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 6.4, 4.5)
	var seen_grace: bool = false
	var moved_at: int = -1
	var last_x: float = w.enemies.x[i]
	var last_z: float = w.enemies.z[i]
	for n: int in 700:
		NavTestUtil.advance(w)
		if w.nav.sep_off[i] > 0:
			seen_grace = true
		var jump: float = Vector2(w.enemies.x[i] - last_x, w.enemies.z[i] - last_z).length()
		if jump > 0.3 and moved_at < 0:
			moved_at = n
		last_x = w.enemies.x[i]
		last_z = w.enemies.z[i]
	assert_bool(seen_grace).is_true()
	assert_int(moved_at).is_greater(300)
	assert_int(w.nav.recoveries[i]).is_greater_equal(1)


func test_a_stunned_enemy_is_never_reported_stuck() -> void:
	var w: SimWorld = _walled_world()
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 6.4, 4.5)
	w.enemies.stun_ticks[i] = 100000
	NavTestUtil.advance_n(w, 800)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_STUCK)).is_equal(0)
	assert_float(w.enemies.x[i]).is_equal(6.4)
	assert_float(w.enemies.z[i]).is_equal(4.5)


func test_open_ground_walkers_are_never_reported_stuck() -> void:
	var w: SimWorld = NavTestUtil.world()
	var ids: Array[int] = []
	for k: int in 6:
		ids.append(w.spawn_enemy(Ids.EN_SKITTER if k % 2 == 0 else Ids.EN_HOLLOW, 10.8, -6.0 + float(k) * 2.5))
	NavTestUtil.advance_n(w, 1200)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_STUCK)).is_equal(0)
	assert_int(w.stats.stuck_recoveries).is_equal(0)
	for i: int in ids:
		assert_int(w.enemies.alive[i]).is_equal(1)


func test_stuck_recovery_is_deterministic() -> void:
	var hashes: Array[String] = []
	for n: int in 2:
		var w: SimWorld = _walled_world()
		w.spawn_enemy(Ids.EN_HOLLOW, 6.4, 4.5)
		w.spawn_enemy(Ids.EN_SKITTER, 6.4, 5.4)
		NavTestUtil.advance_n(w, 900)
		hashes.append(w.state_hash())
	assert_str(hashes[0]).is_equal(hashes[1])
