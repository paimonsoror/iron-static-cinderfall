extends GdUnitTestSuite
## V4-V (B07): the interaction table of VARIETY_SPEC 7.4 / GDD 7b, row by row. Where a row is an exact rule of another
## suite of this task, the test here states the row and checks it on the same footing; rows that belong to a boss script
## (Tremor Rig stomp, Lance Platform beam) are covered from the event side only: the hooks they use are
## EventSystem.take_turrets_offline and the Static Front lock.


func _world() -> SimWorld:
	return VarietyVKit.world(1, 4)


func _planned(event_index: int) -> SimWorld:
	var w: SimWorld = _world()
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, event_index, 1)
	return w


# --- STATIC FRONT: EMP locked | Shield locked (an active shield continues) | Overdrive locked (active continues) ---


func test_static_front_emp_shield_and_overdrive_are_locked_and_an_active_one_continues() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	VarietyVKit.run(w, 100)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)  # active when the front starts at 361
	VarietyVKit.run(w, 261)
	assert_bool(EventRates.lock_active(w)).is_true()
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_true()
	for a: int in 3:
		assert_int(AbilitySystem.activate(w, 10 + a, a)).is_equal(Reason.Id.ALREADY_ACTIVE if a == Ids.AB_OVERDRIVE else Reason.Id.LOCKED_BY_EVENT)
	var left: int = w.abilities.active_left[Ids.AB_OVERDRIVE]
	VarietyVKit.run(w, left)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_false()  # it ran to its end under the front


# --- CORE SURGE: reload and vent instant (Overdrive wastes nothing); turrets x2 then offline 5 s; the pad ---


func test_core_surge_marks_the_window_in_which_reload_and_vent_are_instant() -> void:
	var w: SimWorld = _planned(VarietyVKit.SURGE)
	VarietyVKit.run(w, 240)
	assert_bool(EventSystem.surge_active(w)).is_false()
	VarietyVKit.tick(w)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_bool(EventSystem.surge_active(w)).is_true()  # ArsenalSystem asks this on every reload and vent
	VarietyVKit.run(w, 599)
	assert_bool(EventSystem.surge_active(w)).is_true()
	VarietyVKit.tick(w)
	assert_bool(EventSystem.surge_active(w)).is_false()


# --- RUNAWAY FREIGHT: lines never cross a pad; line B passes 3.5 m below the Warden ---


func test_runaway_freight_lanes_never_cross_a_pad_and_line_b_passes_3_5_m_from_the_warden() -> void:
	var w: SimWorld = _world()
	var arena: ArenaDef = w.content.arena
	assert_int(arena.rail_z.size()).is_equal(2)
	for line: int in 2:
		for pad: Vector2 in arena.turret_pads:
			assert_float(absf(pad.y - arena.rail_z[line])).is_greater(arena.rail_half_width[line])
		assert_float(absf(arena.core_z - arena.rail_z[line])).is_greater(arena.rail_half_width[line] + arena.core_radius)
	assert_float(absf(arena.rail_z[1] - arena.warden_z)).is_equal(3.5)
	assert_float(absf(arena.rail_z[1] - arena.warden_z)).is_greater(arena.rail_half_width[1])  # only wind reaches the Warden
	assert_float(arena.rail_z[0]).is_equal(-7.0)
	assert_float(arena.rail_z[1]).is_equal(10.5)


# --- ACCORD DROP: every drop point is in reach of a turret pad ---


func test_accord_drop_points_are_all_within_reach_of_a_pad() -> void:
	var w: SimWorld = _world()
	var arena: ArenaDef = w.content.arena
	var reach: float = w.content.upgrades[Ids.UP_AUTO_TURRET].turret_range_m
	assert_int(arena.drop_points.size()).is_equal(4)
	for p: Vector2 in arena.drop_points:
		var best: float = INF
		for pad: Vector2 in arena.turret_pads:
			best = minf(best, p.distance_to(pad))
		assert_float(best).is_less_equal(reach)


# --- FLOOR BREACH: pools on a breach hit the borers as they emerge ---


func test_floor_breach_borers_that_come_out_in_a_pool_are_burnt_at_once() -> void:
	var w: SimWorld = _planned(VarietyVKit.BREACH)
	w.plan.wave(4).act = 2
	w.phase_state.act = 2
	VarietyVKit.tick(w)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	var _pool: int = HazardSystem.add_pool(w, warned.f, warned.g, 2.2, 600, 60.0, 0.0)
	VarietyVKit.run(w, 150)  # the borers come out at tick 151
	var hurt: int = 0
	VarietyVKit.run(w, 31)
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.hp[i] < w.enemies.max_hp[i]:
			hurt += 1
	assert_int(hurt).is_greater(0)


# --- Tremor Rig stomp and Lance Platform beam (boss scripts): the hooks they use ---


func test_a_stomp_takes_the_turrets_offline_for_four_seconds_and_a_front_cannot_start_on_top_of_it() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	EventSystem.take_turrets_offline(w, 240)
	VarietyVKit.run(w, 200)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)
	VarietyVKit.run(w, 100)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(1)


func test_a_lance_platform_beam_can_always_be_answered_by_a_deadfall_strike_and_a_vent() -> void:
	var w: SimWorld = _world()
	VarietyVKit.place(w, Ids.EN_HULK, -3.0, 3.0)
	assert_int(EventSystem.block_reason(w, VarietyVKit.STRIKE)).is_equal(Reason.Id.OK)  # a charge and a target are enough
	assert_int(EventSystem.block_reason(w, VarietyVKit.VENT)).is_equal(Reason.Id.OK)
	w.events_state.ability_lock_ticks = 720  # even under a Static Front the calls are not abilities
	assert_int(EventSystem.block_reason(w, VarietyVKit.STRIKE)).is_equal(Reason.Id.OK)


## Tremor Rig stomp | turrets: offline 4 s. The boss writes EventState.turret_offline_ticks through BossEffects.turrets_offline;
## EventSystem counts it down once per tick and TurretSystem does not fire while it is above 0.
func test_the_stomp_of_the_tremor_rig_silences_the_turrets_for_exactly_its_ticks() -> void:
	var w: SimWorld = _world()
	w.turrets.active[0] = 1
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, -1.0, -1.5))
	BossEffects.turrets_offline(w, 240)
	var shots: int = w.combat.shots_by_source[DamageSource.Id.TURRET_0]
	VarietyVKit.run(w, 239)
	assert_int(w.events_state.turret_offline_ticks).is_equal(1)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(shots)
	VarietyVKit.tick(w)  # tick 240: the counter reaches 0 before the turret step of that tick
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(shots + 1)
	BossEffects.turrets_offline(w, 100)
	BossEffects.turrets_offline(w, 30)  # a second stomp never shortens the first
	assert_int(w.events_state.turret_offline_ticks).is_equal(100)
