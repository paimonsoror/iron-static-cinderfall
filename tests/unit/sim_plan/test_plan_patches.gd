extends GdUnitTestSuite
## V4-C: the plan patches of open_gate, chorus_handshake and static_pact (VARIETY_SPEC 9.3, CONTENT 3.6): they touch only
## the waves after the current one, draw from `plan.patch:<directive>:<w>` and so are reproducible, survive a snapshot, and
## also work for a directive a kit gave at tick 0. Content is the 15-wave stretch of the variety fixture; the events a
## Static Front needs are added to it as synthetic definitions (events.json belongs to V4-V).

const SEED: int = 3

var c: ContentSet


func before_test() -> void:
	c = VarietyAKit.long_content()


func _add_event(id: StringName, harmful: bool, boss_safe: bool) -> int:
	var e: EventDef = EventDef.new()
	e.id = id
	e.index = c.events.size()
	e.who = EventDef.Who.WORLD
	e.name_key = "event.%s.name" % String(id)
	e.warn_ticks = 360
	e.duration_ticks = 720
	e.weights = PackedFloat32Array([0.0, 0.0, 0.0])  # the plan never rolls them: the tests place them by hand
	e.harmful = harmful
	e.boss_safe = boss_safe
	c.events.append(e)
	return e.index


func _wave_hash(pw: PlannedWave) -> String:
	var h: StateHasher = StateHasher.new()
	pw.hash_into(h)
	return h.finish()


func _plan_hash(plan: RunPlan) -> String:
	var h: StateHasher = StateHasher.new()
	plan.hash_into(h)
	return h.finish()


func _event(index: int, offset: int) -> PlannedEvent:
	var e: PlannedEvent = PlannedEvent.new()
	e.event_index = index
	e.start_offset = offset
	return e


func _events_of(pw: PlannedWave) -> Array:
	var out: Array = []
	for e: PlannedEvent in pw.events:
		out.append([c.events[e.event_index].id, e.start_offset])
	return out


func test_open_gate_scales_the_intervals_of_the_remaining_waves_by_0_75() -> void:
	var reference: RunPlan = RunPlanSystem.build_for(c, SEED)
	var w: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(w, &"open_gate")
	var checked: int = 0
	for pw: PlannedWave in w.plan.waves:
		var before: PlannedWave = reference.wave(pw.index)
		if pw.index <= 2:
			assert_str(_wave_hash(pw)).override_failure_message("wave %d" % pw.index).is_equal(_wave_hash(before))
			continue
		for o: int in pw.options.size():
			for g: int in pw.options[o].groups.size():
				var want: int = maxi(1, roundi(float(before.options[o].groups[g].interval_ticks) * 0.75))
				assert_int(pw.options[o].groups[g].interval_ticks).is_equal(want)
				assert_int(pw.options[o].groups[g].count).is_equal(before.options[o].groups[g].count)
				checked += 1
	assert_int(checked).is_greater(40)


func test_chorus_handshake_adds_one_elite_per_option_of_every_remaining_normal_wave() -> void:
	var reference: RunPlan = RunPlanSystem.build_for(c, SEED)
	var w: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(w, &"chorus_handshake")
	for pw: PlannedWave in w.plan.waves:
		var before: PlannedWave = reference.wave(pw.index)
		var normal: bool = c.run.wave_slot(pw.index).kind == WaveSlotDef.Kind.NORMAL
		if pw.index <= 2 or not normal:
			assert_str(_wave_hash(pw)).override_failure_message("wave %d" % pw.index).is_equal(_wave_hash(before))
			continue
		for o: int in pw.options.size():
			var elites: Array[PlannedElite] = pw.options[o].elites
			assert_int(elites.size()).override_failure_message("wave %d option %d" % [pw.index, o]).is_equal(before.options[o].elites.size() + 1)
			var seen: Dictionary[String, bool] = {}
			for e: int in elites.size():
				var key: String = "%d/%d" % [elites[e].group, elites[e].ordinal]
				assert_bool(seen.has(key)).is_false()  # no body is elite twice
				seen[key] = true
				assert_int(elites[e].affix_mask).is_not_equal(0)
				if e > 0:
					var ordered: bool = elites[e - 1].group < elites[e].group or (elites[e - 1].group == elites[e].group and elites[e - 1].ordinal < elites[e].ordinal)
					assert_bool(ordered).is_true()


