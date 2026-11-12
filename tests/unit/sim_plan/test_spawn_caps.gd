extends GdUnitTestSuite
## V2-A: SpawnSystem on a generated run (VARIETY_SPEC 5.5): the chosen option is what spawns, the four caps, and the FIFO
## queue that keeps every blocked body in order and never drops one.


func _alive_of(w: SimWorld, type_index: int) -> int:
	var n: int = 0
	for i: int in w.enemies.high_water:
		n += 1 if w.enemies.alive[i] == 1 and w.enemies.type[i] == type_index else 0
	return n


func _kill_type(w: SimWorld, type_index: int, how_many: int) -> void:
	var done: int = 0
	for i: int in w.enemies.high_water:
		if done < how_many and w.enemies.alive[i] == 1 and w.enemies.type[i] == type_index:
			w.kill_enemy(i, DamageSource.Id.WARDEN)
			done += 1


func test_begin_wave_schedules_the_option_that_was_chosen() -> void:
	for pick: int in [0, 1]:
		var w: SimWorld = VarietyAKit.world(4)
		w.plan.chosen[1] = pick
		SpawnSystem.begin_wave(w, 2)
		var option: RouteOption = w.plan.wave(2).options[pick]
		assert_int(w.nav.sched_due.size()).is_equal(option.total_count())
		assert_int(w.nav.wave_begun).is_equal(2)
		var per_type: Dictionary[int, int] = {}
		for t: int in w.nav.sched_type:
			per_type[t] = per_type.get(t, 0) + 1
		for g: SpawnGroupDef in option.groups:
			assert_int(per_type[g.enemy_index]).is_equal(g.count)


func test_begin_wave_ignores_a_wave_the_plan_does_not_have() -> void:
	var w: SimWorld = VarietyAKit.world()
	SpawnSystem.begin_wave(w, 6)
	SpawnSystem.begin_wave(w, 0)
	assert_int(w.nav.wave_begun).is_equal(0)
	assert_int(w.nav.sched_due.size()).is_equal(0)


func test_a_full_yard_queues_the_rest_in_order_and_drops_nothing() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_SKITTER, 70, 0, 0, &"right")])
	VarietyAKit.tick_spawn(w, 60)
	assert_int(w.alive_count()).is_equal(50)  # enemy_cap
	assert_int(SpawnSystem.pending_count(w)).is_equal(20)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	assert_int(w.stats.max_pending).is_greater_equal(20)
	_kill_type(w, Ids.EN_SKITTER, 10)
	VarietyAKit.tick_spawn(w, 10)
	assert_int(w.alive_count()).is_equal(50)
	assert_int(SpawnSystem.pending_count(w)).is_equal(10)
	_kill_type(w, Ids.EN_SKITTER, 30)
	VarietyAKit.tick_spawn(w, 30)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()
	assert_int(w.next_enemy_id - 1).is_equal(70)  # every scheduled body entered exactly once


func _x_of_id(w: SimWorld, enemy_id: int) -> float:
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.id[i] == enemy_id:
			return w.enemies.x[i]
	return NAN


func test_the_queue_is_first_in_first_out_by_schedule_order() -> void:
	var w: SimWorld = VarietyAKit.world()
	var groups: Array[SpawnGroupDef] = [VarietyAKit.group(Ids.EN_SKITTER, 60, 0, 0, &"right")]
	VarietyAKit.start_wave(w, groups)
	VarietyAKit.tick_spawn(w, 30)
	var first_pending: int = w.nav.pending[w.nav.pending_head]
	assert_int(first_pending).is_equal(50)
	_kill_type(w, Ids.EN_SKITTER, 3)
	VarietyAKit.tick_spawn(w, 3)
	assert_int(w.nav.pending[w.nav.pending_head]).is_equal(first_pending + 3)  # the three oldest waiting entries went first
	for k: int in 3:
		assert_float(_x_of_id(w, 51 + k)).is_equal(w.nav.sched_x[first_pending + k])


