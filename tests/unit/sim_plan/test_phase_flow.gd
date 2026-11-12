extends GdUnitTestSuite
## V2-A: the intermission of a generated run (VARIETY_SPEC 2.5): ROUTE and BOSS_BRIEF awaits, PICK_ROUTE, the breather, the
## DRAFT and SALVAGE steps, and that an await holds the whole simulation. Since the V2 merge the draft and salvage
## systems are real: where a test is about the route, the draft and the crate before it are closed through their
## systems (VarietyAKit.run_to_route); the chain with every step answered by command is in test_slice_intermission.gd.


func _at_first_route(run_seed: int = 1) -> SimWorld:
	var w: SimWorld = VarietyAKit.world(run_seed)
	assert_bool(VarietyAKit.run_to_route(w)).is_true()  # the draft of wave 1 is skipped on the way
	return w


func _rejected(w: SimWorld) -> Array[SimEvent]:
	return VarietyAKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED)


func test_a_new_variety_world_waits_for_nothing_and_starts_in_act_one() -> void:
	var w: SimWorld = VarietyAKit.world()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_int(w.phase_state.act).is_equal(1)
	assert_bool(w.phase_state.breather).is_false()
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(PhaseSystem.wave_count(w)).is_equal(5)


func test_wave_one_announces_the_act_and_its_planned_count() -> void:
	var w: SimWorld = VarietyAKit.world()
	for _n: int in 180:
		w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	var acts: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.ACT_STARTED)
	assert_int(acts.size()).is_equal(1)
	assert_int(acts[0].a).is_equal(1)
	var started: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
	assert_int(started[0].b).is_equal(w.plan.option(1).total_count())
	assert_int(w.nav.sched_due.size()).is_equal(w.plan.option(1).total_count())


func test_clearing_a_wave_opens_the_route_choice_of_the_next_wave() -> void:
	var w: SimWorld = _at_first_route()
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	assert_int(w.waves_completed).is_equal(1)
	assert_int(w.phase_ticks_left).is_equal(0)
	assert_bool(w.phase_state.breather).is_false()
	var offered: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_OFFERED)
	assert_int(offered.size()).is_equal(1)
	assert_int(offered[0].a).is_equal(2)
	assert_int(offered[0].b).is_equal(2)
	var changed: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.AWAIT_CHANGED)
	assert_int(changed[changed.size() - 1].a).is_equal(PhaseState.Await.ROUTE)
	assert_int(changed[changed.size() - 1].b).is_equal(PhaseState.Await.NONE)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.INTERMISSION_STARTED).size()).is_equal(1)


func test_an_await_freezes_the_tick_and_every_timer() -> void:
	var w: SimWorld = _at_first_route()
	var tick: int = w.tick
	var combat: int = w.stats.combat_ticks
	var hash_before: String = w.state_hash()
	var events: int = w.events.total
	for _n: int in 600:
		w.step()
	assert_int(w.tick).is_equal(tick)
	assert_int(w.stats.combat_ticks).is_equal(combat)
	assert_int(w.phase_ticks_left).is_equal(0)
	assert_int(w.events.total).is_equal(events)
	assert_str(w.state_hash()).is_equal(hash_before)


func test_picking_a_route_records_it_and_starts_the_breather() -> void:
	var w: SimWorld = _at_first_route()
	w.submit(SimCommand.pick_route(10, 1))
	w.step()
	assert_int(w.plan.chosen[1]).is_equal(1)
	assert_int(w.stats.route_choices[2]).is_equal(1)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_bool(w.phase_state.breather).is_true()
	assert_int(w.phase_ticks_left).is_equal(w.content.mission.breather_ticks - 1)  # the pick tick is the first breather tick
	var picked: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_PICKED)
	assert_int(picked.size()).is_equal(1)
	assert_int(picked[0].a).is_equal(2)
	assert_int(picked[0].b).is_equal(1)
	assert_int(_rejected(w).size()).is_equal(0)


