extends GdUnitTestSuite
## V4-V: the world events that happen at a place: ACCORD DROP (a crate and its squatters), FLOOR BREACH (borers out of the
## ground), RECOUNT (the next 12 scheduled spawns from the other edge) and RUNAWAY FREIGHT (the world's car). Planned in
## wave 4 at offset 1 unless a test says otherwise.


func _planned(event_index: int, wave_act: int = 1) -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, 4)
	w.plan.waves[3].act = wave_act
	w.phase_state.act = wave_act
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, event_index, 1)
	return w


func _is_drop_point(w: SimWorld, x: float, z: float) -> bool:
	for p: Vector2 in w.content.arena.drop_points:
		if absf(p.x - x) < 0.001 and absf(p.y - z) < 0.001:
			return true
	return false


# --- ACCORD DROP ---


func test_a_crate_lands_on_a_drop_point_three_seconds_after_the_warning() -> void:
	var w: SimWorld = _planned(VarietyVKit.DROP)
	VarietyVKit.run(w, 180)  # tick 180, one before the landing
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_int(warned.tick).is_equal(1)
	assert_int(warned.b).is_equal(180)
	assert_bool(_is_drop_point(w, warned.f, warned.g)).is_true()
	assert_bool(w.salvage.crate_active).is_false()
	VarietyVKit.tick(w)  # tick 181
	assert_bool(w.salvage.crate_active).is_true()
	assert_float(w.salvage.crate_x).is_equal(warned.f)  # the crate lands where the warning showed
	assert_float(w.salvage.crate_z).is_equal(warned.g)
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.CRATE_DROPPED)).is_equal([181])
	assert_int(w.salvage.crate_life_left).is_equal(w.content.run.salvage_lifetime_ticks)


func test_the_drop_point_comes_from_the_seed_and_varies() -> void:
	var seen: Dictionary[int, bool] = {}
	for s: int in range(1, 25):
		var w: SimWorld = VarietyVKit.world(s, 4)
		VarietyVKit.clear_plan(w)
		VarietyVKit.plan_event(w, 4, VarietyVKit.DROP, 1)
		VarietyVKit.tick(w)
		var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
		seen[roundi(warned.f * 100.0) * 10000 + roundi(warned.g * 100.0)] = true
		var again: SimWorld = VarietyVKit.world(s, 4)
		VarietyVKit.clear_plan(again)
		VarietyVKit.plan_event(again, 4, VarietyVKit.DROP, 1)
		VarietyVKit.tick(again)
		var twin: SimEvent = VarietyVKit.events_of(again, SimEventKind.Id.EVENT_WARNED)[0]
		assert_float(twin.f).is_equal(warned.f)
		assert_float(twin.g).is_equal(warned.g)
	assert_int(seen.size()).is_greater(1)
	assert_int(seen.size()).is_less_equal(4)


