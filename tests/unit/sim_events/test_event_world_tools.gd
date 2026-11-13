extends GdUnitTestSuite
## V4-V: the world events that touch the player's tools: RELAY WINDOW (Scrap x2), CORE SURGE (turrets x2, then a brownout
## unless a Shield was activated during the surge) and STATIC FRONT (abilities locked, cooldowns frozen, active effects
## continue, motes stunned). Planned in wave 4 at offset 1, so the warning starts on tick 1 (CONTENT 6; VARIETY_SPEC 7.4).


func _planned(event_index: int, offset: int = 1) -> SimWorld:
	var w: SimWorld = VarietyVKit.world(1, 4)
	VarietyVKit.clear_plan(w)
	VarietyVKit.plan_event(w, 4, event_index, offset)
	return w


## A turret on pad 0 with a target in range for as long as the test runs.
func _with_turret(w: SimWorld) -> void:
	w.turrets.active[0] = 1
	var target: int = VarietyVKit.place(w, Ids.EN_HOLLOW, -1.0, -1.5)
	VarietyVKit.tough(w, target)


func _turret_shots(w: SimWorld, ticks: int) -> int:
	var before: int = w.combat.shots_by_source[DamageSource.Id.TURRET_0]
	VarietyVKit.run(w, ticks)
	return w.combat.shots_by_source[DamageSource.Id.TURRET_0] - before


# --- RELAY WINDOW ---


func test_the_relay_window_doubles_the_scrap_of_kills_for_ten_seconds() -> void:
	var w: SimWorld = _planned(VarietyVKit.ACCORD)
	var skitter: int = VarietyVKit.place(w, Ids.EN_SKITTER, 3.0, 3.0)
	var base: int = w.content.enemies[Ids.EN_SKITTER].scrap
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(base)
	VarietyVKit.tick(w)  # tick 1: the window opens as it is announced
	assert_int(w.events_state.scrap_mult_milli).is_equal(2000)
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(2 * base)
	VarietyVKit.run(w, 598)  # tick 599
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(2 * base)
	VarietyVKit.tick(w)  # tick 600: ten seconds after the start
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(2 * base)
	VarietyVKit.tick(w)  # tick 601 = 1 + 600
	assert_int(DeathHooks.scrap_for(w, skitter, DamageSource.Id.WARDEN)).is_equal(base)
	assert_int(w.events_state.scrap_mult_milli).is_equal(1000)


func test_a_kill_in_the_window_really_pays_double() -> void:
	var w: SimWorld = _planned(VarietyVKit.ACCORD)
	var skitter: int = VarietyVKit.place(w, Ids.EN_SKITTER, 3.0, 3.0)
	VarietyVKit.tick(w)
	w.kill_enemy(skitter, DamageSource.Id.WARDEN)
	assert_int(w.scrap).is_equal(2 * w.content.enemies[Ids.EN_SKITTER].scrap)


# --- CORE SURGE ---


func test_the_surge_doubles_the_turret_rate_for_ten_seconds_then_a_brownout_takes_them_offline_for_five() -> void:
	var w: SimWorld = _planned(VarietyVKit.SURGE)
	_with_turret(w)
	VarietyVKit.run(w, 100)
	var normal: int = _turret_shots(w, 120)  # ticks 101 to 220: the rate before the surge
	assert_int(normal).is_greater(0)
	VarietyVKit.run(w, 240 - w.tick)  # tick 240: the warning is still on
	assert_bool(EventSystem.surge_active(w)).is_false()
	VarietyVKit.tick(w)  # tick 241 = 1 + 240
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([241])
	assert_bool(EventSystem.surge_active(w)).is_true()
	assert_int(w.events_state.turret_rate_milli).is_equal(2000)
	var surged: int = _turret_shots(w, 120)
	assert_int(surged).is_between(2 * normal - 1, 2 * normal + 1)
	VarietyVKit.run(w, 840 - w.tick)  # tick 840: the last tick of the surge
	assert_bool(EventSystem.surge_active(w)).is_true()
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	VarietyVKit.tick(w)  # tick 841 = 241 + 600: the surge is over
	assert_bool(EventSystem.surge_active(w)).is_false()
	assert_int(w.events_state.turret_rate_milli).is_equal(1000)
	assert_int(w.events_state.turret_offline_ticks).is_equal(300)
	assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_ENDED, VarietyVKit.SURGE)).is_equal([841])
	assert_int(_turret_shots(w, 299)).is_equal(0)  # offline until tick 1140
	VarietyVKit.tick(w)
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	assert_int(_turret_shots(w, 120)).is_between(normal - 1, normal + 1)