func test_the_breather_lasts_the_configured_ticks_then_the_chosen_option_spawns() -> void:
	for pick: int in [0, 1]:
		var w: SimWorld = _at_first_route(4)
		w.submit(SimCommand.pick_route(10, pick))
		w.step()
		for _n: int in w.content.mission.breather_ticks - 2:
			w.step()
		assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
		w.step()
		assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
		assert_int(w.wave).is_equal(2)
		assert_bool(w.phase_state.breather).is_false()
		var option: RouteOption = w.plan.wave(2).options[pick]
		assert_int(w.nav.sched_due.size()).is_equal(option.total_count())
		assert_int(w.nav.sched_type[w.nav.sched_type.size() - 1]).is_greater_equal(0)
		var started: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
		assert_int(started[started.size() - 1].b).is_equal(option.total_count())


func test_the_two_options_schedule_different_waves() -> void:
	var sched: Array[PackedInt32Array] = []
	for pick: int in [0, 1]:
		var w: SimWorld = _at_first_route(4)
		w.submit(SimCommand.pick_route(10, pick))
		w.step()
		w.phase_ticks_left = 1
		w.step()
		sched.append(w.nav.sched_type.duplicate())
	assert_array(Array(sched[0])).is_not_equal(Array(sched[1]))


func test_a_route_that_does_not_exist_is_refused_and_the_await_stays() -> void:
	var w: SimWorld = _at_first_route()
	w.submit(SimCommand.pick_route(10, 2))
	w.submit(SimCommand.pick_route(11, -1))
	w.step()
	var refused: Array[SimEvent] = _rejected(w)
	assert_int(refused.size()).is_equal(2)
	assert_int(refused[0].b).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(refused[1].b).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	assert_int(w.plan.chosen[1]).is_equal(0)
	w.submit(SimCommand.pick_route(12, 1))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)


func test_a_route_pick_outside_the_route_await_is_refused() -> void:
	var w: SimWorld = VarietyAKit.world()
	w.submit(SimCommand.pick_route(1, 0))
	w.step()
	assert_int(_rejected(w)[0].b).is_equal(Reason.Id.NOT_AWAITING)
	var at_route: SimWorld = _at_first_route()
	at_route.submit(SimCommand.pick_route(1, 0))
	at_route.step()
	at_route.submit(SimCommand.pick_route(2, 1))  # the second pick: the await is over
	at_route.step()
	assert_int(_rejected(at_route)[0].b).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(at_route.plan.chosen[1]).is_equal(0)


func test_a_command_during_an_await_advances_exactly_one_tick() -> void:
	var w: SimWorld = _at_first_route()
	var tick: int = w.tick
	w.submit(SimCommand.pick_route(1, 5))  # refused, but still applied and logged
	w.step()
	assert_int(w.tick).is_equal(tick + 1)
	assert_int(w.command_log.entries[0].tick).is_equal(tick + 1)
	w.step()
	assert_int(w.tick).is_equal(tick + 1)


func test_a_pending_choice_cannot_be_skipped_but_the_breather_can() -> void:
	var w: SimWorld = _at_first_route()
	w.submit(SimCommand.skip(5))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	assert_int(PhaseSystem.skip_intermission(w)).is_equal(Reason.Id.WRONG_STATE)
	w.submit(SimCommand.pick_route(6, 0))
	w.step()
	assert_bool(w.phase_state.breather).is_true()
	w.submit(SimCommand.skip(7))
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(2)


func test_the_boss_briefing_comes_before_a_boss_wave_and_continue_starts_the_breather() -> void:
	var w: SimWorld = VarietyAKit.world(2)
	var command_id: int = 1
	for n: int in 3:  # the routes of waves 2, 3 and 4
		assert_bool(VarietyAKit.run_to_route(w)).is_true()
		assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
		VarietyAKit.answer(w, command_id)
		command_id += 1
	assert_bool(VarietyAKit.run_to_route(w)).is_true()
	assert_int(w.wave).is_equal(4)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.BOSS_BRIEF)
	var briefed: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.BOSS_BRIEFED)
	assert_int(briefed[briefed.size() - 1].a).is_equal(5)
	assert_int(briefed[briefed.size() - 1].b).is_equal(w.plan.boss_ids[0])
	w.submit(SimCommand.pick_route(99, 0))
	w.step()
	assert_int(_rejected(w)[_rejected(w).size() - 1].b).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.BOSS_BRIEF)
	w.submit(SimCommand.skip(100))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_bool(w.phase_state.breather).is_true()
	for _n: int in w.content.mission.breather_ticks:
		w.step()
	assert_int(w.wave).is_equal(5)
	assert_int(w.nav.sched_type[0]).is_equal(w.plan.boss_ids[0])  # the boss enters first


