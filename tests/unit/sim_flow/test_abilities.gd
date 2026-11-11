extends GdUnitTestSuite
## AbilitySystem: activation, EMP and boss immunity, every refusal (A12).


func _combat_world() -> SimWorld:
	return FlowKit.in_phase(GameState.Id.SPAWNING, 1)


func test_emp_stuns_normals_180_ticks_and_the_boss_60_and_cools_down_2100() -> void:
	var w: SimWorld = _combat_world()
	var skitter: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	var hollow: int = FlowKit.spawn(w, Ids.EN_HOLLOW)
	var rusher: int = FlowKit.spawn(w, Ids.EN_RUSHER)
	var boss: int = FlowKit.spawn(w, Ids.EN_HULK)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(w.enemies.stun_ticks[skitter]).is_equal(180)
	assert_int(w.enemies.stun_ticks[hollow]).is_equal(180)
	assert_int(w.enemies.stun_ticks[rusher]).is_equal(180)
	assert_int(w.enemies.stun_ticks[boss]).is_equal(60)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(2100)
	assert_int(w.abilities.active_left[Ids.AB_EMP]).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.ENEMY_STUNNED)).is_equal(4)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ACTIVATED)).is_equal(1)
	var activated: SimEvent = FlowKit.events_of(w, SimEventKind.Id.ABILITY_ACTIVATED)[0]
	assert_int(activated.a).is_equal(Ids.AB_EMP)
	assert_int(activated.b).is_equal(1)


func test_emp_leaves_empty_store_slots_alone() -> void:
	var w: SimWorld = _combat_world()
	var dead: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	var alive: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	w.kill_enemy(dead, DamageSource.Id.WARDEN)
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	assert_int(w.enemies.stun_ticks[dead]).is_equal(0)
	assert_int(w.enemies.stun_ticks[alive]).is_equal(180)
	assert_int(FlowKit.count(w, SimEventKind.Id.ENEMY_STUNNED)).is_equal(1)


func test_emp_never_shortens_a_longer_stun_and_replaces_a_shorter_one() -> void:
	var w: SimWorld = _combat_world()
	var longer: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	var shorter: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	w.enemies.stun_ticks[longer] = 500
	w.enemies.stun_ticks[shorter] = 10
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	assert_int(w.enemies.stun_ticks[longer]).is_equal(500)
	assert_int(w.enemies.stun_ticks[shorter]).is_equal(180)
	assert_int(FlowKit.count(w, SimEventKind.Id.ENEMY_STUNNED)).is_equal(1)


func test_a_stunned_enemy_is_released_after_exactly_180_steps() -> void:
	var w: SimWorld = _combat_world()
	var skitter: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	FlowKit.ability_steps(w, 179)
	assert_int(w.enemies.stun_ticks[skitter]).is_equal(1)
	FlowKit.ability_steps(w, 1)
	assert_int(w.enemies.stun_ticks[skitter]).is_equal(0)
	assert_int(w.enemies.stun_immune_ticks[skitter]).is_equal(0)


func test_boss_is_immune_for_300_ticks_after_its_stun_ends() -> void:
	var w: SimWorld = _combat_world()
	var boss: int = FlowKit.spawn(w, Ids.EN_HULK)
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	FlowKit.ability_steps(w, 59)
	assert_int(w.enemies.stun_ticks[boss]).is_equal(1)
	assert_int(w.enemies.stun_immune_ticks[boss]).is_equal(0)
	FlowKit.ability_steps(w, 1)
	assert_int(w.enemies.stun_ticks[boss]).is_equal(0)
	assert_int(w.enemies.stun_immune_ticks[boss]).is_equal(300)
	FlowKit.ability_steps(w, 299)
	assert_int(w.enemies.stun_immune_ticks[boss]).is_equal(1)
	FlowKit.ability_steps(w, 1)
	assert_int(w.enemies.stun_immune_ticks[boss]).is_equal(0)


func test_emp_skips_an_immune_boss_but_stuns_everything_else() -> void:
	var w: SimWorld = _combat_world()
	var boss: int = FlowKit.spawn(w, Ids.EN_HULK)
	var skitter: int = FlowKit.spawn(w, Ids.EN_SKITTER)
	w.enemies.stun_immune_ticks[boss] = 50
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	assert_int(w.enemies.stun_ticks[boss]).is_equal(0)
	assert_int(w.enemies.stun_ticks[skitter]).is_equal(180)


