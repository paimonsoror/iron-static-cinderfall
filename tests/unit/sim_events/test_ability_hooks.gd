extends GdUnitTestSuite
## V4-V: the call points AbilitySystem owes to CoreHooks (CONTENT 3.5): on_ability after an activation (cascade,
## overclocked_core), on_emp after the stun is applied (emp_overload), on_shield_end after the cooldown starts (shield_burst,
## amber_surge). The hooks themselves are V4-C's; these tests check that they are called at the right moment.


func test_cascade_takes_six_seconds_off_the_other_cooldowns_after_an_activation() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"cascade": 1})
	w.abilities.cooldown_left[Ids.AB_EMP] = 1000
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 200
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(640)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(0)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_true()
	# a refusal runs no hook
	w.abilities.cooldown_left[Ids.AB_EMP] = 1000
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.ALREADY_ACTIVE)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(1000)


func test_a_locked_activation_is_a_refusal_and_runs_no_hook() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"cascade": 1})
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 500
	w.events_state.ability_lock_ticks = 100
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(500)


func test_emp_overload_hurts_the_stunned_after_the_stun_is_applied() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"emp_overload": 2})
	var a: int = VarietyVKit.place(w, Ids.EN_SKITTER, 3.0, 3.0)
	var b: int = VarietyVKit.place(w, Ids.EN_SKITTER, 4.0, 3.0)
	VarietyVKit.tough(w, a)
	VarietyVKit.tough(w, b)
	w.enemies.stun_immune_ticks[b] = 100  # it is not stunned, so it takes nothing
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_float(VarietyVKit.taken(w, a)).is_equal(120.0)  # 60 a stack
	assert_float(VarietyVKit.taken(w, b)).is_equal(0.0)
	assert_int(w.enemies.stun_ticks[a]).is_greater(0)


func test_shield_burst_goes_off_when_the_shield_ends_after_its_cooldown_started() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"shield_burst": 1})
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -5.5, 3.0)  # 2 m from the core
	var far: int = VarietyVKit.place(w, Ids.EN_SKITTER, 6.0, 3.0)
	VarietyVKit.tough(w, near)
	VarietyVKit.tough(w, far)
	var shield: AbilityDef = w.content.abilities[Ids.AB_SHIELD]
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	VarietyVKit.run(w, shield.duration_ticks - 1)
	assert_float(VarietyVKit.taken(w, near)).is_equal(0.0)
	VarietyVKit.tick(w)  # the shield ends in this step
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(shield.cooldown_ticks)
	assert_float(VarietyVKit.taken(w, near)).is_equal(150.0)
	assert_float(VarietyVKit.taken(w, far)).is_equal(0.0)


func test_a_shield_the_enemy_broke_also_ends_with_the_hook() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"shield_burst": 1})
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -5.5, 3.0)
	VarietyVKit.tough(w, near)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	w.shield_hp = 0.0  # the shield took its last point
	VarietyVKit.tick(w)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_float(VarietyVKit.taken(w, near)).is_equal(150.0)


func test_the_free_shield_of_amber_surge_gives_the_shield_cooldown_back_when_it_ends() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"amber_surge": 1})
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 77
	CoreHooks.on_core_changed(w, w.core_max_hp * 0.6, w.core_max_hp * 0.4)  # the first drop below half
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	assert_float(w.shield_hp).is_greater(0.0)
	VarietyVKit.run(w, w.abilities.active_left[Ids.AB_SHIELD])
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(77)  # not the full cooldown: the shield was free


func test_the_end_of_a_run_ends_the_shield_without_the_hooks() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"shield_burst": 1})
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -5.5, 3.0)
	VarietyVKit.tough(w, near)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	AbilitySystem.end_all(w)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_float(VarietyVKit.taken(w, near)).is_equal(0.0)


func test_the_legacy_world_runs_no_hook_and_keeps_its_numbers() -> void:
	var w: SimWorld = TestContent.world(1)
	w.phase = GameState.Id.SPAWNING
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	for _n: int in w.content.abilities[Ids.AB_SHIELD].duration_ticks:
		w.tick += 1
		AbilitySystem.step(w)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(w.content.abilities[Ids.AB_SHIELD].cooldown_ticks)
