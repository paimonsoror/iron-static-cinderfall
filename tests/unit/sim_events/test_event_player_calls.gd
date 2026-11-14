extends GdUnitTestSuite
## V4-V: the player's calls beyond the Deadfall Strike (V2-C tests that one): CORE VENT and FREIGHT, and the charges of all
## three (VARIETY_SPEC 7.1; CONTENT 6). The core is at (-7.5, 3.0), the rail lines are z = -7.0 (A) and z = 10.5 (B).


func _vent_world() -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, 4)
	w.core_hp = w.core_max_hp
	return w


# --- CORE VENT ---


func test_the_vent_costs_four_percent_of_the_core_and_lands_half_a_second_later() -> void:
	var w: SimWorld = _vent_world()
	var near: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -4.0, 3.0)  # 3.5 m from the core, on the march
	var far: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 5.0, 3.0)  # 12.5 m
	VarietyVKit.tough(w, near)
	VarietyVKit.tough(w, far)
	var before: float = w.core_hp
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)).is_equal(Reason.Id.OK)  # tick 1
	assert_float(w.core_hp).is_equal_approx(before * 0.96, 0.001)  # V5-C: 4% (was 8%)
	assert_int(w.events_state.charges_of(VarietyVKit.VENT)).is_equal(0)
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_int(warned.b).is_equal(30)
	assert_float(warned.f).is_equal(-7.5)
	assert_float(warned.g).is_equal(3.0)
	VarietyVKit.run(w, 29)  # tick 30
	assert_float(VarietyVKit.taken(w, near)).is_equal(0.0)
	VarietyVKit.tick(w)  # tick 31 = 1 + 30
	assert_float(VarietyVKit.taken(w, near)).is_equal(220.0)  # the armor of the hollow warden is ignored
	assert_float(VarietyVKit.taken(w, far)).is_equal(0.0)
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([31])
	var blasts: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	assert_int(blasts.size()).is_equal(1)
	assert_int(blasts[0].a).is_equal(HazardState.K_VENT)
	assert_int(blasts[0].b).is_equal(600)


func test_the_vent_throws_survivors_back_two_meters_and_resets_the_attackers() -> void:
	var w: SimWorld = _vent_world()
	var walker: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -4.0, 3.0)
	var attacker: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -5.0, 3.0, EnemyStore.ST_ATTACKING)
	var slot: int = w.nav.slots.claim(w, attacker)
	var boss: int = VarietyVKit.place(w, Ids.EN_HULK, -3.0, 3.0)
	for i: int in [walker, attacker, boss]:
		VarietyVKit.tough(w, i)
	w.enemies.attack_cd[attacker] = 3
	var _reason: int = VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)
	VarietyVKit.run(w, 30)
	assert_float(w.enemies.x[walker]).is_equal_approx(-2.0, 0.0001)  # 2 m straight away from the core
	assert_float(w.enemies.z[walker]).is_equal_approx(3.0, 0.0001)
	assert_float(w.enemies.x[attacker]).is_equal_approx(-3.0, 0.0001)
	assert_int(w.enemies.state[attacker]).is_equal(EnemyStore.ST_SEEK_SLOT)
	assert_int(w.enemies.slot[attacker]).is_equal(slot)  # the slot stays its own
	assert_int(w.enemies.attack_cd[attacker]).is_equal(w.nav.t_period[Ids.EN_HOLLOW])
	assert_float(w.enemies.x[boss]).is_equal(-3.0)  # a boss is hit but never thrown
	assert_float(VarietyVKit.taken(w, boss)).is_equal(220.0)