func test_an_open_draft_is_awaited_before_the_route() -> void:
	var w: SimWorld = VarietyAKit.world()
	w.draft.open = true  # DraftSystem.open is V2-B's: here the draft counts as open
	assert_bool(VarietyAKit.run_to_await(w)).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_OFFERED).size()).is_equal(0)
	PhaseSystem.advance_await(w)  # still open: nothing moves
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	w.submit(SimCommand.skip(1))  # the breather skip cannot jump the draft
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	w.draft.open = false
	PhaseSystem.advance_await(w)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	var changed: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.AWAIT_CHANGED)
	assert_int(changed[changed.size() - 1].a).is_equal(PhaseState.Await.ROUTE)
	assert_int(changed[changed.size() - 1].b).is_equal(PhaseState.Await.DRAFT)


func test_an_await_that_its_system_releases_is_picked_up_on_the_same_tick() -> void:
	var w: SimWorld = VarietyAKit.world()
	w.draft.open = true
	assert_bool(VarietyAKit.run_to_await(w)).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_bool(w.phase_state.drafted).is_true()
	w.draft.open = false  # DraftSystem closes its draft and sets the await back to NONE itself
	w.phase_state.awaiting = PhaseState.Await.NONE
	var tick: int = w.tick
	w.step()
	assert_int(w.tick).is_equal(tick + 1)  # nothing is awaited at the moment of the step, so the tick runs
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)  # pre_step went on to the route of wave 2
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_OFFERED).size()).is_equal(1)
	w.draft.open = true  # a second draft is never opened in the same intermission
	PhaseSystem.advance_await(w)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)


func test_a_pending_salvage_holds_the_flow_until_its_offer_is_resolved() -> void:
	var w: SimWorld = VarietyAKit.world()
	assert_bool(VarietyAKit.run_to_await(w)).is_true()  # at the route of wave 2
	w.phase_state.awaiting = PhaseState.Await.SALVAGE  # a debug write: SalvageSystem.open_next is V2-C's
	w.salvage.offer = PackedInt32Array([2, 3])
	PhaseSystem.advance_await(w)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.SALVAGE)
	w.salvage.offer = PackedInt32Array()
	PhaseSystem.advance_await(w)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)


func test_advance_await_is_harmless_outside_an_intermission() -> void:
	var w: SimWorld = VarietyAKit.world()
	var before: String = w.state_hash()
	PhaseSystem.advance_await(w)
	assert_str(w.state_hash()).is_equal(before)
	var legacy: SimWorld = TestContent.world()
	PhaseSystem.advance_await(legacy)
	assert_int(legacy.phase_state.awaiting).is_equal(PhaseState.Await.NONE)


func test_phase_state_round_trips_through_json() -> void:
	var w: SimWorld = _at_first_route()
	var doc: Dictionary = JSON.parse_string(JSON.stringify(w.phase_state.to_dict()))
	var copy: PhaseState = PhaseState.new()
	copy.from_dict(doc)
	var a: StateHasher = StateHasher.new()
	var b: StateHasher = StateHasher.new()
	w.phase_state.hash_into(a)
	copy.hash_into(b)
	assert_str(a.finish()).is_equal(b.finish())
	assert_int(copy.awaiting).is_equal(PhaseState.Await.ROUTE)


func test_every_field_of_the_intermission_is_hashed() -> void:
	var w: SimWorld = VarietyAKit.world()
	var seen: Dictionary[String, bool] = {w.state_hash(): true}
	w.phase_state.drafted = true
	seen[w.state_hash()] = true
	w.phase_state.drafted = false
	w.phase_state.breather = true
	seen[w.state_hash()] = true
	w.phase_state.drafted = true
	seen[w.state_hash()] = true
	assert_int(seen.size()).is_equal(4)
