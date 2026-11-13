extends GdUnitTestSuite
## V4-V (B07): the fairness rules of GDD 7b / VARIETY_SPEC 7.3, one test each (the numbers refer to the rules):
## 1 no event damages the core, the Warden or a turret; 2 no harmful event in waves 1 and 2, wave 3's is helpful;
## 3 at most one harmful event per wave in acts I and II, two in act III, never two tool-denying at once; 4 mercy below 15%;
## 5 cooldowns freeze (test_event_world_tools); 6 every event is in the plan; 7 never the same world event in two
## consecutive waves; 8 (test_fairness_balance). The plan rules are checked on the shipped schedule rules over many seeds.

const SEEDS: int = 150


func _plans(seeds: int) -> Array[RunPlan]:
	var content: ContentSet = VarietyVKit.long_content()
	var out: Array[RunPlan] = []
	for s: int in range(1, seeds + 1):
		out.append(RunPlanSystem.build_for(content, s))
	return out


func _planned(wave: int, event_index: int, act: int = 1) -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, wave, wave > 5)
	w.plan.wave(wave).act = act
	w.phase_state.act = act
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, wave, event_index, 1)
	return w


# --- rule 2 ---


func test_rule_2_no_event_in_waves_one_and_two_and_wave_three_is_helpful() -> void:
	var content: ContentSet = VarietyVKit.long_content()
	var seen_event_in_three: bool = false
	for plan: RunPlan in _plans(SEEDS):
		assert_int(plan.wave(1).events.size()).is_equal(0)
		assert_int(plan.wave(2).events.size()).is_equal(0)
		for e: PlannedEvent in plan.wave(3).events:
			seen_event_in_three = true
			assert_bool(content.events[e.event_index].harmful).is_false()
	assert_bool(seen_event_in_three).is_true()


func test_rule_2_at_run_time_a_harmful_event_is_refused_in_waves_one_to_three() -> void:
	for wave: int in [1, 2, 3]:
		var w: SimWorld = _planned(wave, VarietyVKit.STATIC)
		VarietyVKit.tick(w)
		assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).override_failure_message("wave %d" % wave).is_equal(0)
		var cancelled: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_CANCELLED)
		assert_int(cancelled.size()).is_equal(1)
		assert_int(cancelled[0].a).is_equal(VarietyVKit.STATIC)
		assert_int(cancelled[0].b).is_equal(Reason.Id.WRONG_STATE)
	var helpful: SimWorld = _planned(3, VarietyVKit.ACCORD)
	VarietyVKit.tick(helpful)
	assert_int(VarietyVKit.count(helpful, SimEventKind.Id.EVENT_WARNED)).is_equal(1)


# --- rule 3 ---


func test_rule_3_the_plan_has_at_most_one_harmful_event_a_wave_in_acts_one_and_two_and_two_in_act_three() -> void:
	var content: ContentSet = VarietyVKit.long_content()
	var worst: Dictionary[int, int] = {1: 0, 2: 0, 3: 0}
	for plan: RunPlan in _plans(SEEDS):
		for pw: PlannedWave in plan.waves:
			var harmful: int = 0
			var ids: Array[StringName] = []
			for e: PlannedEvent in pw.events:
				harmful += 1 if content.events[e.event_index].harmful else 0
				ids.append(content.events[e.event_index].id)
			worst[pw.act] = maxi(worst[pw.act], harmful)
			assert_bool(ids.has(&"static_front") and ids.has(&"power_surge")).is_false()  # never overlap
	assert_int(worst[1]).is_less_equal(1)
	assert_int(worst[2]).is_less_equal(1)
	assert_int(worst[3]).is_less_equal(2)
	assert_int(worst[2]).is_equal(1)  # the limit is reached, so the test means something


func test_rule_3_at_run_time_the_second_harmful_event_of_a_wave_is_refused_in_acts_one_and_two() -> void:
	var w: SimWorld = _planned(4, VarietyVKit.STATIC)
	VarietyVKit.plan_event(w, 4, VarietyVKit.RECOUNT, 5)
	VarietyVKit.run(w, 10)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(1)
	var cancelled: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_CANCELLED)
	assert_int(cancelled.size()).is_equal(1)
	assert_int(cancelled[0].a).is_equal(VarietyVKit.RECOUNT)
	assert_int(w.events_state.cancelled).is_equal(1)


