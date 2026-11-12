extends GdUnitTestSuite
## V2-C: the Deadfall Strike, the first user of delayed hits (VARIETY_SPEC 7.1; CONTENT 6), and the densest-cluster
## query it aims with. 450 damage within 4 m, half at the edge, armor ignored, bosses take half; it lands 120 ticks
## after the call on the place picked at the call. Charges: 1 at the start, cap 3.
## EventSystem is not a file of this task, so the tests drive the `sys_*` functions of the event file directly.

const STRIKE: int = 0  # the index of deadfall_strike in the fixture's events.json


func _world() -> SimWorld:
	var w: SimWorld = VarietyCKit.world()
	EventDeadfallStrike.sys_init(w)
	return w


## The call as the command applies it: at the start of the next tick, before the event and hazard steps.
func _call_on_next_tick(w: SimWorld) -> int:
	VarietyCKit.begin_tick(w)
	var reason: int = EventDeadfallStrike.sys_call(w, 1000 + w.tick, STRIKE)
	EventDeadfallStrike.sys_step(w)
	HazardSystem.step(w)
	return reason


func test_the_densest_cluster_is_the_enemy_with_the_most_neighbours() -> void:
	var w: SimWorld = VarietyCKit.world()
	VarietyCKit.place(w, Ids.EN_SKITTER, -5.0, -5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, -5.5, -5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 7.0, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 3.0, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 9.0, -9.0)
	# radius 2.5: only the enemy at (5, 5) has both neighbours inside
	assert_vector(AreaDamage.densest_cluster(w, 0.0, 0.0, 0.0, 100.0, 2.5)).is_equal(Vector2(5.0, 5.0))
	# radius 1: the pair on the left is the densest
	assert_vector(AreaDamage.densest_cluster(w, 0.0, 0.0, 0.0, 100.0, 1.0)).is_equal(Vector2(-5.0, -5.0))


func test_cluster_ties_go_to_the_best_ranked_enemy_and_the_range_limits_the_centres() -> void:
	var w: SimWorld = VarietyCKit.world()
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.5, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, -5.0, -5.0)
	var attacker: int = VarietyCKit.place(w, Ids.EN_SKITTER, -5.5, -5.0)
	assert_vector(AreaDamage.densest_cluster(w, 0.0, 0.0, 0.0, 100.0, 1.0)).is_equal(Vector2(5.0, 5.0))  # lower id
	w.enemies.state[attacker] = EnemyStore.ST_ATTACKING  # the second pair now holds the best-ranked enemy
	assert_vector(AreaDamage.densest_cluster(w, 0.0, 0.0, 0.0, 100.0, 1.0)).is_equal(Vector2(-5.0, -5.0))
	# centres must lie between the two ranges of the shooter at (-5, -5)
	assert_vector(AreaDamage.densest_cluster(w, -5.0, -5.0, 6.0, 100.0, 1.0)).is_equal(Vector2(5.0, 5.0))
	assert_vector(AreaDamage.densest_cluster(w, -5.0, -5.0, 0.0, 3.0, 1.0)).is_equal(Vector2(-5.0, -5.0))
	assert_vector(AreaDamage.densest_cluster(w, -5.0, -5.0, 1.0, 3.0, 1.0)).is_equal(Vector2(-5.0, -5.0))  # no enemy: the shooter
	assert_vector(AreaDamage.densest_cluster(VarietyCKit.world(), 2.0, 3.0, 0.0, 100.0, 4.0)).is_equal(Vector2(2.0, 3.0))