func test_boss_can_be_stunned_again_once_the_immunity_is_over() -> void:
	var w: SimWorld = _combat_world()
	var boss: int = FlowKit.spawn(w, Ids.EN_HULK)
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	FlowKit.ability_steps(w, 60 + 300)
	assert_int(w.enemies.stun_immune_ticks[boss]).is_equal(0)
	FlowKit.ability_steps(w, 2100)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(w.enemies.stun_ticks[boss]).is_equal(60)


func test_emp_cooldown_blocks_until_exactly_2100_steps_after_activation() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	FlowKit.ability_steps(w, 2099)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(1)
	assert_bool(w.abilities.is_ready(Ids.AB_EMP)).is_false()
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_EMP)).is_equal(Reason.Id.ON_COOLDOWN)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(1)
	FlowKit.ability_steps(w, 1)
	assert_bool(w.abilities.is_ready(Ids.AB_EMP)).is_true()
	assert_int(AbilitySystem.activate(w, 3, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(2100)


func test_a_rejected_activation_pushes_the_reason_and_starts_nothing() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	var before: String = w.state_hash()
	assert_int(AbilitySystem.activate(w, 42, Ids.AB_EMP)).is_equal(Reason.Id.ON_COOLDOWN)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ACTIVATED)).is_equal(1)
	var rejected: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.ABILITY_REJECTED)
	assert_int(rejected.size()).is_equal(1)
	assert_int(rejected[0].a).is_equal(Ids.AB_EMP)
	assert_int(rejected[0].b).is_equal(Reason.Id.ON_COOLDOWN)
	assert_float(rejected[0].f).is_equal(42.0)


func test_shield_and_overdrive_refuse_while_active_without_touching_cooldowns() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_SHIELD)
	AbilitySystem.activate(w, 2, Ids.AB_OVERDRIVE)
	var before: String = w.state_hash()
	assert_int(AbilitySystem.activate(w, 3, Ids.AB_SHIELD)).is_equal(Reason.Id.ALREADY_ACTIVE)
	assert_int(AbilitySystem.activate(w, 4, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.ALREADY_ACTIVE)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(0)
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(0)


func test_activation_outside_a_running_wave_is_refused_for_every_ability() -> void:
	var phases: Array[int] = [
		GameState.Id.PREPARING, GameState.Id.INTERMISSION, GameState.Id.VICTORY, GameState.Id.DEFEAT
	]
	for phase_id: int in phases:
		var w: SimWorld = FlowKit.in_phase(phase_id, 2)
		var before: String = w.state_hash()
		for ability: int in Ids.ABILITIES.size():
			assert_int(AbilitySystem.activate(w, ability + 1, ability)).is_equal(Reason.Id.WRONG_STATE)
			assert_int(w.ability_block_reason(ability)).is_equal(Reason.Id.WRONG_STATE)
		assert_str(w.state_hash()).is_equal(before)
		assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(0)
		assert_float(w.shield_hp).is_equal(0.0)


func test_abilities_are_legal_in_spawning_and_clearing() -> void:
	for phase_id: int in [GameState.Id.SPAWNING, GameState.Id.CLEARING]:
		var w: SimWorld = FlowKit.in_phase(phase_id, 3)
		for ability: int in Ids.ABILITIES.size():
			assert_int(w.ability_block_reason(ability)).is_equal(Reason.Id.OK)
			assert_int(AbilitySystem.activate(w, ability + 1, ability)).is_equal(Reason.Id.OK)


func test_unknown_ability_index_is_refused() -> void:
	var w: SimWorld = _combat_world()
	var before: String = w.state_hash()
	for bad: int in [-1, 3, 17]:
		assert_int(AbilitySystem.activate(w, 9, bad)).is_equal(Reason.Id.UNKNOWN_ID)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_REJECTED)).is_equal(3)


func test_abilities_do_not_start_each_other() -> void:
	var w: SimWorld = _combat_world()
	AbilitySystem.activate(w, 1, Ids.AB_EMP)
	assert_bool(w.abilities.is_ready(Ids.AB_SHIELD)).is_true()
	assert_bool(w.abilities.is_ready(Ids.AB_OVERDRIVE)).is_true()
	assert_float(w.shield_hp).is_equal(0.0)
	assert_int(w.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(0)