func test_the_three_nearest_skitters_and_rushers_walk_to_the_crate_and_contest_it() -> void:
	var w: SimWorld = _planned(VarietyVKit.DROP)
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	var cx: float = warned.f
	var cz: float = warned.g
	var near_a: int = VarietyVKit.place(w, Ids.EN_SKITTER, cx + 3.0, cz)
	var near_b: int = VarietyVKit.place(w, Ids.EN_RUSHER, cx, cz + 4.0)
	var near_c: int = VarietyVKit.place(w, Ids.EN_SKITTER, cx - 5.0, cz)
	var far: int = VarietyVKit.place(w, Ids.EN_SKITTER, cx, cz - 9.0)
	var heavy: int = VarietyVKit.place(w, Ids.EN_HOLLOW, cx + 2.5, cz)  # nearer than the squatters but not a skitter or rusher
	var attacker: int = VarietyVKit.place(w, Ids.EN_SKITTER, cx + 2.2, cz, EnemyStore.ST_ATTACKING)  # not on the march
	VarietyVKit.run(w, 180)
	assert_int(w.events_state.squat_ids.size()).is_equal(3)
	var ids: Array = Array(w.events_state.squat_ids)
	assert_bool(ids.has(w.enemies.id[near_a]) and ids.has(w.enemies.id[near_b]) and ids.has(w.enemies.id[near_c])).is_true()
	assert_bool(ids.has(w.enemies.id[far]) or ids.has(w.enemies.id[heavy]) or ids.has(w.enemies.id[attacker])).is_false()
	assert_bool(SalvageSystem.is_contested(w)).is_false()  # they are still on their way (3 to 5 m)
	var heavy_x: float = w.enemies.x[heavy]
	VarietyVKit.run(w, 150)  # skitters walk about 2.3 m/s
	for i: int in [near_a, near_b, near_c]:
		var dx: float = w.enemies.x[i] - cx
		var dz: float = w.enemies.z[i] - cz
		assert_float(sqrt(dx * dx + dz * dz)).is_less_equal(0.61)  # on the ring of 0.6 m
	assert_bool(SalvageSystem.is_contested(w)).is_true()
	assert_float(w.enemies.x[heavy]).is_equal(heavy_x)  # the others are left alone
	# the crate is secured only once the squatters are gone
	for i: int in [near_a, near_b, near_c]:
		w.kill_enemy(i, DamageSource.Id.WARDEN)
	w.kill_enemy(heavy, DamageSource.Id.WARDEN)
	assert_bool(SalvageSystem.is_contested(w)).is_false()


func test_stunned_squatters_stop_where_they_are_but_still_contest() -> void:
	var w: SimWorld = _planned(VarietyVKit.DROP)
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	var squatter: int = VarietyVKit.place(w, Ids.EN_SKITTER, warned.f + 1.5, warned.g)
	VarietyVKit.run(w, 180)
	w.enemies.stun_ticks[squatter] = 100000  # the EMP
	var x: float = w.enemies.x[squatter]
	VarietyVKit.run(w, 60)
	assert_float(w.enemies.x[squatter]).is_equal(x)
	assert_bool(SalvageSystem.is_contested(w)).is_true()  # within 2 m of the crate: a stunned enemy still contests


func test_the_squatters_are_released_when_the_crate_is_gone_and_no_second_crate_lands() -> void:
	var w: SimWorld = _planned(VarietyVKit.DROP)
	VarietyVKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	VarietyVKit.run(w, 181)
	assert_int(w.events_state.squat_ids.size()).is_equal(1)
	w.salvage.crate_active = false  # secured or lost
	VarietyVKit.tick(w)
	assert_bool(w.events_state.squat_ids.is_empty()).is_true()
	# a crate already on the field: the drop does nothing
	var busy: SimWorld = _planned(VarietyVKit.DROP)
	assert_bool(SalvageSystem.drop_crate(busy, 0, false)).is_true()
	var ordinal: int = busy.salvage.crate_ordinal
	VarietyVKit.run(busy, 181)
	assert_int(busy.salvage.crate_ordinal).is_equal(ordinal)
	assert_bool(busy.events_state.squat_ids.is_empty()).is_true()


# --- FLOOR BREACH ---


func test_a_breach_in_act_two_opens_two_points_with_three_borers_each() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH, 2)
	VarietyVKit.tick(w)
	var warns: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)
	assert_int(warns.size()).is_equal(2)  # one warning per breach point
	assert_int(warns[0].b).is_equal(150)
	var points: Array[Vector2] = []
	for e: SimEvent in warns:
		var p: Vector2 = Vector2(e.f, e.g)
		assert_bool(w.content.arena.breach_points.has(p)).is_true()
		assert_bool(points.has(p)).is_false()
		points.append(p)
	assert_int(VarietyVKit.alive(w)).is_equal(0)
	VarietyVKit.run(w, 149)  # tick 150
	assert_int(VarietyVKit.alive(w)).is_equal(0)
	VarietyVKit.tick(w)  # tick 151 = 1 + 150
	assert_int(VarietyVKit.alive(w)).is_equal(6)
	for i: int in w.enemies.high_water:
		assert_int(w.enemies.type[i]).is_equal(Ids.EN_BORER)
		var near_a_point: bool = false
		for p: Vector2 in points:
			near_a_point = near_a_point or Vector2(w.enemies.x[i], w.enemies.z[i]).distance_to(p) <= 0.31
		assert_bool(near_a_point).is_true()
	assert_int(w.events_state.breach_mask).is_equal(0)


