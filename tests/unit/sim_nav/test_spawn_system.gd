extends GdUnitTestSuite
## SpawnSystem: schedule, ordering, positions, the 50-enemy cap and the pending queue (GDD 7, ARCH 6.6).


func _spawns(w: SimWorld) -> Array[SimEvent]:
	return NavTestUtil.events_of(w, SimEventKind.Id.ENEMY_SPAWNED)


func _fill_alive(w: SimWorld, n: int) -> void:
	for k: int in n:
		w.spawn_enemy(Ids.EN_SKITTER, -2.0 + float(k % 10) * 0.8, -6.0 + float(k) * 0.25)


func test_wave_one_spawns_sixteen_skitters_every_102_ticks() -> void:
	var w: SimWorld = NavTestUtil.world()
	var t0: int = NavTestUtil.start_wave(w, 1)
	NavTestUtil.advance_n(w, 16 * 102)
	var spawns: Array[SimEvent] = _spawns(w)
	assert_int(spawns.size()).is_equal(16)
	for k: int in 16:
		assert_int(spawns[k].tick - t0).is_equal(k * 102)
		assert_int(spawns[k].b).is_equal(Ids.EN_SKITTER)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()


func test_schedule_is_sorted_by_tick_then_group_then_ordinal() -> void:
	var w: SimWorld = NavTestUtil.world()
	SpawnSystem.begin_wave(w, 5)
	var nav: NavState = w.nav
	assert_int(nav.sched_due.size()).is_equal(103)
	for k: int in range(1, 103):
		var a: int = k - 1
		if nav.sched_due[a] == nav.sched_due[k]:
			if nav.sched_group[a] == nav.sched_group[k]:
				assert_int(nav.sched_ordinal[k]).is_greater(nav.sched_ordinal[a])
			else:
				assert_int(nav.sched_group[k]).is_greater(nav.sched_group[a])
		else:
			assert_int(nav.sched_due[k]).is_greater(nav.sched_due[a])


func test_wave_totals_match_the_data() -> void:
	var expected: Array[int] = [16, 36, 54, 76, 103]
	for wave_index: int in range(1, 6):
		var w: SimWorld = NavTestUtil.world()
		SpawnSystem.begin_wave(w, wave_index)
		assert_int(w.nav.sched_due.size()).is_equal(expected[wave_index - 1])
		assert_int(w.nav.sched_due.size()).is_equal(w.content.waves[wave_index - 1].total_count())


func test_wave_five_spawns_103_enemies_when_there_is_room() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.start_wave(w, 5)
	var guard: int = 0
	while not SpawnSystem.is_wave_fully_spawned(w) and guard < 5000:
		NavTestUtil.kill_all(w)
		NavTestUtil.advance(w)
		guard += 1
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()
	var by_type: Array[int] = [0, 0, 0, 0]
	for e: SimEvent in _spawns(w):
		by_type[e.b] += 1
	assert_int(_spawns(w).size()).is_equal(103)
	assert_int(by_type[Ids.EN_SKITTER]).is_equal(72)
	assert_int(by_type[Ids.EN_RUSHER]).is_equal(20)
	assert_int(by_type[Ids.EN_HOLLOW]).is_equal(10)
	assert_int(by_type[Ids.EN_HULK]).is_equal(1)
	assert_int(NavTestUtil.count_events(w, SimEventKind.Id.BOSS_SPAWNED)).is_equal(1)


func test_same_tick_order_is_tick_then_group_then_ordinal() -> void:
	var content: ContentSet = TestContent.baseline()
	var groups: Array[SpawnGroupDef] = [
		NavTestUtil.group(Ids.EN_SKITTER, 3, 0, 2, &"right"),
		NavTestUtil.group(Ids.EN_HOLLOW, 3, 1, 2, &"right"),
		NavTestUtil.group(Ids.EN_RUSHER, 2, 2, 2, &"upper_right"),
	]
	NavTestUtil.set_groups(content, 1, groups)
	var w: SimWorld = NavTestUtil.world_with(content)
	var t0: int = NavTestUtil.start_wave(w, 1)
	NavTestUtil.advance_n(w, 10)
	var seq: Array[int] = []
	var ticks: Array[int] = []
	for e: SimEvent in _spawns(w):
		seq.append(e.b)
		ticks.append(e.tick - t0)
	# tick 0: A0; 1: B0; 2: A1, C0 (group order); 3: B1; 4: A2, C1; 5: B2
	assert_array(seq).is_equal(
		[Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_SKITTER, Ids.EN_RUSHER, Ids.EN_HOLLOW, Ids.EN_SKITTER, Ids.EN_RUSHER, Ids.EN_HOLLOW]
	)
	assert_array(ticks).is_equal([0, 1, 2, 2, 3, 4, 4, 5])


