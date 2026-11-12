extends GdUnitTestSuite
## V2-H: the `balanced` bot's abilities and calls (CONTENT 13): EMP at 10 attackers or on a telegraphed boss attack,
## Shield on the hit that crosses 60% or before a lance beam, Overdrive on a boss in range or 20 alive, Deadfall on a
## cluster of 10 or an elite pair, Vent at 12 attackers. Hand-made fields on TestContent.variety().

var w: SimWorld
var bot: PolicyBot


func before_test() -> void:
	w = VarietyHKit.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 2
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)


func _abilities() -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.ABILITY:
			out.append(c.arg)
	return out


func _act() -> Array[int]:
	w.command_queue.clear()
	bot.act(w)
	return _abilities()


func test_emp_needs_ten_attackers() -> void:
	VarietyHKit.crowd(w, 9, 3.0, true)
	assert_array(_act()).is_empty()
	VarietyHKit.crowd(w, 1, 3.0, true)
	assert_array(_act()).is_equal([Ids.AB_EMP])


func test_emp_interrupts_a_telegraphed_boss_attack() -> void:
	assert_array(_act()).is_empty()
	w.boss.telegraph_attack = 1
	w.boss.telegraph_left = 40
	assert_array(_act()).is_equal([Ids.AB_EMP])


func test_emp_waits_out_its_cooldown() -> void:
	VarietyHKit.crowd(w, 12, 3.0, true)
	w.abilities.cooldown_left[Ids.AB_EMP] = 300
	assert_array(_act()).is_empty()


func test_shield_comes_on_the_hit_that_crosses_sixty_percent() -> void:
	assert_array(_act()).is_empty()  # the first call only notes the core
	w.set_core_hp(w.core_max_hp * 0.61)
	assert_array(_act()).is_empty()  # hurt, but still above the line
	w.set_core_hp(w.core_max_hp * 0.59)
	assert_array(_act()).is_equal([Ids.AB_SHIELD])


func test_shield_does_not_fire_again_for_hits_below_the_line() -> void:
	assert_array(_act()).is_empty()
	w.set_core_hp(w.core_max_hp * 0.55)
	assert_array(_act()).is_equal([Ids.AB_SHIELD])
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 0
	w.abilities.active_left[Ids.AB_SHIELD] = 0
	w.set_core_hp(w.core_max_hp * 0.45)
	assert_array(_act()).is_empty()  # it was already below 60% a call ago


func test_shield_goes_up_before_a_lance_beam() -> void:
	w.boss.boss_type = Ids.EN_LANCE_PLATFORM
	w.boss.telegraph_attack = 0
	w.boss.telegraph_left = 30
	var used: Array[int] = _act()
	assert_array(used).contains([Ids.AB_SHIELD])
	w.boss.boss_type = Ids.EN_HULK
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 0
	assert_array(_act()).not_contains([Ids.AB_SHIELD])  # another boss's telegraph is not a beam


func test_overdrive_needs_twenty_alive_or_the_boss_in_range() -> void:
	VarietyHKit.crowd(w, 19, 3.0)
	assert_array(_act()).is_empty()
	VarietyHKit.crowd(w, 1, 3.0)
	assert_array(_act()).is_equal([Ids.AB_OVERDRIVE])


func test_overdrive_on_a_boss_within_reach() -> void:
	var boss: int = w.spawn_enemy(Ids.EN_HULK, w.warden.x + 10.0, w.warden.z)
	assert_bool(boss >= 0).is_true()
	assert_array(_act()).contains([Ids.AB_OVERDRIVE])


func test_nothing_is_used_outside_combat() -> void:
	VarietyHKit.crowd(w, 25, 3.0, true)
	w.phase = GameState.Id.INTERMISSION
	assert_array(_act()).is_empty()
	w.phase = GameState.Id.PREPARING
	assert_array(_act()).is_empty()


func test_the_cluster_scan_finds_the_densest_group() -> void:
	for k: int in 6:
		w.spawn_enemy(Ids.EN_SKITTER, 0.0 + 0.3 * float(k), 0.0)  # six within 4 m of each other
	for k: int in 4:
		w.spawn_enemy(Ids.EN_SKITTER, 12.0 + 0.3 * float(k), 5.0)  # a second group of four, far away
	assert_int(PolicySenses.densest(w, 4.0)).is_equal(6)
	w.spawn_enemy(Ids.EN_SKITTER, 1.0, 1.0)
	assert_int(PolicySenses.densest(w, 4.0)).is_equal(7)
	assert_int(PolicySenses.densest(w, 20.0)).is_equal(11)


func test_an_elite_pair_is_two_elites_close_together() -> void:
	var a: int = w.spawn_enemy(Ids.EN_HOLLOW, 0.0, 0.0)
	var b: int = w.spawn_enemy(Ids.EN_HOLLOW, 3.0, 0.0)
	var c: int = w.spawn_enemy(Ids.EN_HOLLOW, 20.0, 0.0)
	w.ext.flags[a] |= EnemyExtState.F_ELITE
	assert_bool(PolicySenses.elite_pair(w, 4.0)).is_false()  # one elite is not a pair
	w.ext.flags[c] |= EnemyExtState.F_ELITE
	assert_bool(PolicySenses.elite_pair(w, 4.0)).is_false()  # far apart
	w.ext.flags[b] |= EnemyExtState.F_ELITE
	assert_bool(PolicySenses.elite_pair(w, 4.0)).is_true()


func test_the_strike_is_called_on_a_cluster_exactly_when_the_sim_allows_it() -> void:
	var strike: int = w.content.event_index(&"deadfall_strike")
	assert_int(strike).is_greater_equal(0)
	w.events_state.charges[strike] = 1
	for k: int in 10:
		w.spawn_enemy(Ids.EN_SKITTER, 0.0 + 0.2 * float(k), 0.0)
	w.tick = 60  # the scan runs on a multiple of 12
	w.command_queue.clear()
	bot.act(w)
	var calls: int = 0
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.CALL_EVENT:
			calls += 1
			assert_int(c.arg).is_equal(strike)
	# V2-C decides whether a call is legal; until it lands the stub refuses every call and the bot must not send one.
	var legal: bool = EventSystem.block_reason(w, strike) == Reason.Id.OK
	assert_int(calls).is_equal(1 if legal else 0)


func test_no_call_is_made_for_a_small_group() -> void:
	var strike: int = w.content.event_index(&"deadfall_strike")
	w.events_state.charges[strike] = 1
	for k: int in 9:
		w.spawn_enemy(Ids.EN_SKITTER, 0.0 + 0.2 * float(k), 0.0)
	w.tick = 60
	w.command_queue.clear()
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).not_contains([SimCommand.Kind.CALL_EVENT])


func test_the_legacy_content_has_no_events_to_call_and_the_bot_still_plays() -> void:
	var legacy: SimWorld = TestContent.world()
	legacy.set_phase(GameState.Id.SPAWNING)
	var legacy_bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.BALANCED)
	for k: int in 14:
		var i: int = legacy.spawn_enemy(Ids.EN_SKITTER, 4.0, 0.0)
		legacy.enemies.state[i] = EnemyStore.ST_ATTACKING
	legacy_bot.act(legacy)
	assert_int(legacy.command_queue.size()).is_equal(1)
	assert_int(legacy.command_queue[0].arg).is_equal(Ids.AB_EMP)