func test_a_shield_activated_during_the_surge_cancels_the_brownout() -> void:
	var w: SimWorld = _planned(VarietyVKit.SURGE)
	VarietyVKit.run(w, 241 + 100)
	assert_int(AbilitySystem.activate(w, 7, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_int(w.events_state.brownout_cancelled).is_equal(1)
	VarietyVKit.run(w, 600)
	assert_bool(EventSystem.surge_active(w)).is_false()
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	assert_int(w.events_state.brownout_cancelled).is_equal(0)


func test_a_shield_from_before_the_surge_or_after_it_does_not_cancel_the_brownout() -> void:
	var early: SimWorld = _planned(VarietyVKit.SURGE)
	VarietyVKit.run(early, 5)
	assert_int(AbilitySystem.activate(early, 7, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)  # a shield of 480 ticks: over at 485
	VarietyVKit.run(early, 241 + 600 - early.tick)
	assert_int(early.events_state.turret_offline_ticks).is_equal(300)
	var late: SimWorld = _planned(VarietyVKit.SURGE)
	VarietyVKit.run(late, 241 + 600)
	assert_int(AbilitySystem.activate(late, 7, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)
	assert_int(late.events_state.brownout_cancelled).is_equal(0)
	assert_int(late.events_state.turret_offline_ticks).is_greater(0)


func test_an_outage_that_is_already_running_is_not_shortened_by_a_brownout() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	EventSystem.take_turrets_offline(w, 500)
	EventSystem.take_turrets_offline(w, 100)  # a Tremor Rig stomp (4 s) never shortens a longer outage
	assert_int(w.events_state.turret_offline_ticks).is_equal(500)


# --- STATIC FRONT ---


func test_the_static_front_locks_every_ability_for_twelve_seconds_after_six_seconds_of_warning() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	for a: int in 3:
		assert_int(w.ability_block_reason(a)).is_equal(Reason.Id.OK)
	VarietyVKit.run(w, 360)  # tick 360: the warning is still on
	for a: int in 3:
		assert_int(w.ability_block_reason(a)).is_equal(Reason.Id.OK)
	VarietyVKit.tick(w)  # tick 361 = 1 + 360
	assert_array(VarietyVKit.ticks_of(w, SimEventKind.Id.EVENT_STARTED)).is_equal([361])
	for a: int in 3:
		assert_int(w.ability_block_reason(a)).is_equal(Reason.Id.LOCKED_BY_EVENT)
		assert_int(AbilitySystem.activate(w, 9, a)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.ABILITY_ACTIVATED)).is_equal(0)
	VarietyVKit.run(w, 719)  # tick 1080, the last locked tick
	assert_int(w.ability_block_reason(Ids.AB_EMP)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	VarietyVKit.tick(w)  # tick 1081 = 361 + 720
	for a: int in 3:
		assert_int(w.ability_block_reason(a)).is_equal(Reason.Id.OK)
	assert_array(VarietyVKit.ticks_for(w, SimEventKind.Id.EVENT_ENDED, VarietyVKit.STATIC)).is_equal([1081])


func test_cooldowns_freeze_under_the_front_and_do_not_reset() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	var cooldown: int = w.content.abilities[Ids.AB_EMP].cooldown_ticks
	VarietyVKit.tick(w)  # tick 1
	assert_int(AbilitySystem.activate(w, 7, Ids.AB_EMP)).is_equal(Reason.Id.OK)  # the cooldown starts at tick 1
	VarietyVKit.run(w, 359)  # tick 360: the last tick before the front
	var before: int = w.abilities.cooldown_left[Ids.AB_EMP]
	assert_int(before).is_equal(cooldown - 359)
	VarietyVKit.run(w, 720)  # tick 1080: the front has been on for 720 ticks
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(before)  # frozen, not reset
	VarietyVKit.tick(w)  # tick 1081: it runs again
	assert_int(w.abilities.cooldown_left[Ids.AB_EMP]).is_equal(before - 1)


func test_an_ability_that_is_active_when_the_front_starts_keeps_running() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	var shield_cd: int = w.content.abilities[Ids.AB_SHIELD].cooldown_ticks
	var duration: int = w.content.abilities[Ids.AB_SHIELD].duration_ticks
	VarietyVKit.run(w, 300)
	assert_int(AbilitySystem.activate(w, 7, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)  # tick 300; the front starts at 361
	VarietyVKit.run(w, 100)  # tick 400: the front is on
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	assert_float(w.shield_hp).is_greater(0.0)
	VarietyVKit.run(w, duration - 100)  # tick 300 + duration: the shield has run its course
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(shield_cd)  # started at its end ...
	VarietyVKit.run(w, 50)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(shield_cd)  # ... and frozen while the front lasts


func test_motes_are_stunned_two_seconds_when_the_front_arrives_and_other_enemies_are_not() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	var mote: int = VarietyVKit.place(w, Ids.EN_MOTE, 3.0, 3.0)
	var skitter: int = VarietyVKit.place(w, Ids.EN_SKITTER, 4.0, 3.0)
	VarietyVKit.run(w, 360)
	assert_int(w.enemies.stun_ticks[mote]).is_equal(0)
	VarietyVKit.tick(w)
	assert_int(w.enemies.stun_ticks[mote]).is_equal(119)  # set to 120 by the front, one tick counted by the ability step
	assert_int(w.enemies.stun_ticks[skitter]).is_equal(0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.ENEMY_STUNNED)).is_equal(1)


func test_the_front_leaves_turrets_and_the_pad_alone() -> void:
	var w: SimWorld = _planned(VarietyVKit.STATIC)
	_with_turret(w)
	var before: int = _turret_shots(w, 300)
	VarietyVKit.run(w, 61)  # the front is on from tick 361
	var during: int = _turret_shots(w, 300)
	assert_int(during).is_between(before - 1, before + 1)
	assert_bool(EventRates.lock_active(w)).is_true()
	assert_float(w.warden.x).is_equal(w.content.arena.warden_x)
