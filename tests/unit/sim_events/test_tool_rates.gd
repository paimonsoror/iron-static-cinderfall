extends GdUnitTestSuite
## V4-V: the rates and locks on the player's tools that AbilitySystem and TurretSystem take from events, directives and
## jammers (VARIETY_SPEC 7.4, 13.2; CONTENT 5, 6): ability cooldown factors and rates, the numbers a directive adds to an
## ability, offline turrets, turret fire rates and damage.


func _world() -> SimWorld:
	return VarietyVKit.world(1, 4)


func _with_turret(w: SimWorld) -> void:
	w.turrets.active[0] = 1
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, -1.0, -1.5))


func _shots(w: SimWorld, ticks: int) -> int:
	var before: int = w.combat.shots_by_source[DamageSource.Id.TURRET_0]
	VarietyVKit.run(w, ticks)
	return w.combat.shots_by_source[DamageSource.Id.TURRET_0] - before


# --- ability numbers ---


func test_the_legacy_world_keeps_the_definitions_own_numbers() -> void:
	var w: SimWorld = TestContent.world(1)
	for a: int in 3:
		var def: AbilityDef = w.content.abilities[a]
		assert_int(AbilitySystem.cooldown_ticks_of(w, a)).is_equal(def.cooldown_ticks)
		assert_int(AbilitySystem.duration_ticks_of(w, a)).is_equal(def.duration_ticks)
	assert_float(AbilitySystem.absorb_of(w)).is_equal(w.content.abilities[Ids.AB_SHIELD].absorb)
	assert_int(AbilitySystem.emp_stun_ticks_of(w)).is_equal(w.content.abilities[Ids.AB_EMP].stun_ticks)
	assert_int(EventRates.cooldown_ticks(w)).is_equal(1)
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)


func test_the_cooldown_factors_of_the_directives_scale_the_cooldown_each_ability_starts() -> void:
	var w: SimWorld = _world()
	w.mods.emp_cd_mul = 0.85  # emp_capacitor
	w.mods.od_cd_mul = 0.9
	w.mods.ability_cd_mul = 0.5
	var emp: int = w.content.abilities[Ids.AB_EMP].cooldown_ticks
	assert_int(AbilitySystem.cooldown_ticks_of(w, Ids.AB_EMP)).is_equal(roundi(float(emp) * 0.85 * 0.5))
	assert_int(AbilitySystem.cooldown_ticks_of(w, Ids.AB_SHIELD)).is_equal(roundi(float(w.content.abilities[Ids.AB_SHIELD].cooldown_ticks) * 0.5))
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(roundi(float(emp) * 0.85 * 0.5))
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(0)  # it starts when the overdrive ends
	VarietyVKit.run(w, w.content.abilities[Ids.AB_OVERDRIVE].duration_ticks)
	assert_int(w.abilities.cooldown_left[Ids.AB_OVERDRIVE]).is_equal(roundi(float(w.content.abilities[Ids.AB_OVERDRIVE].cooldown_ticks) * 0.9 * 0.5))


func test_durations_absorb_and_stun_take_what_a_directive_adds() -> void:
	var w: SimWorld = _world()
	w.mods.shield_dur_add = 2.0
	w.mods.od_dur_add = 2.0
	w.mods.shield_absorb_add = 50.0
	w.mods.emp_stun_add = 1.0
	var shield: AbilityDef = w.content.abilities[Ids.AB_SHIELD]
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(shield.duration_ticks + 120)
	assert_float(w.shield_hp).is_equal(shield.absorb + 50.0)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_int(w.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(w.content.abilities[Ids.AB_OVERDRIVE].duration_ticks + 120)
	var enemy: int = VarietyVKit.place(w, Ids.EN_SKITTER, 3.0, 3.0)
	assert_int(AbilitySystem.activate(w, 3, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(w.enemies.stun_ticks[enemy]).is_equal(w.content.abilities[Ids.AB_EMP].stun_ticks + 60)


# --- cooldown rates ---


func _emp_cooldown_over(w: SimWorld, ticks: int) -> int:
	var before: int = w.abilities.cooldown_left[Ids.AB_EMP]
	VarietyVKit.run(w, ticks)
	return before - w.abilities.cooldown_left[Ids.AB_EMP]


func test_a_modifier_rate_runs_the_cooldowns_at_that_share() -> void:
	var w: SimWorld = _world()
	w.mods.ability_cd_rate_mul = 0.5
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(_emp_cooldown_over(w, 1000)).is_between(499, 501)
	w.mods.ability_cd_rate_mul = 1.0
	assert_int(_emp_cooldown_over(w, 500)).is_equal(500)


func test_a_living_jammer_slows_the_cooldowns_to_seventy_percent_and_only_while_it_works() -> void:
	var w: SimWorld = _world()
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	var jammer: int = VarietyVKit.place(w, Ids.EN_JAMMER, 8.0, 3.0)
	VarietyVKit.tough(w, jammer)
	assert_int(_emp_cooldown_over(w, 1000)).is_between(699, 701)
	w.enemies.stun_ticks[jammer] = 100000  # the EMP kills the aura for the stun
	assert_int(_emp_cooldown_over(w, 300)).is_equal(300)
	w.enemies.stun_ticks[jammer] = 0
	w.events_state.ability_lock_ticks = 100000  # a Static Front puts the aura down - and freezes the cooldowns
	assert_int(_emp_cooldown_over(w, 300)).is_equal(0)
	w.events_state.ability_lock_ticks = 0
	w.kill_enemy(jammer, DamageSource.Id.WARDEN)
	assert_int(_emp_cooldown_over(w, 300)).is_equal(300)


func test_two_jammers_do_not_stack_and_the_modifier_rate_multiplies() -> void:
	var w: SimWorld = _world()
	w.mods.ability_cd_rate_mul = 0.5
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_JAMMER, 8.0, 3.0))
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_JAMMER, 9.0, 4.0))
	assert_int(_emp_cooldown_over(w, 1000)).is_between(349, 351)  # 0.5 x 0.7


