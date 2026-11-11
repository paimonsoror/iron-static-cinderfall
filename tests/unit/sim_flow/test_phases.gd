extends GdUnitTestSuite
## PhaseSystem: the wave loop PREPARING -> SPAWNING -> CLEARING -> INTERMISSION -> ... (A07).


func test_new_world_starts_preparing_with_a_180_tick_countdown() -> void:
	var w: SimWorld = FlowKit.world()
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(w.wave).is_equal(0)
	assert_int(w.waves_completed).is_equal(0)
	assert_int(w.phase_ticks_left).is_equal(180)


func test_preparing_lasts_180_ticks_then_wave_one_starts() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 179)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(w.phase_ticks_left).is_equal(1)
	assert_int(w.wave).is_equal(0)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(1)
	assert_int(w.phase_ticks_left).is_equal(0)
	assert_int(w.stats.wave_start_tick[1]).is_equal(180)


func test_wave_start_pushes_the_phase_change_and_the_wave_banner_event() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180)
	var changed: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PHASE_CHANGED)
	assert_int(changed.size()).is_equal(1)
	assert_int(changed[0].a).is_equal(GameState.Id.PREPARING)
	assert_int(changed[0].b).is_equal(GameState.Id.SPAWNING)
	var started: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
	assert_int(started.size()).is_equal(1)
	assert_int(started[0].a).is_equal(1)
	assert_int(started[0].b).is_equal(16)
	assert_int(started[0].tick).is_equal(180)


func test_spawning_does_not_end_while_the_wave_is_not_fully_spawned() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180 + 300)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_bool(w.phase_state.force_wave_spawned).is_false()


func test_spawning_becomes_clearing_once_the_wave_counts_as_fully_spawned() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	FlowKit.spawn(w, Ids.EN_HULK)
	w.phase_state.force_wave_spawned = true
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	assert_int(w.phase_ticks_left).is_equal(0)


func test_clearing_waits_for_every_enemy_to_die() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 1)
	var first: int = FlowKit.spawn(w, Ids.EN_HULK)
	var second: int = FlowKit.spawn(w, Ids.EN_HULK)
	FlowKit.step_n(w, 5)
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	w.kill_enemy(first, DamageSource.Id.WARDEN)
	FlowKit.step_n(w, 5)
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	w.kill_enemy(second, DamageSource.Id.WARDEN)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)


func test_wave_clear_counts_the_wave_and_starts_the_480_tick_intermission() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 2)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.waves_completed).is_equal(1)
	assert_int(w.wave).is_equal(2)
	assert_int(w.phase_ticks_left).is_equal(480)
	assert_int(w.stats.wave_clear_tick[2]).is_equal(1)
	var cleared: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.WAVE_CLEARED)
	assert_int(cleared.size()).is_equal(1)
	assert_int(cleared[0].a).is_equal(2)
	var intermission: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.INTERMISSION_STARTED)
	assert_int(intermission.size()).is_equal(1)
	assert_int(intermission[0].a).is_equal(2)
	assert_int(intermission[0].b).is_equal(480)


func test_intermission_lasts_480_ticks_then_the_next_wave_starts() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	FlowKit.step_n(w, 479)
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.phase_ticks_left).is_equal(1)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(2)
	var started: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
	assert_int(started[0].a).is_equal(2)
	assert_int(started[0].b).is_equal(36)


func test_skip_starts_the_next_wave_at_once() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 3)
	assert_int(PhaseSystem.skip_intermission(w)).is_equal(Reason.Id.OK)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(4)
	assert_int(w.phase_ticks_left).is_equal(0)
	var started: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.WAVE_STARTED)
	assert_int(started.size()).is_equal(1)
	assert_int(started[0].a).is_equal(4)
	assert_int(started[0].b).is_equal(76)


func test_skip_outside_the_intermission_is_wrong_state_and_changes_nothing() -> void:
	var phases: Array[int] = [
		GameState.Id.PREPARING,
		GameState.Id.SPAWNING,
		GameState.Id.CLEARING,
		GameState.Id.VICTORY,
		GameState.Id.DEFEAT,
	]
	for phase_id: int in phases:
		var w: SimWorld = FlowKit.in_phase(phase_id, 1)
		var before: String = w.state_hash()
		assert_int(PhaseSystem.skip_intermission(w)).is_equal(Reason.Id.WRONG_STATE)
		assert_str(w.state_hash()).is_equal(before)
		assert_int(FlowKit.count(w, SimEventKind.Id.WAVE_STARTED)).is_equal(0)


func test_five_cleared_waves_end_in_victory() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180)
	for n: int in range(1, 6):
		assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
		assert_int(w.wave).is_equal(n)
		FlowKit.clear_wave(w)
		assert_int(w.waves_completed).is_equal(n)
		if n < 5:
			assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
			assert_int(w.phase_ticks_left).is_equal(480)
			assert_int(FlowKit.run_until(w, GameState.Id.SPAWNING, 600)).is_equal(480)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(5)
	assert_int(w.wave).is_equal(5)
	assert_int(w.result()).is_equal(RunResult.Id.VICTORY)
	assert_bool(w.is_over()).is_true()
	assert_int(FlowKit.count(w, SimEventKind.Id.WAVE_CLEARED)).is_equal(5)
	assert_int(FlowKit.count(w, SimEventKind.Id.INTERMISSION_STARTED)).is_equal(4)
	var totals: PackedInt32Array = PackedInt32Array()
	for e: SimEvent in FlowKit.events_of(w, SimEventKind.Id.WAVE_STARTED):
		totals.append(e.b)
	assert_array(totals).is_equal(PackedInt32Array([16, 36, 54, 76, 103]))


func test_the_last_wave_needs_a_full_clear_for_victory() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	w.waves_completed = 4
	var boss: int = FlowKit.spawn(w, Ids.EN_HULK)
	FlowKit.step_n(w, 10)
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	w.kill_enemy(boss, DamageSource.Id.WARDEN)
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(5)
	assert_int(FlowKit.count(w, SimEventKind.Id.INTERMISSION_STARTED)).is_equal(0)


func test_every_phase_change_of_a_full_run_is_a_legal_transition() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180)
	for n: int in range(1, 6):
		FlowKit.clear_wave(w)
		if n < 5:
			FlowKit.run_until(w, GameState.Id.SPAWNING, 600)
	var changes: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PHASE_CHANGED)
	assert_int(changes.size()).is_equal(1 + 4 * 3 + 2)
	for e: SimEvent in changes:
		assert_bool(GameStateMachine.can_transition(e.a, e.b)).is_true()
	assert_int(changes[changes.size() - 1].b).is_equal(GameState.Id.VICTORY)


func test_countdown_is_zero_outside_preparing_and_intermission() -> void:
	var w: SimWorld = FlowKit.world()
	FlowKit.step_n(w, 180)
	assert_int(w.phase_ticks_left).is_equal(0)
	w.phase_state.force_wave_spawned = true
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.CLEARING)
	assert_int(w.phase_ticks_left).is_equal(0)
