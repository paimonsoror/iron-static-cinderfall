extends GdUnitTestSuite
## V4-V: the clock of the ten events (VARIETY_SPEC 7.2, B07 "every event warns first"): for each event the tick of its
## warning, its start and its end, planned at an offset of 100 ticks into wave 4. The warning is announced with EVENT_WARNED
## (its payload carries the warning ticks), the start is exactly warn_ticks later, the end duration_ticks after the start.

const AT: int = 100

## event index, warn ticks (CONTENT 6), duration ticks
const CLOCK: Array[Array] = [
	[VarietyVKit.ACCORD, 0, 600],
	[VarietyVKit.DROP, 180, 0],
	[VarietyVKit.SURGE, 240, 600],
	[VarietyVKit.RUNAWAY, 240, 72],
	[VarietyVKit.STATIC, 360, 720],
	[VarietyVKit.BREACH, 150, 0],
	[VarietyVKit.RECOUNT, 180, 0],
]


func _planned(event_index: int) -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, 4)
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, event_index, AT)
	return w


func test_every_world_event_warns_then_starts_then_ends_on_its_ticks() -> void:
	for row: Array in CLOCK:
		var event_index: int = row[0]
		var warn: int = row[1]
		var duration: int = row[2]
		var w: SimWorld = _planned(event_index)
		VarietyVKit.run(w, AT + warn + duration + 5)
		var label: String = String(w.content.events[event_index].id)
		assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_WARNED, event_index)).override_failure_message(label).is_not_empty()
		assert_int(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_WARNED, event_index)[0]).override_failure_message(label).is_equal(AT)
		assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_STARTED, event_index)).override_failure_message(label).is_equal([AT + warn])
		assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_ENDED, event_index)).override_failure_message(label).is_equal([AT + warn + duration])
		var warned: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)[0]
		assert_int(warned.b).override_failure_message(label).is_equal(warn)
		assert_int(w.events_state.active_count()).override_failure_message(label).is_equal(0)
		assert_int(w.stats.events_seen[event_index]).override_failure_message(label).is_equal(1)


func test_the_data_agrees_with_the_clock_table() -> void:
	var w: SimWorld = VarietyVKit.world()
	for row: Array in CLOCK:
		var def: EventDef = w.content.events[row[0]]
		assert_int(def.warn_ticks).override_failure_message(String(def.id)).is_equal(row[1])
		assert_int(def.duration_ticks).override_failure_message(String(def.id)).is_equal(row[2])
	assert_int(w.content.events[VarietyVKit.VENT].warn_ticks).is_equal(30)
	assert_int(w.content.events[VarietyVKit.FREIGHT].warn_ticks).is_equal(240)
	assert_int(w.content.events[VarietyVKit.STRIKE].warn_ticks).is_equal(120)


func test_every_event_with_an_effect_warns_before_it_acts_and_the_minimum_warnings_hold() -> void:
	var w: SimWorld = VarietyVKit.world()
	for def: EventDef in w.content.events:
		if def.id == &"accord_window":
			continue  # helpful and harmless: it opens as it is announced (warn_s 0)
		assert_int(def.warn_ticks).override_failure_message(String(def.id)).is_greater(0)
	var bodies: Array[StringName] = [&"floor_breach", &"recount", &"supply_drop"]
	for id: StringName in bodies:
		assert_int(w.content.event_def(id).warn_ticks).override_failure_message("spawns enemies: %s" % id).is_greater_equal(150)
	var tools: Array[StringName] = [&"power_surge", &"runaway_freight"]
	for id: StringName in tools:
		assert_int(w.content.event_def(id).warn_ticks).override_failure_message("changes tools: %s" % id).is_greater_equal(240)
	assert_int(w.content.event_def(&"static_front").warn_ticks).is_greater_equal(360)


func test_an_event_planned_later_than_the_wave_is_old_never_starts_and_the_cursor_waits() -> void:
	var w: SimWorld = _planned(VarietyVKit.ACCORD)
	VarietyVKit.run(w, AT - 1)
	assert_int(w.events_state.plan_cursor).is_equal(0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)
	VarietyVKit.tick(w)
	assert_int(w.events_state.plan_cursor).is_equal(1)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(1)
	assert_int(w.events_state.last_world_event).is_equal(VarietyVKit.ACCORD)


func test_two_events_of_a_wave_start_in_the_order_of_the_plan() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, VarietyVKit.DROP, 300)
	VarietyVKit.plan_event(w, 4, VarietyVKit.ACCORD, 100)
	VarietyVKit.run(w, 320)
	var warned: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.EVENT_WARNED)
	assert_int(warned.size()).is_equal(2)
	assert_int(warned[0].a).is_equal(VarietyVKit.ACCORD)
	assert_int(warned[0].tick).is_equal(100)
	assert_int(warned[1].a).is_equal(VarietyVKit.DROP)
	assert_int(warned[1].tick).is_equal(300)