func test_a_patch_is_reproducible_and_does_not_depend_on_when_the_directive_is_taken() -> void:
	var early: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(early, &"chorus_handshake")
	DirectiveKit.give(early, &"open_gate")
	var early_again: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(early_again, &"chorus_handshake")
	DirectiveKit.give(early_again, &"open_gate")
	assert_str(_plan_hash(early.plan)).is_equal(_plan_hash(early_again.plan))
	var late: SimWorld = DirectiveKit.world(SEED, 4, 1, c)
	DirectiveKit.give(late, &"chorus_handshake")
	DirectiveKit.give(late, &"open_gate")
	for n: int in range(5, 16):  # the waves both patched are patched identically
		assert_str(_wave_hash(late.plan.wave(n))).override_failure_message("wave %d" % n).is_equal(_wave_hash(early.plan.wave(n)))
	assert_str(_wave_hash(late.plan.wave(3))).is_not_equal(_wave_hash(early.plan.wave(3)))  # only the early pick reaches wave 3
	var other_seed: SimWorld = DirectiveKit.world(SEED + 1, 2, 1, c)
	DirectiveKit.give(other_seed, &"chorus_handshake")
	assert_str(_wave_hash(other_seed.plan.wave(8))).is_not_equal(_wave_hash(early.plan.wave(8)))


func test_a_patch_draws_nothing_from_the_world_streams() -> void:
	var w: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(w, &"chorus_handshake")
	DirectiveKit.give(w, &"open_gate")
	assert_str(DirectiveKit.hash_of(w.rng)).is_equal(DirectiveKit.hash_of(SimRng.new(SEED)))


func test_static_pact_puts_a_static_front_into_every_remaining_normal_wave() -> void:
	var front: int = _add_event(&"static_front", true, false)
	var surge: int = _add_event(&"power_surge", false, true)
	var breach: int = _add_event(&"floor_breach", true, false)
	var accord: int = _add_event(&"accord_window", false, true)
	var w: SimWorld = DirectiveKit.world(SEED, 5, 1, c)
	w.plan.wave(6).events = [_event(surge, 600), _event(breach, 900)]  # act II: one harmful event per wave at most
	w.plan.wave(7).events = [_event(accord, 500)]
	w.plan.wave(8).events = [_event(front, 700)]  # has one already
	w.plan.wave(10).events = [_event(accord, 400)]  # a boss wave
	w.plan.wave(12).events = [_event(breach, 800), _event(surge, 1000)]  # act III may hold several harmful events
	w.plan.wave(4).events = [_event(accord, 300)]  # before the pick: left alone
	DirectiveKit.give(w, &"static_pact")
	var window_6: int = c.run.wave_slot(6).window_ticks
	var offset_6: int = roundi(lerpf(0.25, 0.70, PlanRng.unit(PlanRng.stream(SEED, &"plan.patch:static_pact:6"))) * float(window_6))
	assert_array(_events_of(w.plan.wave(6))).is_equal([[&"static_front", offset_6]])
	var offset_7: int = roundi(lerpf(0.25, 0.70, PlanRng.unit(PlanRng.stream(SEED, &"plan.patch:static_pact:7"))) * float(c.run.wave_slot(7).window_ticks))
	var want_7: Array = [[&"accord_window", 500], [&"static_front", offset_7]]
	if offset_7 < 500:
		want_7.reverse()
	assert_array(_events_of(w.plan.wave(7))).is_equal(want_7)
	assert_array(_events_of(w.plan.wave(8))).is_equal([[&"static_front", 700]])
	assert_array(_events_of(w.plan.wave(10))).is_equal([[&"accord_window", 400]])
	assert_array(_events_of(w.plan.wave(4))).is_equal([[&"accord_window", 300]])
	var kept_12: Array = _events_of(w.plan.wave(12))
	assert_int(kept_12.size()).is_equal(2)  # the surge goes, the breach stays, the front joins
	assert_bool(kept_12.has([&"floor_breach", 800])).is_true()
	assert_bool(kept_12.has([&"power_surge", 1000])).is_false()
	for n: int in [6, 7, 9, 11, 12, 13, 14]:  # every remaining normal wave has exactly one static front
		var fronts: int = 0
		for e: PlannedEvent in w.plan.wave(n).events:
			fronts += 1 if e.event_index == front else 0
		assert_int(fronts).override_failure_message("wave %d" % n).is_equal(1)
	for n: int in [1, 5, 10, 15]:  # the opener and the boss waves get none
		for e: PlannedEvent in w.plan.wave(n).events:
			assert_int(e.event_index).is_not_equal(front)