func _bodied(w: SimWorld) -> int:
	var n: int = 0
	for i: int in w.enemies.high_water:
		n += 1 if w.enemies.alive[i] == 1 and not w.ext.has_flag(i, EnemyExtState.F_MINI) else 0
	return n


## V5-A (scorecard S17): a breach into a full field keeps the bodied cap of SPEC 5.5; its borers wait in the spawn queue.
func test_a_breach_into_a_full_field_queues_its_borers_and_keeps_the_cap() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH, 2)
	VarietyVKit.run(w, 150)  # tick 150, one before the borers
	var cap: int = w.content.mission.enemy_cap
	for type_index: int in [Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER, Ids.EN_BURSTER]:
		var n: int = 0
		while _bodied(w) < cap and w.spawn_enemy(type_index, 9.0, -6.0 + float(n % 12)) >= 0:
			n += 1
	assert_int(_bodied(w)).is_equal(cap)
	VarietyVKit.tick(w)  # tick 151: the breach opens
	assert_int(_bodied(w)).is_less_equal(cap)
	var borers_alive: int = 0
	for i: int in w.enemies.high_water:
		borers_alive += 1 if w.enemies.alive[i] == 1 and w.enemies.type[i] == Ids.EN_BORER else 0
	var borers_queued: int = 0
	for k: int in range(w.nav.pending_head, w.nav.pending.size()):
		borers_queued += 1 if w.nav.sched_type[w.nav.pending[k]] == Ids.EN_BORER else 0
	assert_int(borers_alive + borers_queued).is_equal(6)  # nothing is dropped
	assert_int(borers_queued).is_greater(0)


func test_a_breach_in_act_three_opens_three_points_with_four_borers_each() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH, 3)
	VarietyVKit.run(w, 151)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(3)
	assert_int(VarietyVKit.alive(w)).is_equal(12)


func test_borers_emerge_stunned_while_the_emp_still_runs_and_trip_a_mine_on_the_breach() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH, 2)
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_bool(HazardMines.place(w, warned.f, warned.g, 0)).is_true()
	assert_int(AbilitySystem.activate(w, 5, Ids.AB_EMP)).is_equal(Reason.Id.OK)  # at tick 1; the stun lasts stun_ticks
	var stun: int = w.content.abilities[Ids.AB_EMP].stun_ticks
	VarietyVKit.run(w, 149)  # tick 150
	VarietyVKit.tick(w)  # tick 151: the borers emerge
	var stunned: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.stun_ticks[i] > 0:
			stunned += 1
	assert_int(stunned).is_equal(VarietyVKit.alive(w))  # all of them, if the stun is not over by tick 151
	assert_int(stun).is_greater(151 - 1)  # (the EMP stun of the fixture outlasts the warning)
	assert_int(HazardMines.count(w)).is_equal(0)  # the mine on the breach went off as they came out
	VarietyVKit.run(w, 2)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(1)
	assert_int(VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST)[0].a).is_equal(HazardState.K_MINE)


func test_borers_that_find_no_room_wait_in_the_spawn_queue() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH, 2)
	var cap: int = w.content.enemies[Ids.EN_BORER].alive_cap
	for _n: int in cap:
		VarietyVKit.place(w, Ids.EN_BORER, 9.0, 0.0)
	VarietyVKit.run(w, 151)
	assert_int(VarietyVKit.alive(w)).is_equal(cap)  # the type is full
	assert_int(SpawnSystem.pending_count(w)).is_equal(6)


# --- RECOUNT ---