func test_rule_3_act_three_allows_two_harmful_events_and_refuses_the_third() -> void:
	var w: SimWorld = _planned(12, VarietyVKit.RECOUNT, 3)
	VarietyVKit.plan_event(w, 12, VarietyVKit.BREACH, 5)
	VarietyVKit.plan_event(w, 12, VarietyVKit.RECOUNT, 9)
	VarietyVKit.run(w, 12)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_greater_equal(2)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_CANCELLED)).is_equal(1)
	assert_int(EventSchedule.harmful_this_wave(w)).is_equal(2)


func test_rule_3_a_boss_wave_takes_boss_safe_events_only() -> void:
	var content: ContentSet = VarietyVKit.long_content()
	for plan: RunPlan in _plans(SEEDS):
		for pw: PlannedWave in plan.waves:
			if pw.is_boss:
				for e: PlannedEvent in pw.events:
					assert_bool(content.events[e.event_index].boss_safe).is_true()
	var w: SimWorld = _planned(5, VarietyVKit.RECOUNT)  # wave 5 is the boss wave of the slice
	VarietyVKit.tick(w)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)


func test_rule_3_a_static_front_waits_for_a_brownout_and_never_overlaps_another_tool_denying_state() -> void:
	var w: SimWorld = _planned(4, VarietyVKit.STATIC)
	w.events_state.turret_offline_ticks = 200  # a brownout, Low Power or a stomp is on
	VarietyVKit.run(w, 150)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)
	assert_int(w.events_state.plan_cursor).is_equal(0)
	VarietyVKit.run(w, 60)
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_WARNED)).is_equal([201])  # as soon as the outage is over
	# the other way round: a surge that ends under a Static Front gives no brownout
	var surge: SimWorld = _planned(4, VarietyVKit.SURGE)
	VarietyVKit.run(surge, 241)
	surge.events_state.ability_lock_ticks = 100000
	VarietyVKit.run(surge, 600)
	assert_int(surge.events_state.turret_offline_ticks).is_equal(0)


# --- rule 4 ---


func test_rule_4_a_harmful_event_whose_warning_starts_below_fifteen_percent_is_cancelled_and_logged() -> void:
	var w: SimWorld = _planned(4, VarietyVKit.STATIC)
	w.core_hp = w.core_max_hp * 0.1499
	VarietyVKit.tick(w)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)
	var cancelled: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_CANCELLED)
	assert_int(cancelled.size()).is_equal(1)
	assert_int(cancelled[0].b).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(w.events_state.cancelled).is_equal(1)
	assert_int(w.events_state.plan_cursor).is_equal(1)  # it is gone, not postponed
	var exactly: SimWorld = _planned(4, VarietyVKit.STATIC)
	exactly.core_hp = exactly.core_max_hp * 0.15
	VarietyVKit.tick(exactly)
	assert_int(VarietyVKit.count(exactly, SimEventKind.Id.EVENT_WARNED)).is_equal(1)


func test_rule_4_helpful_events_still_come_when_the_core_is_low() -> void:
	for event_index: int in [VarietyVKit.ACCORD, VarietyVKit.DROP, VarietyVKit.SURGE, VarietyVKit.RUNAWAY]:
		var w: SimWorld = _planned(4, event_index)
		w.core_hp = w.core_max_hp * 0.05
		VarietyVKit.tick(w)
		assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(1)
		assert_int(w.events_state.cancelled).is_equal(0)


func test_rule_4_the_cancelled_event_is_decided_when_the_warning_would_start_not_later() -> void:
	var w: SimWorld = _planned(4, VarietyVKit.STATIC)
	VarietyVKit.run(w, 5)  # warning started at tick 1 with a healthy core
	w.core_hp = w.core_max_hp * 0.05  # the core falls during the warning: the event is not taken back
	VarietyVKit.run(w, 400)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_STARTED)).is_equal(1)


# --- rule 1 ---