func test_the_lock_comes_before_the_cooldown_and_after_already_active() -> void:
	var w: SimWorld = _world()
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_EMP)).is_equal(Reason.Id.OK)
	assert_int(AbilitySystem.activate(w, 2, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	w.events_state.ability_lock_ticks = 100
	assert_int(w.ability_block_reason(Ids.AB_EMP)).is_equal(Reason.Id.LOCKED_BY_EVENT)  # on cooldown, but the lock says why
	assert_int(w.ability_block_reason(Ids.AB_SHIELD)).is_equal(Reason.Id.ALREADY_ACTIVE)
	assert_int(w.ability_block_reason(Ids.AB_OVERDRIVE)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	w.phase = GameState.Id.INTERMISSION
	assert_int(w.ability_block_reason(Ids.AB_OVERDRIVE)).is_equal(Reason.Id.WRONG_STATE)


# --- turrets ---


func test_offline_turrets_do_not_fire_or_charge_and_fire_at_once_when_back() -> void:
	var w: SimWorld = _world()
	_with_turret(w)
	var normal: int = _shots(w, 300)
	assert_int(normal).is_greater(10)
	EventSystem.take_turrets_offline(w, 240)  # a Tremor Rig stomp, 4 s
	assert_int(_shots(w, 239)).is_equal(0)
	VarietyVKit.tick(w)
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	assert_int(_shots(w, 300)).is_between(normal - 1, normal + 1)


func test_the_low_power_modifier_takes_the_turrets_offline_for_the_first_twelve_seconds() -> void:
	var w: SimWorld = _world()
	w.mods.turret_offline_ticks = 720.0
	VarietyVKit.begin_wave(w, 4)
	assert_int(w.events_state.turret_offline_ticks).is_equal(720)
	_with_turret(w)
	assert_int(_shots(w, 719)).is_equal(0)
	assert_int(_shots(w, 300)).is_greater(10)


func test_turret_fire_rate_follows_the_directive_overdrive_the_surge_and_the_jammer_aura() -> void:
	var w: SimWorld = _world()
	_with_turret(w)
	var base: int = _shots(w, 600)
	assert_int(base).is_greater(20)
	w.mods.t_rate_mul = 1.5  # turret_servos and friends
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1500)
	assert_int(_shots(w, 600)).is_between(roundi(float(base) * 1.5) - 1, roundi(float(base) * 1.5) + 1)
	w.mods.t_rate_mul = 1.0
	w.mods.set_flag(&"od_turrets", true)  # pad_capacitors: only while Overdrive runs
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)
	assert_int(AbilitySystem.activate(w, 1, Ids.AB_OVERDRIVE)).is_equal(Reason.Id.OK)
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(2000)
	w.mods.set_flag(&"od_turrets", false)
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 0
	var jammer: int = VarietyVKit.place(w, Ids.EN_JAMMER, 2.0, -1.5)  # 4.5 m from pad 0
	VarietyVKit.tough(w, jammer)
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(500)
	assert_int(EventRates.turret_rate_milli(w, 1)).is_equal(1000)  # pad 1 is 10 m away
	w.events_state.turret_rate_milli = 2000  # a surge on top of the aura: x2 x0.5
	w.events_state.turret_rate_ticks = 100
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)
	w.enemies.stun_ticks[jammer] = 100
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(2000)  # a stunned jammer has no aura
	w.enemies.stun_ticks[jammer] = 0
	w.events_state.ability_lock_ticks = 100  # a Static Front puts the aura down
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(2000)


func test_a_jammer_outside_seven_meters_leaves_the_pad_alone() -> void:
	var w: SimWorld = _world()
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_JAMMER, 4.6, -1.5))  # 7.1 m from pad 0
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_JAMMER, 4.4, -1.5))  # 6.9 m
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(500)


func test_turret_damage_follows_the_directive_factor() -> void:
	var w: SimWorld = _world()
	w.turrets.active[0] = 1
	var target: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -1.0, -1.5)
	VarietyVKit.tough(w, target)
	var def: UpgradeDef = w.content.upgrades[Ids.UP_AUTO_TURRET]
	var armor: float = w.content.enemies[Ids.EN_HOLLOW].armor
	var shots: int = _shots(w, 120)
	assert_float(VarietyVKit.taken(w, target)).is_equal_approx(float(shots) * maxf(1.0, def.turret_damage - armor), 0.001)
	var heavy: SimWorld = _world()
	heavy.mods.t_dmg_mul = 1.3  # turret_heavy_slugs
	heavy.turrets.active[0] = 1
	var victim: int = VarietyVKit.place(heavy, Ids.EN_HOLLOW, -1.0, -1.5)
	VarietyVKit.tough(heavy, victim)
	var heavy_shots: int = _shots(heavy, 120)
	assert_float(VarietyVKit.taken(heavy, victim)).is_equal_approx(
		float(heavy_shots) * maxf(1.0, def.turret_damage * 1.3 - armor), 0.001
	)
