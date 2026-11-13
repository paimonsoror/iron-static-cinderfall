extends GdUnitTestSuite
## V4-V (B08 for events): events are deterministic, in the snapshot and in the hash. A world is captured in the middle of a
## warning (or of an effect), written through JSON like the run file, restored into a fresh world, and both are played on:
## the hashes agree on every tick and every event lands on the same tick as in the uninterrupted run.


func _plan(w: SimWorld, event_index: int, offset: int = 1) -> void:
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, event_index, offset)


func _crowd(w: SimWorld) -> void:
	for k: int in 8:
		VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_SKITTER if k % 2 == 0 else Ids.EN_RUSHER, -4.0 + float(k) * 1.6, -7.0 + float(k % 3) * 3.0))


## Events from the tick after `from_tick`, as "kind@tick:a" strings.
func _log(w: SimWorld, from_tick: int) -> Array[String]:
	var out: Array[String] = []
	for e: SimEvent in w.events.peek():
		if e.tick > from_tick:
			out.append("%d@%d:%d:%d" % [e.kind, e.tick, e.a, e.b])
	return out


func _assert_resumes(w: SimWorld, capture_at: int, total: int, label: String) -> void:
	VarietyVKit.run(w, capture_at)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(WorldSnapshot.capture(w)))
	var twin: SimWorld = SimWorld.new(w.config)
	assert_bool(WorldSnapshot.restore(twin, doc)).override_failure_message(label + ": restore").is_true()
	assert_str(twin.state_hash()).override_failure_message(label + ": hash after restore").is_equal(w.state_hash())
	for _n: int in total - capture_at:
		VarietyVKit.tick(w)
		VarietyVKit.tick(twin)
		if twin.state_hash() != w.state_hash():
			assert_str(twin.state_hash()).override_failure_message("%s: drift at tick %d" % [label, w.tick]).is_equal(w.state_hash())
			return
	assert_array(_log(twin, capture_at)).override_failure_message(label + ": events").is_equal(_log(w, capture_at))
	assert_int(twin.events.event_hash).override_failure_message(label + ": event hash").is_equal(w.events.event_hash)


func test_a_static_front_warned_before_the_kill_starts_on_the_same_tick_afterwards() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.STATIC)
	_crowd(w)
	_assert_resumes(w, 200, 1200, "static front, mid-warning")
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([361])


func test_a_surge_resumes_in_the_middle_of_its_effect_and_the_brownout_follows() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.SURGE)
	_crowd(w)
	w.turrets.active[0] = 1
	_assert_resumes(w, 500, 1300, "core surge, mid-effect")
	assert_int(w.events_state.turret_offline_ticks).is_greater(0)


func test_a_relay_window_resumes_and_keeps_paying_double_until_its_tick() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.ACCORD)
	_assert_resumes(w, 300, 700, "relay window")


func test_a_supply_drop_resumes_before_the_crate_lands_and_with_its_squatters() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.DROP)
	_crowd(w)
	_assert_resumes(w, 100, 420, "supply drop, mid-warning")
	assert_bool(w.salvage.crate_active).is_true()
	var late: SimWorld = VarietyVKit.world(1, 4)
	_plan(late, VarietyVKit.DROP)
	_crowd(late)
	_assert_resumes(late, 250, 420, "supply drop, squatters walking")
	assert_int(late.events_state.squat_ids.size()).is_equal(3)


func test_a_runaway_freight_resumes_in_the_middle_of_its_pass() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.RUNAWAY)
	_crowd(w)
	_assert_resumes(w, 265, 340, "runaway freight, car on the rails")


func test_a_floor_breach_resumes_after_the_points_were_chosen() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	w.plan.wave(4).act = 2
	w.phase_state.act = 2
	_plan(w, VarietyVKit.BREACH)
	_assert_resumes(w, 80, 300, "floor breach, mid-warning")
	assert_int(VarietyVKit.alive(w)).is_equal(6)


func test_a_recount_resumes_and_moves_the_same_spawns() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	w.plan.wave(4).act = 2
	_plan(w, VarietyVKit.RECOUNT)
	var nav: NavState = w.nav
	for k: int in 16:
		nav.sched_due.append(3000 + k * 20)
		nav.sched_type.append(Ids.EN_SKITTER)
		nav.sched_group.append(0)
		nav.sched_ordinal.append(k)
		nav.sched_x.append(10.8)
		nav.sched_z.append(-6.0 + float(k) * 0.5)
	_assert_resumes(w, 90, 260, "recount, mid-warning")
	assert_int(w.nav.sched_due[0]).is_equal(181)


func test_a_strike_and_a_vent_in_the_air_land_on_the_same_tick_after_a_resume() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_crowd(w)
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.STRIKE)).is_equal(Reason.Id.OK)
	assert_int(VarietyVKit.call_on_next_tick(w, VarietyVKit.VENT)).is_equal(Reason.Id.OK)
	_assert_resumes(w, 10, 200, "strike and vent in flight")
	assert_int(VarietyVKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(2)


func test_a_lit_drum_blasts_on_the_same_tick_after_a_resume() -> void:
	var w: SimWorld = VarietyVKit.world(1, 1)
	var p: Vector2 = HazardDrums.position_of(w, 0)
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, p.x + 1.0, p.y))
	HazardDrums.ignite(w, 0)
	_assert_resumes(w, 3, 400, "fuel drum, fuse burning")
	assert_int(VarietyVKit.count(w, SimEventKind.Id.POOL_STARTED)).is_equal(1)
	assert_int(HazardDrums.alive_count(w)).is_equal(2)


func test_the_event_state_has_every_field_in_the_hash_and_round_trips_through_json() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_plan(w, VarietyVKit.SURGE)
	VarietyVKit.run(w, 400)
	var es: EventState = w.events_state
	var copy: EventState = EventState.new(es.charges.size())
	copy.from_dict(JSON.parse_string(JSON.stringify(es.to_dict())))
	var a: StateHasher = StateHasher.new()
	es.hash_into(a)
	var b: StateHasher = StateHasher.new()
	copy.hash_into(b)
	assert_str(b.finish()).is_equal(a.finish())
	assert_int(copy.turret_rate_milli).is_equal(2000)
	assert_int(copy.a_event.size()).is_equal(1)
