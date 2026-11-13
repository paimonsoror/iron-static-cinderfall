extends GdUnitTestSuite
## Crowds: invariants over long runs, determinism, the 50-enemy slot assignment, and the MovementSystem benchmark.


## Kills the lowest-id attacker every 45 ticks so the run keeps cycling enemies through the slots.
func _cull(w: SimWorld) -> void:
	if w.tick % 45 != 0:
		return
	var best: int = -1
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.state[i] == EnemyStore.ST_ATTACKING:
			if best < 0 or w.enemies.id[i] < w.enemies.id[best]:
				best = i
	if best >= 0:
		w.kill_enemy(best, DamageSource.Id.WARDEN)


func _run_wave_five(run_seed: int, ticks: int, checkpoints: Array[int]) -> Array[String]:
	var w: SimWorld = NavTestUtil.world(run_seed)
	NavTestUtil.start_wave(w, 5)
	var hashes: Array[String] = []
	for n: int in ticks:
		_cull(w)
		NavTestUtil.advance(w)
		if checkpoints.has(n + 1):
			hashes.append(w.state_hash())
	hashes.append(str(w.events.event_hash))
	return hashes


func test_fifty_mixed_enemies_stay_finite_in_the_grid_and_out_of_props_for_3600_ticks() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.fill_mixed(w, 50)
	assert_int(w.alive_count()).is_equal(50)
	var g: ArenaGrid = w.nav.flow.grid
	var obstacles: Array[ObstacleDef] = w.content.arena.obstacles
	var violations: int = 0
	var first: String = ""
	for n: int in 3600:
		NavTestUtil.advance(w)
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] == 0:
				continue
			var x: float = w.enemies.x[i]
			var z: float = w.enemies.z[i]
			var bad: String = ""
			if not (is_finite(x) and is_finite(z) and is_finite(w.enemies.path_dist[i]) and is_finite(w.enemies.face_x[i])):
				bad = "not finite"
			elif not (x > g.origin_x and x < g.max_x() and z > g.origin_z and z < g.max_z()):
				bad = "outside the grid"
			elif NavGeometry.inside_any(obstacles, x, z, 0.0):
				bad = "inside a prop"
			if bad != "":
				violations += 1
				if first == "":
					first = "tick %d enemy %d at (%f, %f): %s" % [w.tick, w.enemies.id[i], x, z, bad]
	assert_str(first).is_equal("")
	assert_int(violations).is_equal(0)
	assert_int(w.alive_count()).is_equal(50)


func test_fifty_enemies_end_up_attacking_from_fifty_distinct_slots() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.fill_mixed(w, 50)
	NavTestUtil.advance_n(w, 3000)
	var held: Dictionary = {}
	var attackers: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 0:
			continue
		assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
		attackers += 1
		var slot: int = w.enemies.slot[i]
		assert_bool(held.has(slot)).is_false()
		held[slot] = w.enemies.id[i]
		assert_int(w.nav.slots.occupant(slot)).is_equal(w.enemies.id[i])
		var target: Vector2 = w.content.arena.slot_positions[slot]
		assert_float(w.enemies.x[i]).is_equal_approx(target.x, 0.000001)
		assert_float(w.enemies.z[i]).is_equal_approx(target.y, 0.000001)
	assert_int(attackers).is_equal(50)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_REACHED_SLOT)).is_equal(50)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.ENEMY_STUCK)).is_equal(0)
	var occupied: int = 0
	for k: int in 64:
		if w.nav.slots.occupant(k) != 0:
			occupied += 1
	assert_int(occupied).is_equal(50 + 2)


func test_killing_attackers_frees_slots_for_the_next_wave_of_arrivals() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.fill_mixed(w, 50)
	NavTestUtil.advance_n(w, 3000)
	var killed: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and killed < 10 and w.content.enemies[w.enemies.type[i]].slot_span == 1:
			w.kill_enemy(i, DamageSource.Id.WARDEN)
			killed += 1
	assert_int(w.alive_count()).is_equal(40)
	var fresh: Array[int] = []
	for k: int in 10:
		fresh.append(w.spawn_enemy(Ids.EN_SKITTER, 10.8, -6.0 + float(k) * 1.5))
	NavTestUtil.advance_n(w, 1500)
	for i: int in fresh:
		assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)
	assert_int(w.alive_count()).is_equal(50)


func test_two_worlds_with_the_same_seed_stay_identical_for_3600_ticks_of_spawning() -> void:
	var a: Array[String] = _run_wave_five(7, 3600, [1, 900, 1800, 2700, 3600])
	var b: Array[String] = _run_wave_five(7, 3600, [1, 900, 1800, 2700, 3600])
	assert_int(a.size()).is_equal(6)
	assert_array(a).is_equal(b)
	var distinct: Dictionary = {}
	for h: String in a:
		distinct[h] = true
	assert_int(distinct.size()).is_equal(6)


func test_another_seed_gives_another_history() -> void:
	var a: Array[String] = _run_wave_five(7, 1200, [1200])
	var b: Array[String] = _run_wave_five(8, 1200, [1200])
	assert_bool(a[0] != b[0]).is_true()


func test_state_hash_covers_the_nav_state() -> void:
	var w: SimWorld = NavTestUtil.world()
	var h0: String = w.state_hash()
	SpawnSystem.begin_wave(w, 1)
	var h1: String = w.state_hash()
	assert_bool(h0 != h1).is_true()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 0.0, 3.0)
	var h2: String = w.state_hash()
	w.nav.slots.claim(w, i)
	var h3: String = w.state_hash()
	assert_bool(h2 != h3).is_true()
	w.nav.slots.release(w, i)
	NavTestUtil.advance(w)
	var h4: String = w.state_hash()
	assert_bool(h3 != h4).is_true()
	var fresh: NavState = NavState.new()
	var hasher: StateHasher = StateHasher.new()
	fresh.hash_into(hasher)
	assert_int(hasher.finish().length()).is_equal(64)


func test_movement_step_with_fifty_enemies_averages_under_one_millisecond() -> void:
	## Worst case: all fifty enemies start on the spawn edges, so the 300 measured ticks cover the walk in, the crowd
	## converging on the core and the first arrivals. The best of five fresh runs is asserted so a busy machine does
	## not fail the test (ten other checkouts measure on the same machine in wave V4); every run is printed.
	var averages: Array[float] = []
	for run: int in 5:
		var w: SimWorld = NavTestUtil.world()
		NavTestUtil.fill_mixed(w, 50)
		NavTestUtil.advance_n(w, 5)
		var total: int = 0
		for n: int in 300:
			w.tick += 1
			var t0: int = Time.get_ticks_usec()
			MovementSystem.step(w)
			total += Time.get_ticks_usec() - t0
		averages.append(float(total) / 300.0)
		assert_int(w.alive_count()).is_equal(50)
	var best: float = averages[0]
	for value: float in averages:
		best = minf(best, value)
	print("NAV_BENCH MovementSystem.step, 50 enemies, avg us per tick over 300 ticks, 5 runs: %s best=%.1f" % [str(averages), best])
	assert_float(best).is_less(1000.0)