func _schedule(w: SimWorld, count: int, x: float, z0: float) -> void:
	var nav: NavState = w.nav
	nav.sched_due = PackedInt32Array()
	nav.sched_type = PackedInt32Array()
	nav.sched_group = PackedInt32Array()
	nav.sched_ordinal = PackedInt32Array()
	nav.sched_x = PackedFloat64Array()
	nav.sched_z = PackedFloat64Array()
	for k: int in count:
		nav.sched_due.append(2000 + k * 30)
		nav.sched_type.append(Ids.EN_SKITTER)
		nav.sched_group.append(0)
		nav.sched_ordinal.append(k)
		nav.sched_x.append(x)
		nav.sched_z.append(z0 + float(k) * 0.1)
	nav.sched_next = 0
	nav.wave_begun = 4


func test_a_recount_brings_the_next_twelve_spawns_in_together_from_the_other_edge() -> void:
	var w: SimWorld = _planned(VarietyVKit.RECOUNT, 2)
	_schedule(w, 20, 10.8, -7.0)  # the whole wave comes from the right edge
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_int(warned.b).is_equal(180)
	assert_float(warned.f).is_equal_approx(4.5, 0.001)  # the upper_right edge: x from -1 to 10, z = -16.8
	assert_float(warned.g).is_equal_approx(-16.8, 0.001)
	VarietyVKit.run(w, 179)  # tick 180
	assert_int(w.nav.sched_due[0]).is_equal(2000)
	VarietyVKit.tick(w)  # tick 181
	for k: int in 12:
		assert_int(w.nav.sched_due[k]).is_equal(181)
		assert_float(w.nav.sched_z[k]).is_equal_approx(-16.8, 0.001)
		assert_float(w.nav.sched_x[k]).is_between(-1.0, 10.0)
	assert_int(w.nav.sched_due[12]).is_equal(2000 + 12 * 30)  # the rest of the wave is untouched
	assert_float(w.nav.sched_x[12]).is_equal(10.8)
	var sorted: bool = true
	for k: int in range(1, w.nav.sched_due.size()):
		sorted = sorted and w.nav.sched_due[k - 1] <= w.nav.sched_due[k]
	assert_bool(sorted).is_true()
	# they enter together, at the spawn rate limit of the mission
	var limit: int = w.content.mission.max_spawns_per_tick
	SpawnSystem.step(w)
	assert_int(VarietyVKit.alive(w)).is_equal(limit)
	SpawnSystem.step(w)
	SpawnSystem.step(w)
	assert_int(VarietyVKit.alive(w)).is_equal(12)


func test_a_recount_with_fewer_spawns_left_moves_what_there_is_and_with_none_does_nothing() -> void:
	var few: SimWorld = _planned(VarietyVKit.RECOUNT, 2)
	_schedule(few, 5, 10.8, -7.0)
	VarietyVKit.run(few, 181)
	for k: int in 5:
		assert_int(few.nav.sched_due[k]).is_equal(181)
	var none: SimWorld = _planned(VarietyVKit.RECOUNT, 2)
	_schedule(none, 0, 10.8, 0.0)
	VarietyVKit.run(none, 181)
	assert_int(VarietyVKit.count(none, SimEventKind.Id.EVENT_STARTED)).is_equal(1)


func test_the_other_edge_is_the_one_with_fewer_of_the_next_spawns() -> void:
	var w: SimWorld = _planned(VarietyVKit.RECOUNT, 2)
	_schedule(w, 20, 4.5, -16.8)  # the wave comes from the upper edge: the other edge is the right one
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_float(warned.f).is_equal_approx(10.8, 0.001)


# --- RUNAWAY FREIGHT (the world's car) ---


func test_the_world_freight_takes_the_busier_lane() -> void:
	var w: SimWorld = _planned(VarietyVKit.RUNAWAY)
	var a: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 6.0, 10.4)  # line B holds two ...
	var b: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -2.0, 11.2)
	var c: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, -7.0)  # ... line A one
	for i: int in [a, b, c]:
		VarietyVKit.tough(w, i)
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_int(warned.b).is_equal(240)
	assert_float(warned.g).is_equal(10.5)
	VarietyVKit.run(w, 240 + 72)
	assert_float(VarietyVKit.taken(w, a)).is_equal(700.0)
	assert_float(VarietyVKit.taken(w, b)).is_equal(700.0)
	assert_float(VarietyVKit.taken(w, c)).is_equal(0.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.HAZARD]).is_equal(1400.0)