func test_static_pact_offsets_stay_inside_the_event_window_and_in_order() -> void:
	var front: int = _add_event(&"static_front", true, false)
	var w: SimWorld = DirectiveKit.world(SEED, 0, 1, c)
	DirectiveKit.give(w, &"static_pact")
	for pw: PlannedWave in w.plan.waves:
		var window: int = c.run.wave_slot(pw.index).window_ticks
		var last: int = -1
		for e: PlannedEvent in pw.events:
			assert_int(e.start_offset).is_greater_equal(last)
			last = e.start_offset
			if e.event_index == front:
				assert_int(e.start_offset).is_between(roundi(0.25 * float(window)), roundi(0.70 * float(window)))


func test_static_pact_without_a_static_front_in_the_content_changes_nothing() -> void:
	var reference: RunPlan = RunPlanSystem.build_for(c, SEED)
	var w: SimWorld = DirectiveKit.world(SEED, 2, 1, c)  # the fixture events have no static_front yet
	DirectiveKit.give(w, &"static_pact")
	assert_str(_plan_hash(w.plan)).is_equal(_plan_hash(reference))


func test_a_plan_patch_directive_from_a_kit_patches_the_whole_plan() -> void:
	var reference: RunPlan = RunPlanSystem.build_for(c, SEED)
	var ops: Array[OpDef] = [VarietyBKit.op_grant(&"directive", 1.0, &"open_gate")]
	var kit: int = DirectiveKit.add_kit(c, &"k_pact", ops)
	var w: SimWorld = DirectiveKit.kit_world(c, kit, SEED)
	assert_int(DirectiveKit.held(w, &"open_gate")).is_equal(1)
	for pw: PlannedWave in w.plan.waves:
		for o: int in pw.options.size():
			for g: int in pw.options[o].groups.size():
				var old: int = reference.wave(pw.index).options[o].groups[g].interval_ticks
				assert_int(pw.options[o].groups[g].interval_ticks).is_equal(maxi(1, roundi(float(old) * 0.75)))


func test_a_patched_plan_survives_a_snapshot() -> void:
	var w: SimWorld = DirectiveKit.world(SEED, 2, 1, c)
	DirectiveKit.give(w, &"chorus_handshake")
	DirectiveKit.give(w, &"open_gate")
	var doc: Dictionary = WorldSnapshot.capture(w)
	var twin: SimWorld = SimWorld.new(w.config)
	assert_str(_plan_hash(twin.plan)).is_not_equal(_plan_hash(w.plan))  # a fresh world has the unpatched plan
	assert_bool(WorldSnapshot.restore(twin, doc)).is_true()
	assert_str(_plan_hash(twin.plan)).is_equal(_plan_hash(w.plan))
	assert_str(twin.state_hash()).is_equal(w.state_hash())


func test_the_patch_of_the_legacy_content_does_nothing() -> void:
	var legacy: SimWorld = TestContent.world(2)
	PlanPatch.apply(legacy, 0)
	RunPlanSystem.patch(legacy, 0)
	assert_object(legacy.plan).is_null()