func test_the_vent_is_blocked_at_ten_percent_and_once_per_wave() -> void:
	var w: SimWorld = _vent_world()
	VarietyVKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.core_hp = w.core_max_hp * 0.10
	assert_int(EventSystem.block_reason(w, VarietyVKit.VENT)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)).is_equal(Reason.Id.WRONG_STATE)
	assert_float(w.core_hp).is_equal(w.core_max_hp * 0.10)  # a refusal costs nothing
	w.core_hp = w.core_max_hp * 0.11
	assert_int(EventSystem.block_reason(w, VarietyVKit.VENT)).is_equal(Reason.Id.OK)
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)).is_equal(Reason.Id.OK)
	assert_float(w.core_hp).is_greater(w.core_max_hp * 0.029)  # the price can never kill
	assert_int(EventSystem.block_reason(w, VarietyVKit.VENT)).is_equal(Reason.Id.NO_CHARGES)
	VarietyVKit.begin_wave(w, 5)
	assert_int(w.events_state.charges_of(VarietyVKit.VENT)).is_equal(1)  # a new wave charges it again
	assert_int(w.events_state.used_this_wave[VarietyVKit.VENT]).is_equal(0)


func test_the_vent_is_refused_between_waves() -> void:
	var w: SimWorld = _vent_world()
	w.phase = GameState.Id.INTERMISSION
	assert_int(EventSystem.block_reason(w, VarietyVKit.VENT)).is_equal(Reason.Id.WRONG_STATE)


func test_the_vent_never_hurts_the_core_beyond_its_price_or_the_warden_or_a_turret() -> void:
	var w: SimWorld = _vent_world()
	w.turrets.active[0] = 1
	for k: int in 6:
		VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, -5.0 + float(k) * 0.4, 3.5))
	var warden_x: float = w.warden.x
	var _reason: int = VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)
	var after_price: float = w.core_hp
	VarietyVKit.run(w, 40)
	assert_float(w.core_hp).is_equal(after_price)
	assert_float(w.warden.x).is_equal(warden_x)
	assert_int(w.turrets.active[0]).is_equal(1)


# --- FREIGHT ---


func _freight_world() -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, 4)
	EventSystem.grant_charges(w, VarietyVKit.FREIGHT, 1)
	return w


func test_freight_picks_the_line_with_more_enemies_and_crosses_in_1_2_seconds() -> void:
	var w: SimWorld = _freight_world()
	var on_lane: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 5.1, -7.0)
	var near_edge: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -3.0, -6.0)  # 1.0 m from the line: inside 1.3
	var wide: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 0.0, -5.4)  # 1.6 m: outside
	var other_line: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 4.0, 10.5)
	for i: int in [on_lane, near_edge, wide, other_line]:
		VarietyVKit.tough(w, i)
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.FREIGHT)).is_equal(Reason.Id.OK)  # tick 1
	var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
	assert_int(warned.b).is_equal(240)
	assert_float(warned.g).is_equal(-7.0)  # line A holds two, line B one
	VarietyVKit.run(w, 239)  # tick 240, one before the start
	assert_float(VarietyVKit.taken(w, on_lane)).is_equal(0.0)
	VarietyVKit.tick(w)  # tick 241 = 1 + 240: the car enters
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([241])
	VarietyVKit.run(w, 17)  # tick 258
	assert_float(VarietyVKit.taken(w, on_lane)).is_equal(0.0)
	VarietyVKit.tick(w)  # tick 259: 18 ticks after the start the car (x = 10 - 20 t / 72) has passed x = 5.1
	assert_float(VarietyVKit.taken(w, on_lane)).is_equal(700.0)
	VarietyVKit.run(w, 60)  # tick 319, the car is still on its way
	assert_float(VarietyVKit.taken(w, near_edge)).is_equal(700.0)
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_ENDED)).is_equal([241 + 72])
	assert_float(VarietyVKit.taken(w, wide)).is_equal(0.0)
	assert_float(VarietyVKit.taken(w, other_line)).is_equal(0.0)