func test_ordinals_of_one_group_on_one_tick_keep_their_order() -> void:
	var content: ContentSet = TestContent.baseline()
	var groups: Array[SpawnGroupDef] = [NavTestUtil.group(Ids.EN_SKITTER, 4, 0, 0, &"right")]
	NavTestUtil.set_groups(content, 1, groups)
	var w: SimWorld = NavTestUtil.world_with(content)
	NavTestUtil.start_wave(w, 1)
	assert_int(w.nav.sched_ordinal.size()).is_equal(4)
	for k: int in 4:
		assert_int(w.nav.sched_ordinal[k]).is_equal(k)
	assert_int(_spawns(w).size()).is_equal(4)


func test_enemy_ids_are_strictly_increasing_in_spawn_order() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.start_wave(w, 2)
	for n: int in 1200:
		if n % 7 == 0:
			NavTestUtil.kill_all(w)
		NavTestUtil.advance(w)
	var last: int = 0
	var count: int = 0
	for e: SimEvent in _spawns(w):
		assert_int(e.a).is_greater(last)
		last = e.a
		count += 1
	assert_int(count).is_greater(20)


func test_spawn_positions_lie_on_the_region_segment_with_the_stratified_step() -> void:
	var w: SimWorld = NavTestUtil.world()
	NavTestUtil.start_wave(w, 2)
	NavTestUtil.advance_n(w, 1950)
	var right_k: int = 0
	var upper_k: int = 0
	for e: SimEvent in _spawns(w):
		var expected_t: float
		var t: float
		if e.b == Ids.EN_SKITTER:
			assert_float(e.f).is_equal(10.8)
			assert_float(e.g).is_between(-8.0, 9.0)
			t = (e.g + 8.0) / 17.0
			expected_t = fposmod(float(right_k) * 0.618034, 1.0)
			right_k += 1
		else:
			assert_float(e.g).is_equal(-16.8)
			assert_float(e.f).is_between(-1.0, 10.0)
			t = (e.f + 1.0) / 11.0
			expected_t = fposmod(float(upper_k) * 0.618034, 1.0)
			upper_k += 1
		var diff: float = absf(t - expected_t)
		diff = minf(diff, 1.0 - diff)
		assert_float(diff).is_less_equal(0.08 + 0.000001)
	assert_int(right_k).is_equal(30)
	assert_int(upper_k).is_equal(6)


func test_same_seed_gives_the_same_positions_and_another_seed_differs() -> void:
	var runs: Array[Array] = []
	for run_seed: int in [5, 5, 6]:
		var w: SimWorld = NavTestUtil.world(run_seed)
		NavTestUtil.start_wave(w, 2)
		NavTestUtil.advance_n(w, 700)
		var pts: Array[Vector2] = []
		for e: SimEvent in _spawns(w):
			pts.append(Vector2(e.f, e.g))
		runs.append(pts)
	assert_int(runs[0].size()).is_greater(8)
	assert_array(runs[0]).is_equal(runs[1])
	assert_int(runs[2].size()).is_equal(runs[0].size())
	assert_bool(runs[2] != runs[0]).is_true()