func test_minis_do_not_wait_behind_bodies_and_do_not_use_their_room() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [
		VarietyAKit.group(Ids.EN_SKITTER, 60, 0, 0, &"right"),
		VarietyAKit.group(Ids.EN_MOTE, 30, 20, 0, &"upper_right"),
	])
	VarietyAKit.tick_spawn(w, 80)
	assert_int(_alive_of(w, Ids.EN_SKITTER)).is_equal(50)
	assert_int(_alive_of(w, Ids.EN_MOTE)).is_equal(30)  # the queue holds 10 skitters ahead of them and they still entered
	assert_int(w.alive_count()).is_equal(80)  # 50 bodied + 30 minis
	assert_int(SpawnSystem.pending_count(w)).is_equal(10)


func test_the_swarm_cap_holds_minis_in_the_queue() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_MOTE, 52, 0, 0, &"right")])
	VarietyAKit.tick_spawn(w, 40)
	assert_int(_alive_of(w, Ids.EN_MOTE)).is_equal(40)  # swarm_cap
	assert_int(SpawnSystem.pending_count(w)).is_equal(12)
	var head: int = w.nav.pending[w.nav.pending_head]
	_kill_type(w, Ids.EN_MOTE, 5)
	VarietyAKit.tick_spawn(w, 5)
	assert_int(_alive_of(w, Ids.EN_MOTE)).is_equal(40)
	assert_int(w.nav.pending[w.nav.pending_head]).is_equal(head + 5)
	_kill_type(w, Ids.EN_MOTE, 40)
	VarietyAKit.tick_spawn(w, 20)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
	assert_int(w.next_enemy_id - 1).is_equal(52)


func test_the_type_cap_holds_one_type_while_others_enter() -> void:
	var w: SimWorld = VarietyAKit.world()
	var cap: int = w.content.enemies[Ids.EN_BURSTER].alive_cap
	VarietyAKit.start_wave(w, [
		VarietyAKit.group(Ids.EN_BURSTER, cap + 5, 0, 0, &"right"),
		VarietyAKit.group(Ids.EN_SKITTER, 10, 3, 0, &"right"),
	])
	VarietyAKit.tick_spawn(w, 60)
	assert_int(_alive_of(w, Ids.EN_BURSTER)).is_equal(cap)
	assert_int(_alive_of(w, Ids.EN_SKITTER)).is_equal(10)
	assert_int(SpawnSystem.pending_count(w)).is_equal(5)
	_kill_type(w, Ids.EN_BURSTER, 2)
	VarietyAKit.tick_spawn(w, 5)
	assert_int(_alive_of(w, Ids.EN_BURSTER)).is_equal(cap)
	assert_int(SpawnSystem.pending_count(w)).is_equal(3)


func test_elites_stop_at_the_elite_cap_and_the_rest_wait() -> void:
	var w: SimWorld = VarietyAKit.world()
	var elites: Array[PlannedElite] = []
	for k: int in 6:
		var e: PlannedElite = PlannedElite.new()
		e.group = 0
		e.ordinal = k
		e.affix_mask = 1
		elites.append(e)
	w.plan.waves[0].options[0].elites = elites
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_SKITTER, 10, 0, 0, &"right")])
	VarietyAKit.tick_spawn(w, 30)
	assert_int(EliteSystem.alive_elites(w)).is_equal(w.content.run.max_elites_alive)
	assert_int(w.alive_count()).is_equal(8)  # 4 elites and the 4 normal bodies; the 2 elites that did not fit wait
	assert_int(SpawnSystem.pending_count(w)).is_equal(2)
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.ext.is_elite(i):
			w.kill_enemy(i, DamageSource.Id.WARDEN)
			break
	VarietyAKit.tick_spawn(w, 5)
	assert_int(SpawnSystem.pending_count(w)).is_equal(1)
	assert_int(EliteSystem.alive_elites(w)).is_equal(w.content.run.max_elites_alive)