func test_rule_1_no_event_damages_the_core_the_warden_or_a_turret() -> void:
	var cases: Array[Array] = [
		[VarietyVKit.ACCORD, 1], [VarietyVKit.DROP, 1], [VarietyVKit.SURGE, 1], [VarietyVKit.RUNAWAY, 1],
		[VarietyVKit.STATIC, 1], [VarietyVKit.BREACH, 2], [VarietyVKit.RECOUNT, 2],
	]
	for row: Array in cases:
		var event_index: int = row[0]
		var act: int = row[1]
		var w: SimWorld = _planned(4, event_index, act)
		w.turrets.active[0] = 1
		w.turrets.active[1] = 1
		for k: int in 6:  # a crowd on the march, on the rails and at the cage
			VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_SKITTER, -5.0 + float(k) * 2.0, 3.0 + float(k % 2) * 4.0))
		VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, -7.0))
		var core: float = w.core_hp
		var warden_x: float = w.warden.x
		var warden_z: float = w.warden.z
		var magazine: int = w.warden.magazine
		VarietyVKit.run(w, 1500)
		var label: String = String(w.content.events[event_index].id)
		assert_float(w.core_hp).override_failure_message(label).is_equal(core)
		assert_float(w.shield_hp).override_failure_message(label).is_equal(0.0)
		assert_float(w.warden.x).override_failure_message(label).is_equal(warden_x)
		assert_float(w.warden.z).override_failure_message(label).is_equal(warden_z)
		assert_int(w.warden.magazine).override_failure_message(label).is_equal(magazine)
		assert_int(w.turrets.active[0] + w.turrets.active[1]).override_failure_message(label).is_equal(2)
		assert_int(VarietyVKit.count(w, SimEventKind.Id.CORE_HIT)).override_failure_message(label).is_equal(0)
	var called: SimWorld = VarietyVKit.world(1, 4)
	EventSystem.grant_charges(called, VarietyVKit.FREIGHT, 1)
	VarietyVKit.tough(called, VarietyVKit.place(called, Ids.EN_SKITTER, -6.0, 3.0))
	var core_before: float = called.core_hp
	assert_int(VarietyVKit.call_on_next_tick(called, VarietyVKit.STRIKE)).is_equal(Reason.Id.OK)
	assert_int(VarietyVKit.call_on_next_tick(called, VarietyVKit.FREIGHT)).is_equal(Reason.Id.OK)
	VarietyVKit.run(called, 500)
	assert_float(called.core_hp).is_equal(core_before)


# --- rules 6 and 7 ---


func test_rule_6_the_plan_is_a_function_of_the_seed_and_the_run_plays_only_what_it_holds() -> void:
	var a: RunPlan = RunPlanSystem.build_for(VarietyVKit.long_content(), 7)
	var b: RunPlan = RunPlanSystem.build_for(VarietyVKit.long_content(), 7)
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))
	var differs: bool = false
	for s: int in range(8, 30):
		differs = differs or JSON.stringify(RunPlanSystem.build_for(VarietyVKit.long_content(), s).to_dict()) != JSON.stringify(a.to_dict())
	assert_bool(differs).is_true()
	# the events that start in wave n are exactly the ones planned for wave n, at their offsets, however the wave goes
	for s: int in range(1, 13):
		for wave: int in [3, 4, 5]:
			var w: SimWorld = VarietyVKit.world(s, wave)
			w.core_hp = w.core_max_hp
			VarietyVKit.run(w, w.content.run.wave_slot(wave).window_ticks)
			var launched: Array[String] = []
			for e: SimEvent in VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED):
				launched.append("%d@%d" % [e.a, e.tick])
			var planned: Array[String] = []
			for pe: PlannedEvent in w.plan.wave(wave).events:
				planned.append("%d@%d" % [pe.event_index, pe.start_offset])
			assert_array(launched).override_failure_message("seed %d wave %d" % [s, wave]).is_equal(planned)


func test_rule_7_the_same_world_event_never_comes_in_two_consecutive_waves() -> void:
	var worst: int = 0
	for plan: RunPlan in _plans(SEEDS):
		for n: int in range(2, plan.wave_count() + 1):
			for e: PlannedEvent in plan.wave(n).events:
				for before: PlannedEvent in plan.wave(n - 1).events:
					assert_int(e.event_index).is_not_equal(before.event_index)
					worst += 1
	assert_int(worst).is_greater(0)