func test_charges_start_at_one_and_stop_at_the_cap() -> void:
	var w: SimWorld = _world()
	assert_int(w.events_state.charges_of(STRIKE)).is_equal(1)
	EventDeadfallStrike.sys_grant(w, STRIKE, 1)  # an act start
	assert_int(w.events_state.charges_of(STRIKE)).is_equal(2)
	EventDeadfallStrike.sys_grant(w, STRIKE, 5)
	assert_int(w.events_state.charges_of(STRIKE)).is_equal(3)
	EventDeadfallStrike.sys_grant(w, STRIKE, 1)  # at the cap: nothing changes, nothing is reported
	var changed: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CHARGES_CHANGED)
	assert_int(changed.size()).is_equal(2)
	assert_int(changed[1].a).is_equal(STRIKE)
	assert_int(changed[1].b).is_equal(3)
	EventDeadfallStrike.sys_grant(w, 99, 1)


func test_the_call_is_refused_outside_a_wave_without_enemies_and_without_charges() -> void:
	var w: SimWorld = _world()
	assert_int(EventDeadfallStrike.sys_block_reason(w, 99)).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(EventDeadfallStrike.sys_block_reason(w, -1)).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(EventDeadfallStrike.sys_call(w, 1, STRIKE)).is_equal(Reason.Id.WRONG_STATE)  # nothing on the field
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 5.0)
	w.phase = GameState.Id.INTERMISSION
	assert_int(EventDeadfallStrike.sys_call(w, 2, STRIKE)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(w.events_state.charges_of(STRIKE)).is_equal(1)  # a refusal costs nothing
	assert_int(w.events_state.active_count()).is_equal(0)
	w.phase = GameState.Id.CLEARING
	assert_int(EventDeadfallStrike.sys_call(w, 3, STRIKE)).is_equal(Reason.Id.OK)
	assert_int(EventDeadfallStrike.sys_call(w, 4, STRIKE)).is_equal(Reason.Id.NO_CHARGES)
	assert_int(w.events_state.active_count()).is_equal(1)


func test_the_call_warns_and_launches_and_the_strike_lands_120_ticks_later() -> void:
	var w: SimWorld = _world()
	var centre: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 5.0, 5.0)
	var mid: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 7.0, 5.0)
	var edge: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 5.0, 1.0)
	var outside: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 5.0, 9.5)
	var boss: int = VarietyCKit.place(w, Ids.EN_HULK, 4.0, 5.0)
	for i: int in [centre, mid, edge, outside, boss]:
		VarietyCKit.tough(w, i)
	for _n: int in 9:
		VarietyCKit.strike_tick(w)
	assert_int(_call_on_next_tick(w)).is_equal(Reason.Id.OK)  # tick 10
	assert_int(w.events_state.charges_of(STRIKE)).is_equal(0)
	assert_int(w.events_state.used_this_wave[STRIKE]).is_equal(1)
	var warned: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.EVENT_WARNED)
	assert_int(warned.size()).is_equal(1)
	assert_int(warned[0].a).is_equal(STRIKE)
	assert_int(warned[0].b).is_equal(120)
	assert_float(warned[0].f).is_equal(5.0)
	assert_float(warned[0].g).is_equal(5.0)
	var launched: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)
	assert_int(launched[0].a).is_equal(HazardState.K_STRIKE)
	assert_int(launched[0].b).is_equal(120)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.CHARGES_CHANGED)[0].b).is_equal(0)
	for _n: int in 119:
		VarietyCKit.strike_tick(w)  # tick 129
	assert_float(VarietyCKit.taken(w, centre)).is_equal(0.0)
	assert_int(w.events_state.active_count()).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.EVENT_STARTED)).is_equal(0)
	VarietyCKit.strike_tick(w)  # tick 130 = 10 + 120
	assert_float(VarietyCKit.taken(w, centre)).is_equal(450.0)  # armor 8 is ignored
	assert_float(VarietyCKit.taken(w, mid)).is_equal(337.5)  # half way out: 75%
	assert_float(VarietyCKit.taken(w, edge)).is_equal(225.0)  # the edge: 50%
	assert_float(VarietyCKit.taken(w, outside)).is_equal(0.0)
	assert_float(VarietyCKit.taken(w, boss)).is_equal(196.875)  # 1 m out: 87.5%, and a boss takes half
	assert_float(w.combat.damage_by_source[DamageSource.Id.STRIKE]).is_equal(450.0 + 337.5 + 225.0 + 196.875)
	var blasts: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	assert_int(blasts.size()).is_equal(1)
	assert_int(blasts[0].tick).is_equal(130)
	assert_int(blasts[0].a).is_equal(HazardState.K_STRIKE)
	assert_int(blasts[0].b).is_equal(400)
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([130])
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.EVENT_ENDED)).is_equal([130])
	assert_int(w.events_state.active_count()).is_equal(0)
	assert_int(w.stats.events_seen[STRIKE]).is_equal(1)


