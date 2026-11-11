extends GdUnitTestSuite
## AbilitySystem timers: shield and overdrive durations, cooldown starts, early shield end, freeze rules (A12).


func _combat_world() -> SimWorld:
	return FlowKit.in_phase(GameState.Id.SPAWNING, 1)


func test_shield_sets_100_absorb_for_480_ticks() -> void:
	var w: SimWorld = _combat_world()
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_float(w.shield_hp).is_equal(100.0)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(480)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(0)
	var changed: SimEvent = FlowKit.events_of(w, SimEventKind.Id.SHIELD_CHANGED)[0]
	assert_float(changed.f).is_equal(100.0)
	assert_float(changed.g).is_equal(100.0)


func test_shield_ends_when_time_runs_out_and_starts_a_3000_tick_cooldown() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_SHIELD)
	FlowKit.ability_steps(w, 479)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(1)
	assert_float(w.shield_hp).is_equal(100.0)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ENDED)).is_equal(0)
	FlowKit.ability_steps(w, 1)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(0)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(3000)
	var ended: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.ABILITY_ENDED)
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0].a).is_equal(Ids.AB_SHIELD)
	var changed: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.SHIELD_CHANGED)
	assert_float(changed[changed.size() - 1].f).is_equal(0.0)


func test_shield_cooldown_runs_from_the_end_and_frees_it_after_3000_steps() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_SHIELD)
	FlowKit.ability_steps(w, 480)
	FlowKit.ability_steps(w, 2999)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(1)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_SHIELD)).is_equal(Reason.Id.ON_COOLDOWN)
	FlowKit.ability_steps(w, 1)
	assert_bool(w.abilities.is_ready(Ids.AB_SHIELD)).is_true()
	assert_int(AbilitySystem.activate(w, 3, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_float(w.shield_hp).is_equal(100.0)


func test_shield_ends_early_the_step_after_it_is_used_up() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_SHIELD)
	FlowKit.ability_steps(w, 100)
	w.shield_hp = 0.0
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	FlowKit.ability_steps(w, 1)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(0)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(3000)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ENDED)).is_equal(1)


func test_a_damaged_shield_stays_up_until_its_time_is_over() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_SHIELD)
	w.shield_hp = 10.0
	FlowKit.ability_steps(w, 479)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	assert_float(w.shield_hp).is_equal(10.0)
	FlowKit.ability_steps(w, 1)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_float(w.shield_hp).is_equal(0.0)


func test_overdrive_is_active_360_ticks_then_cools_down_3600() -> void:
	var w: SimWorld = _combat_world()
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(360)
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(0)
	FlowKit.ability_steps(w, 359)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_true()
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(0)
	FlowKit.ability_steps(w, 1)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(3600)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ENDED)).is_equal(1)


func test_overdrive_cooldown_runs_from_the_end_and_frees_it_after_3600_steps() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)
	FlowKit.ability_steps(w, 360)
	FlowKit.ability_steps(w, 3599)
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(1)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.ON_COOLDOWN)
	FlowKit.ability_steps(w, 1)
	assert_int(AbilitySystem.activate(w, 3, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)


func test_a_command_counts_its_own_tick_toward_the_timers() -> void:
	var w: SimWorld = _combat_world()
	w.submit(SimCommand.ability(1, Ids.AB_EMP))
	w.submit(SimCommand.ability(2, Ids.AB_SHIELD))
	w.submit(SimCommand.ability(3, Ids.AB_OVERDRIVE))
	w.step()
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(2099)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(479)
	assert_int(w.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(359)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ACTIVATED)).is_equal(3)


func test_cooldowns_keep_running_in_preparing_and_intermission() -> void:
	for phase_id: int in [GameState.Id.PREPARING, GameState.Id.INTERMISSION]:
		var w: SimWorld = FlowKit.in_phase(phase_id, 1)
		w.abilities.cooldown_left[Ids.AB_EMP] = 100
		w.abilities.cooldown_left[Ids.AB_SHIELD] = 100
		FlowKit.step_n(w, 40)
		assert_int(w.phase).is_equal(phase_id)
		assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(60)
		assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(60)


func test_timers_do_not_move_once_the_run_is_over() -> void:
	for phase_id: int in [GameState.Id.VICTORY, GameState.Id.DEFEAT]:
		var w: SimWorld = FlowKit.in_phase(phase_id, 5)
		w.abilities.cooldown_left[Ids.AB_EMP] = 100
		w.abilities.active_left[Ids.AB_OVERDRIVE] = 100
		var before: String = w.state_hash()
		FlowKit.step_n(w, 10)
		assert_str(w.state_hash()).is_equal(before)
		assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(100)


func test_an_ability_that_ends_leaves_the_others_running() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)
	FlowKit.ability_steps(w, 100)
	AbilitySystem.activate(w, 2, Ids.AB_SHIELD)
	FlowKit.ability_steps(w, 260)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(3600)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(220)
	assert_float(w.shield_hp).is_equal(100.0)