func test_a_full_arena_queues_spawns_and_drains_them_first_in_first_out() -> void:
	var content: ContentSet = TestContent.baseline()
	var groups: Array[SpawnGroupDef] = [NavTestUtil.group(Ids.EN_SKITTER, 10, 0, 1, &"right")]
	NavTestUtil.set_groups(content, 1, groups)
	var w: SimWorld = NavTestUtil.world_with(content)
	_fill_alive(w, 50)
	assert_int(w.alive_count()).is_equal(50)
	NavTestUtil.start_wave(w, 1)
	NavTestUtil.advance_n(w, 20)
	assert_int(w.alive_count()).is_equal(50)
	assert_int(w.next_enemy_id).is_equal(51)
	assert_int(SpawnSystem.pending_count(w)).is_equal(10)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	var queued: Array[SimEvent] = NavTestUtil.events_of(w, SimEventKind.Id.SPAWN_QUEUED)
	assert_int(queued.size()).is_equal(10)
	for k: int in 10:
		assert_int(queued[k].a).is_equal(k + 1)
	assert_int(w.stats.max_pending).is_equal(10)
	var before: int = _spawns(w).size()
	for k: int in 3:
		w.kill_enemy(w.enemies.index_of(1 + k), DamageSource.Id.WARDEN)
	NavTestUtil.advance(w)
	assert_int(_spawns(w).size() - before).is_equal(3)
	assert_int(SpawnSystem.pending_count(w)).is_equal(7)
	assert_int(w.alive_count()).is_equal(50)
	var all: Array[SimEvent] = _spawns(w)
	for k: int in 3:
		assert_float(all[before + k].f).is_equal(w.nav.sched_x[k])
		assert_float(all[before + k].g).is_equal(w.nav.sched_z[k])
	NavTestUtil.kill_all(w)
	NavTestUtil.advance_n(w, 3)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()
	assert_int(w.next_enemy_id).is_equal(61)


func test_spawned_pending_and_unscheduled_always_add_up_to_the_wave() -> void:
	var content: ContentSet = TestContent.baseline()
	var groups: Array[SpawnGroupDef] = [
		NavTestUtil.group(Ids.EN_SKITTER, 25, 0, 2, &"right"), NavTestUtil.group(Ids.EN_RUSHER, 15, 5, 3, &"upper_right")
	]
	NavTestUtil.set_groups(content, 1, groups)
	var w: SimWorld = NavTestUtil.world_with(content)
	_fill_alive(w, 44)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	NavTestUtil.start_wave(w, 1)
	var saw_queue: bool = false
	for n: int in 400:
		if rng.randi_range(0, 9) == 0:
			var victim: int = rng.randi_range(0, w.enemies.high_water - 1)
			w.kill_enemy(victim, DamageSource.Id.WARDEN)
		NavTestUtil.advance(w)
		var spawned: int = w.next_enemy_id - 1 - 44
		var unscheduled: int = w.nav.sched_due.size() - w.nav.sched_next
		assert_int(spawned + SpawnSystem.pending_count(w) + unscheduled).is_equal(40)
		assert_int(w.alive_count()).is_less_equal(50)
		saw_queue = saw_queue or SpawnSystem.pending_count(w) > 0
	assert_bool(saw_queue).is_true()


func test_at_most_four_spawns_happen_per_tick() -> void:
	var content: ContentSet = TestContent.baseline()
	var groups: Array[SpawnGroupDef] = [NavTestUtil.group(Ids.EN_SKITTER, 9, 0, 0, &"right")]
	NavTestUtil.set_groups(content, 1, groups)
	var w: SimWorld = NavTestUtil.world_with(content)
	var t0: int = NavTestUtil.start_wave(w, 1)
	assert_int(w.content.mission.max_spawns_per_tick).is_equal(4)
	assert_int(_spawns(w).size()).is_equal(4)
	assert_int(SpawnSystem.pending_count(w)).is_equal(5)
	NavTestUtil.advance(w)
	assert_int(_spawns(w).size()).is_equal(8)
	NavTestUtil.advance(w)
	assert_int(_spawns(w).size()).is_equal(9)
	assert_int(_spawns(w)[8].tick - t0).is_equal(2)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()


func test_a_new_wave_replaces_the_schedule_and_bad_indexes_are_ignored() -> void:
	var w: SimWorld = NavTestUtil.world()
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	SpawnSystem.begin_wave(w, 0)
	SpawnSystem.begin_wave(w, 6)
	assert_int(w.nav.sched_due.size()).is_equal(0)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	SpawnSystem.begin_wave(w, 3)
	assert_int(w.nav.sched_due.size()).is_equal(54)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	SpawnSystem.begin_wave(w, 1)
	assert_int(w.nav.sched_due.size()).is_equal(16)
	assert_int(w.nav.sched_next).is_equal(0)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