func test_the_strike_does_not_track_and_its_kills_pay_scrap_once() -> void:
	var w: SimWorld = _world()
	var runner: int = VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 5.0)
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.5, 5.0)
	var slow: int = VarietyCKit.place(w, Ids.EN_SKITTER, 4.5, 5.0)
	assert_int(_call_on_next_tick(w)).is_equal(Reason.Id.OK)
	assert_float(w.events_state.a_x[0]).is_equal(5.0)
	w.enemies.x[runner] = -9.0  # it walks out of the circle during the warning
	w.enemies.z[runner] = -9.0
	for _n: int in 120:
		VarietyCKit.strike_tick(w)
	assert_int(w.enemies.alive[runner]).is_equal(1)
	assert_float(w.enemies.hp[runner]).is_equal(45.0)
	assert_int(w.enemies.alive[slow]).is_equal(0)
	assert_int(w.alive_count()).is_equal(1)
	assert_int(w.scrap).is_equal(2 * w.content.enemies[Ids.EN_SKITTER].scrap)
	assert_int(w.combat.kills_by_source[DamageSource.Id.STRIKE]).is_equal(2)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(2)


func test_overpressure_widens_the_strike() -> void:
	var w: SimWorld = _world()
	w.mods.area_mul = 1.35
	var rim: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 5.0, 5.0)
	var beyond: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 10.0, 5.0)  # 5 m from the centre: inside 5.4 m
	VarietyCKit.place(w, Ids.EN_HOLLOW, 5.2, 5.0)
	VarietyCKit.tough(w, rim)
	VarietyCKit.tough(w, beyond)
	_call_on_next_tick(w)
	for _n: int in 120:
		VarietyCKit.strike_tick(w)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST)[0].b).is_equal(540)
	assert_float(VarietyCKit.taken(w, beyond)).is_greater(225.0)


func test_the_event_file_is_reached_through_the_dispatcher_and_ignores_the_other_stages() -> void:
	var w: SimWorld = _world()
	VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 5.0)
	w.events_state.a_event.append(STRIKE)
	w.events_state.a_phase.append(EventState.PH_WARN)
	w.events_state.a_ticks_left.append(121)
	w.events_state.a_x.append(0.0)
	w.events_state.a_z.append(0.0)
	EventSystem.dispatch(w, 0, EventSystem.Stage.START)
	EventSystem.dispatch(w, 0, EventSystem.Stage.TICK)
	EventSystem.dispatch(w, 0, EventSystem.Stage.FINISH)
	assert_int(w.hazards.queued()).is_equal(0)
	EventSystem.dispatch(w, 0, EventSystem.Stage.WARN)
	assert_int(w.hazards.queued()).is_equal(1)
	assert_int(w.hazards.q_kind[0]).is_equal(HazardState.K_STRIKE)
	assert_int(w.hazards.q_source[0]).is_equal(DamageSource.Id.STRIKE)
	assert_float(w.hazards.q_damage[0]).is_equal(450.0)
	assert_float(w.hazards.q_radius[0]).is_equal(4.0)
	assert_float(w.hazards.q_edge[0]).is_equal(0.5)
	assert_float(w.events_state.a_x[0]).is_equal(5.0)
