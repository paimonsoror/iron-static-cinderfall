extends GdUnitTestSuite
## HarnessChecker: each invariant it watches is reported when broken (fed hand-made events and states), and a clean
## stream stays clean. The whole-run use is in tests/integration/sim.


var w: SimWorld
var chk: HarnessChecker


func before_test() -> void:
	w = TestContent.world()
	chk = HarnessChecker.new(w)


func _ev(kind: int, a: int = 0, b: int = 0, f: float = 0.0) -> SimEvent:
	var e: SimEvent = SimEvent.new()
	e.kind = kind
	e.a = a
	e.b = b
	e.f = f
	return e


func _feed(events: Array[SimEvent]) -> void:
	chk.after_step(w, events)


func _has(text: String) -> bool:
	for v: String in chk.violations:
		if v.contains(text):
			return true
	return false


func test_a_fresh_world_and_no_events_are_clean() -> void:
	_feed([])
	chk.finish(w, 0)
	assert_int(chk.violations.size()).is_equal(0)


func test_a_kill_is_paid_once_and_counted() -> void:
	var events: Array[SimEvent] = [_ev(SimEventKind.Id.ENEMY_SPAWNED, 1, Ids.EN_SKITTER), _ev(SimEventKind.Id.ENEMY_KILLED, 1)]
	_feed(events)
	assert_int(chk.spawned).is_equal(1)
	assert_int(chk.killed).is_equal(1)
	assert_int(chk.reward_sum).is_equal(20)
	assert_int(chk.scrap_by_wave[0]).is_equal(20)


func test_a_second_kill_of_the_same_enemy_is_flagged() -> void:
	var events: Array[SimEvent] = [
		_ev(SimEventKind.Id.ENEMY_SPAWNED, 1, Ids.EN_SKITTER), _ev(SimEventKind.Id.ENEMY_KILLED, 1), _ev(SimEventKind.Id.ENEMY_KILLED, 1)
	]
	_feed(events)
	assert_bool(_has("killed twice")).is_true()


func test_a_kill_without_a_spawn_is_flagged() -> void:
	var events: Array[SimEvent] = [_ev(SimEventKind.Id.ENEMY_KILLED, 9)]
	_feed(events)
	assert_bool(_has("never spawned")).is_true()


func test_scrap_that_does_not_match_the_kill_rewards_is_flagged() -> void:
	var events: Array[SimEvent] = [_ev(SimEventKind.Id.ENEMY_SPAWNED, 1, Ids.EN_HOLLOW), _ev(SimEventKind.Id.ENEMY_KILLED, 1)]
	_feed(events)
	chk.finish(w, 0)  # the world itself never paid the 35
	assert_bool(_has("Scrap earned 0 != sum of kill rewards 35")).is_true()


func test_more_than_the_cap_alive_is_flagged() -> void:
	for k: int in w.content.mission.enemy_cap + 1:
		w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	_feed([])
	assert_bool(_has("cap 50")).is_true()


func test_a_non_finite_position_is_flagged() -> void:
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	w.enemies.x[i] = NAN
	_feed([])
	assert_bool(_has("non-finite")).is_true()


func test_the_core_healing_is_flagged_and_losses_are_booked_per_wave() -> void:
	w.set_core_hp(900.0)
	_feed([])
	assert_float(chk.core_lost_by_wave[0]).is_equal(100.0)
	assert_int(chk.violations.size()).is_equal(0)
	w.set_core_hp(950.0)
	_feed([])
	assert_bool(_has("core healed")).is_true()


func test_a_wave_cleared_with_enemies_alive_is_flagged() -> void:
	w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	var events: Array[SimEvent] = [_ev(SimEventKind.Id.WAVE_CLEARED, 1)]
	_feed(events)
	assert_bool(_has("cleared with 1 enemies alive")).is_true()


func test_enemies_during_an_intermission_are_flagged() -> void:
	w = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	chk = HarnessChecker.new(w)
	w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	_feed([])
	assert_bool(_has("during an intermission")).is_true()


func test_a_successful_purchase_must_have_been_paid_for() -> void:
	var events: Array[SimEvent] = [_ev(SimEventKind.Id.PURCHASE_RESOLVED, 1, Reason.Id.OK, float(Ids.UP_DAMAGE))]
	_feed(events)
	assert_int(chk.purchases_ok).is_equal(1)
	assert_int(chk.spent_expected).is_equal(175)
	chk.finish(w, 0)  # the world never debited 175 and never raised the level
	assert_bool(_has("Scrap spent 0")).is_true()
	assert_bool(_has("upgrade levels add up to 0")).is_true()


func test_a_refused_purchase_costs_nothing_and_is_answered_once() -> void:
	var w2: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	var c2: HarnessChecker = HarnessChecker.new(w2)
	w2.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))  # no Scrap
	w2.step()
	c2.after_step(w2, w2.events.drain())
	c2.finish(w2, 1)
	assert_int(c2.violations.size()).is_equal(0)
	assert_int(c2.purchases_ok).is_equal(0)


func test_a_command_that_was_never_applied_is_flagged() -> void:
	chk.finish(w, 3)  # the bot says it submitted three; the log has none
	assert_bool(_has("3 commands submitted, 0 applied")).is_true()


func test_the_violation_list_is_capped() -> void:
	for k: int in HarnessChecker.MAX_VIOLATIONS + 10:
		_feed([_ev(SimEventKind.Id.ENEMY_KILLED, 1000 + k)])
	assert_int(chk.violations.size()).is_equal(HarnessChecker.MAX_VIOLATIONS)
