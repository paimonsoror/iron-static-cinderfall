extends GdUnitTestSuite
## PhaseSystem endings: DEFEAT precedence, RUN_FINISHED exactly once, a finished run is frozen (A07, A14).


func _finished(w: SimWorld) -> Array[SimEvent]:
	return FlowKit.events_of(w, SimEventKind.Id.RUN_FINISHED)


func test_core_at_zero_defeats_the_run_the_same_tick_while_spawning() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 2)
	w.set_core_hp(0.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.result()).is_equal(RunResult.Id.DEFEAT)
	assert_bool(w.is_over()).is_true()
	assert_int(w.tick).is_equal(1)


func test_core_at_zero_defeats_the_run_while_clearing() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 3)
	FlowKit.spawn(w, Ids.EN_HULK)
	w.set_core_hp(0.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)


func test_defeat_wins_over_the_last_enemy_dying_on_the_same_tick() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 1)
	var last: int = FlowKit.spawn(w, Ids.EN_HULK)
	w.set_core_hp(0.0)
	w.kill_enemy(last, DamageSource.Id.WARDEN)
	assert_int(w.alive_count()).is_equal(0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.waves_completed).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.WAVE_CLEARED)).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.INTERMISSION_STARTED)).is_equal(0)


func test_defeat_wins_over_victory_on_the_last_wave() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	w.waves_completed = 4
	w.set_core_hp(0.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.waves_completed).is_equal(4)


func test_defeat_wins_over_a_fully_spawned_wave() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	w.phase_state.force_wave_spawned = true
	w.set_core_hp(0.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)


func test_a_surviving_core_does_not_end_the_run() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 1)
	FlowKit.spawn(w, Ids.EN_HULK)
	w.set_core_hp(0.5)
	FlowKit.step_n(w, 5)
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	assert_int(_finished(w).size()).is_equal(0)


func test_core_at_zero_cannot_defeat_outside_a_running_wave() -> void:
	var preparing: SimWorld = FlowKit.world()
	preparing.set_core_hp(0.0)
	preparing.step()
	assert_int(preparing.phase).is_equal(GameState.Id.PREPARING)
	var resting: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	resting.set_core_hp(0.0)
	resting.step()
	assert_int(resting.phase).is_equal(GameState.Id.INTERMISSION)


func test_defeat_after_two_cleared_waves_reports_two_and_pays_defeat_data() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180)
	FlowKit.clear_wave(w)
	FlowKit.run_until(w, GameState.Id.SPAWNING, 600)
	FlowKit.clear_wave(w)
	FlowKit.run_until(w, GameState.Id.SPAWNING, 600)
	assert_int(w.wave).is_equal(3)
	w.set_core_hp(0.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.waves_completed).is_equal(2)
	var s: RunSummary = w.summary("run-d")
	assert_int(s.result).is_equal(RunResult.Id.DEFEAT)
	assert_int(s.waves_completed).is_equal(2)
	assert_int(s.data_reward).is_equal(20)


func test_run_finished_for_defeat_carries_result_waves_and_core() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 4)
	w.waves_completed = 3
	w.set_core_hp(0.0)
	w.step()
	var finished: Array[SimEvent] = _finished(w)
	assert_int(finished.size()).is_equal(1)
	assert_int(finished[0].a).is_equal(RunResult.Id.DEFEAT)
	assert_int(finished[0].b).is_equal(3)
	assert_float(finished[0].f).is_equal(0.0)
	assert_int(finished[0].tick).is_equal(1)


func test_run_finished_for_victory_carries_result_waves_and_core() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	w.waves_completed = 4
	w.set_core_hp(820.0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	var finished: Array[SimEvent] = _finished(w)
	assert_int(finished.size()).is_equal(1)
	assert_int(finished[0].a).is_equal(RunResult.Id.VICTORY)
	assert_int(finished[0].b).is_equal(5)
	assert_float(finished[0].f).is_equal(820.0)
	assert_int(w.summary("run-v").data_reward).is_equal(100 + 41)


func test_run_finished_is_pushed_exactly_once() -> void:
	for target: int in [GameState.Id.VICTORY, GameState.Id.DEFEAT]:
		var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
		if target == GameState.Id.DEFEAT:
			w.set_core_hp(0.0)
		w.step()
		assert_int(w.phase).is_equal(target)
		FlowKit.step_n(w, 20)
		PhaseSystem.post_step(w)
		PhaseSystem.pre_step(w)
		assert_int(_finished(w).size()).is_equal(1)
		assert_bool(w.phase_state.run_finished).is_true()


func test_step_after_the_end_changes_nothing() -> void:
	for target: int in [GameState.Id.VICTORY, GameState.Id.DEFEAT]:
		var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
		if target == GameState.Id.DEFEAT:
			w.set_core_hp(0.0)
		w.step()
		var hash_at_end: String = w.state_hash()
		var tick_at_end: int = w.tick
		var events_at_end: int = w.events.total
		w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
		FlowKit.step_n(w, 50)
		assert_str(w.state_hash()).is_equal(hash_at_end)
		assert_int(w.tick).is_equal(tick_at_end)
		assert_int(w.events.total).is_equal(events_at_end)
		assert_int(w.command_queue.size()).is_equal(1)


func test_state_hash_covers_the_flow_state() -> void:
	var a: SimWorld = FlowKit.world()
	var b: SimWorld = FlowKit.world()
	assert_str(a.state_hash()).is_equal(b.state_hash())
	b.phase_state.force_wave_spawned = true
	assert_str(a.state_hash()).is_not_equal(b.state_hash())
	b.phase_state.force_wave_spawned = false
	assert_str(a.state_hash()).is_equal(b.state_hash())
	b.phase_state.mark_seen(77)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())
	var c: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	var d: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	d.phase_state.run_finished = true
	assert_str(c.state_hash()).is_not_equal(d.state_hash())


func _play(run_seed: int, buy_damage: bool) -> SimWorld:
	var w: SimWorld = FlowKit.world(run_seed)
	w.add_scrap(2000)
	if buy_damage:
		w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	FlowKit.step_n(w, 180)
	w.submit(SimCommand.ability(2, Ids.AB_SHIELD))
	w.submit(SimCommand.purchase(3, Ids.UP_AUTO_TURRET))
	FlowKit.step_n(w, 3)
	FlowKit.clear_wave(w)
	w.submit(SimCommand.skip(4))
	FlowKit.step_n(w, 2)
	FlowKit.clear_wave(w)
	return w


func test_same_seed_and_commands_give_the_same_hashes() -> void:
	var a: SimWorld = _play(11, true)
	var b: SimWorld = _play(11, true)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.events.event_hash).is_equal(b.events.event_hash)
	assert_int(a.events.total).is_equal(b.events.total)
	assert_int(a.waves_completed).is_equal(2)


func test_a_different_command_stream_gives_a_different_hash() -> void:
	var a: SimWorld = _play(11, true)
	var b: SimWorld = _play(11, false)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())