func test_the_wave_clock_counts_from_the_tick_the_wave_began() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	VarietyVKit.clear_plan(w)
	VarietyVKit.run(w, 50)
	VarietyVKit.plan_event(w, 4, VarietyVKit.ACCORD, 100)
	VarietyVKit.begin_wave(w, 4)  # the wave restarts at tick 50
	VarietyVKit.run(w, 99)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_WARNED)).is_equal(0)
	VarietyVKit.tick(w)
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_WARNED)).is_equal([150])


func test_world_events_end_with_the_wave_and_leave_nothing_behind() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	VarietyVKit.run(w, AT + 360 + 10)
	assert_int(w.events_state.ability_lock_ticks).is_greater(0)
	w.phase = GameState.Id.INTERMISSION  # the last enemy died
	VarietyVKit.tick(w)
	assert_int(w.events_state.ability_lock_ticks).is_equal(0)
	assert_int(w.events_state.active_count()).is_equal(0)
	assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_ENDED, VarietyVKit.STATIC)).is_equal([w.tick])


func test_a_warning_that_the_wave_end_interrupts_is_cancelled_not_started() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	VarietyVKit.run(w, AT + 100)
	assert_int(w.events_state.active_count()).is_equal(1)
	w.phase = GameState.Id.INTERMISSION
	VarietyVKit.run(w, 400)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_STARTED)).is_equal(0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.EVENT_CANCELLED)).is_equal(1)
	assert_int(w.events_state.ability_lock_ticks).is_equal(0)


func test_the_events_the_player_calls_also_push_started_and_ended() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	EventSystem.grant_charges(w, VarietyVKit.FREIGHT, 1)
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_SKITTER, 3.0, -7.0))
	for event_index: int in [VarietyVKit.STRIKE, VarietyVKit.VENT, VarietyVKit.FREIGHT]:
		assert_int(VarietyVKit.call_on_next_tick(w, event_index)).is_equal(Reason.Id.OK)
	VarietyVKit.run(w, 400)
	for event_index: int in [VarietyVKit.STRIKE, VarietyVKit.VENT, VarietyVKit.FREIGHT]:
		var label: String = String(w.content.events[event_index].id)
		assert_int(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_STARTED, event_index).size()).override_failure_message(label).is_equal(1)
		assert_int(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_ENDED, event_index).size()).override_failure_message(label).is_equal(1)
	assert_int(w.events_state.active_count()).is_equal(0)


## The x, z the HUD reads for the first active event (RunApi.active_events()).
func _spot(w: SimWorld) -> Vector2:
	var row: Dictionary = SimRunQueries.active_events(w)[0]
	var x: float = row["x"]
	var z: float = row["z"]
	return Vector2(x, z)


## What the x, z of an active event mean (the HUD's edge arrows and the ground decals read them through active_events()).
func test_the_position_of_an_event_is_the_place_to_look_at() -> void:
	var w: SimWorld = _planned(VarietyVKit.RECOUNT)
	w.plan.wave(4).act = 2
	VarietyVKit.run(w, AT)
	var recount: Vector2 = _spot(w)
	assert_float(recount.x).is_equal_approx(4.5, 0.001)  # the middle of the spawn edge the spawns will come in from
	assert_float(recount.y).is_equal_approx(-16.8, 0.001)
	var breach: SimWorld = _planned(VarietyVKit.BREACH)
	breach.plan.wave(4).act = 2
	breach.phase_state.act = 2
	VarietyVKit.run(breach, AT)
	assert_bool(breach.content.arena.breach_points.has(_spot(breach))).is_true()  # one of the opening points
	var freight: SimWorld = _planned(VarietyVKit.RUNAWAY)
	VarietyVKit.run(freight, AT)
	var lane: Vector2 = _spot(freight)
	assert_float(lane.x).is_equal(freight.content.arena.max_x)  # where the car comes in, on the lane it will take
	assert_bool(freight.content.arena.rail_z.has(lane.y)).is_true()
	VarietyVKit.run(freight, 240 + 36)  # half way through the pass
	var car: Vector2 = _spot(freight)
	assert_float(car.x).is_equal_approx(0.0, 0.5)  # the car itself
	assert_float(car.y).is_equal(lane.y)
	var drop: SimWorld = _planned(VarietyVKit.DROP)
	VarietyVKit.run(drop, AT)
	assert_bool(drop.content.arena.drop_points.has(_spot(drop))).is_true()