func test_freight_throws_survivors_out_of_the_lane_but_not_the_stunned_or_a_boss() -> void:
	var w: SimWorld = _freight_world()
	var above: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 5.0, -6.5)
	var below: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, -7.5)
	var stunned: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 1.0, -6.8)
	var boss: int = VarietyVKit.place(w, Ids.EN_HULK, -2.0, -7.0)
	for i: int in [above, below, stunned, boss]:
		VarietyVKit.tough(w, i)
	w.enemies.stun_ticks[stunned] = 100000
	var _reason: int = VarietyVKit.call_on_next_tick(w, VarietyVKit.FREIGHT)
	VarietyVKit.run(w, 240 + 72)
	assert_float(w.enemies.z[above]).is_equal_approx(-5.0, 0.0001)  # 1.5 m away from the line, to the +z side
	assert_float(w.enemies.z[below]).is_equal_approx(-9.0, 0.0001)
	assert_float(w.enemies.z[stunned]).is_equal(-6.8)  # stunned enemies cannot leave the lane
	assert_float(VarietyVKit.taken(w, stunned)).is_equal(700.0)
	assert_float(w.enemies.z[boss]).is_equal(-7.0)
	assert_float(VarietyVKit.taken(w, boss)).is_equal(350.0)  # a boss takes half


func test_freight_needs_a_charge_and_a_wave_and_is_one_per_act() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	assert_int(w.events_state.charges_of(VarietyVKit.FREIGHT)).is_equal(0)
	assert_int(EventSystem.block_reason(w, VarietyVKit.FREIGHT)).is_equal(Reason.Id.NO_CHARGES)
	w.mods.freight_per_act = 1.0  # signal_hijack
	EventSystem.grant_charges(w, VarietyVKit.FREIGHT, 1)
	EventSystem.grant_charges(w, VarietyVKit.FREIGHT, 1)
	assert_int(w.events_state.charges_of(VarietyVKit.FREIGHT)).is_equal(1)  # cap 1
	w.phase = GameState.Id.INTERMISSION
	assert_int(EventSystem.block_reason(w, VarietyVKit.FREIGHT)).is_equal(Reason.Id.WRONG_STATE)


# --- charges ---


func test_a_kit_grant_of_a_charge_survives_the_start_and_adds_to_it() -> void:
	var w: SimWorld = VarietyVKit.kit_world(1)
	assert_int(w.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(2)  # start 1 + the kit's 1
	EventSlots.init_charges(w)  # asking again changes nothing
	assert_int(w.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(2)
	var capped: SimWorld = VarietyVKit.kit_world(5)
	assert_int(capped.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(3)  # the cap holds
	assert_int(TestContent.variety_world(1).events_state.charges_of(VarietyVKit.STRIKE)).is_equal(1)


func test_the_player_events_start_with_their_charges() -> void:
	var w: SimWorld = TestContent.variety_world(1)
	assert_int(w.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(1)
	assert_int(w.events_state.charges_of(VarietyVKit.VENT)).is_equal(1)
	assert_int(w.events_state.charges_of(VarietyVKit.FREIGHT)).is_equal(0)
	assert_int(w.events_state.charges_of(VarietyVKit.ACCORD)).is_equal(0)


func test_an_act_start_earns_the_charges_of_the_entry_and_leaves_the_directive_stats_to_modsystem() -> void:
	var w: SimWorld = TestContent.variety_world(1)
	w.phase = GameState.Id.SPAWNING
	w.mods.freight_per_act = 1.0  # signal_hijack: ModSystem.set_wave_modifier grants these, not EventSystem
	w.mods.strike_per_act = 1.0  # deadfall_uplink
	w.plan.waves[3].act = 2  # wave 4 opens act II in this test
	VarietyVKit.begin_wave(w, 4)
	assert_int(w.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(2)  # 1 + the entry's charges_per_act
	assert_int(w.events_state.charges_of(VarietyVKit.FREIGHT)).is_equal(0)


func test_the_first_act_start_does_not_double_the_starting_charge() -> void:
	var w: SimWorld = TestContent.variety_world(1)
	w.phase = GameState.Id.SPAWNING
	VarietyVKit.begin_wave(w, 1)
	assert_int(w.events_state.charges_of(VarietyVKit.STRIKE)).is_equal(1)