func test_at_most_the_per_tick_limit_enters_in_one_tick() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_SKITTER, 30, 0, 0, &"right")])
	var limit: int = w.content.mission.max_spawns_per_tick
	assert_int(w.alive_count()).is_less_equal(limit)
	var before: int = w.alive_count()
	VarietyAKit.tick_spawn(w, 1)
	assert_int(w.alive_count() - before).is_less_equal(limit)


func test_a_split_body_joins_the_queue_at_its_death_position_and_waits_for_room() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_MOTE, 40, 0, 0, &"right")])
	VarietyAKit.tick_spawn(w, 40)
	assert_int(_alive_of(w, Ids.EN_MOTE)).is_equal(40)
	SpawnSystem.enqueue(w, Ids.EN_SHARD, -3.5, 1.25)
	SpawnSystem.enqueue(w, Ids.EN_SHARD, -3.0, 1.5)
	assert_int(SpawnSystem.pending_count(w)).is_equal(2)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_false()
	VarietyAKit.tick_spawn(w, 10)
	assert_int(_alive_of(w, Ids.EN_SHARD)).is_equal(0)  # the swarm cap is full: nothing is lost, nothing enters
	_kill_type(w, Ids.EN_MOTE, 1)
	VarietyAKit.tick_spawn(w, 2)
	assert_int(_alive_of(w, Ids.EN_SHARD)).is_equal(1)
	var shard: int = -1
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.type[i] == Ids.EN_SHARD:
			shard = i
	assert_float(w.enemies.x[shard]).is_equal(-3.5)  # the first to be queued is the first to enter
	assert_float(w.enemies.z[shard]).is_equal(1.25)
	_kill_type(w, Ids.EN_MOTE, 1)
	VarietyAKit.tick_spawn(w, 2)
	assert_int(_alive_of(w, Ids.EN_SHARD)).is_equal(2)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()


func test_an_enqueued_body_does_not_disturb_the_rest_of_the_schedule() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_SKITTER, 10, 0, 30, &"right")])
	var due_before: PackedInt32Array = w.nav.sched_due.duplicate()
	SpawnSystem.enqueue(w, Ids.EN_SHARD, 1.0, 1.0)
	assert_int(w.nav.sched_due.size()).is_equal(due_before.size() + 1)
	VarietyAKit.tick_spawn(w, 400)
	assert_int(_alive_of(w, Ids.EN_SKITTER)).is_equal(10)  # all ten still enter, once each
	assert_int(_alive_of(w, Ids.EN_SHARD)).is_equal(1)
	assert_bool(SpawnSystem.is_wave_fully_spawned(w)).is_true()


func test_breach_groups_enter_at_the_arena_breach_points() -> void:
	var w: SimWorld = VarietyAKit.world()
	VarietyAKit.start_wave(w, [VarietyAKit.group(Ids.EN_BORER, 12, 0, 5, &"breach")])
	var points: PackedVector2Array = w.content.arena.breach_points
	assert_int(points.size()).is_greater(0)
	for k: int in w.nav.sched_x.size():
		var at: Vector2 = Vector2(w.nav.sched_x[k], w.nav.sched_z[k])
		assert_bool(points.has(at)).override_failure_message("entry %d is not at a breach point" % k).is_true()


func test_the_legacy_queue_is_still_strict_first_in_first_out() -> void:
	# The baseline content has no run: the old loop stays, one cap on everything alive.
	var w: SimWorld = TestContent.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 5
	w.tick += 1
	SpawnSystem.begin_wave(w, 5)
	var waited: bool = false
	for _k: int in 3000:
		w.tick += 1
		SpawnSystem.step(w)
		assert_int(w.alive_count()).is_less_equal(w.content.mission.enemy_cap)
		if SpawnSystem.pending_count(w) > 0 and w.alive_count() == w.content.mission.enemy_cap:
			waited = true
	assert_bool(waited).is_true()
