extends GdUnitTestSuite
## V4-T: `balanced` against a boss: the weapon that hurts the plating most is the one in hand (PolicyDps), the EMP stuns a
## boss that is striking the core, a Shield soaks what is left. Hand-made states on TestContent.variety().

var w: SimWorld
var bot: PolicyBot
var boss: int = -1


func before_test() -> void:
	w = VarietyHKit.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 5
	VarietyHKit.carry(w, 0, &"pistol")
	VarietyHKit.carry(w, 1, &"arc_projector")
	w.arsenal.active = 0
	w.tick = 600
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)
	boss = w.spawn_enemy(Ids.EN_HULK, 5.0, 3.0)


func _swaps() -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.SWAP_WEAPON:
			out.append(c.arg)
	return out


func _abilities() -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.ABILITY:
			out.append(c.arg)
	return out


func _act() -> void:
	w.command_queue.clear()
	bot.swap_not_before = 0
	bot.act(w)


# --- the damage a weapon does to one target ---


func test_the_pistol_and_the_arc_are_worth_what_the_data_says_against_a_boss() -> void:
	# pistol: (30 - 12 armor) x 2 shots/s x (6 s of a 12-round magazine in 7.25 s); arc: 40 x 1.6 x (5 s of 8 shots in 7.5 s)
	assert_float(PolicyDps.vs(w, 0, boss)).is_equal_approx(18.0 * 2.0 * 6.0 / 7.25, 0.05)
	assert_float(PolicyDps.vs(w, 1, boss)).is_equal_approx(40.0 * 1.6 * 5.0 / 7.5, 0.05)
	assert_float(PolicyDps.vs(w, 1, boss)).is_greater(PolicyDps.vs(w, 0, boss))


func test_an_unarmored_target_goes_to_the_faster_weapon() -> void:
	var skitter: int = w.spawn_enemy(Ids.EN_SKITTER, 4.0, 3.0)
	assert_float(PolicyDps.vs(w, 0, skitter)).is_greater(PolicyDps.vs(w, 1, skitter))
	assert_float(PolicyDps.vs(w, 2, skitter)).is_equal(0.0)  # no third slot
	assert_float(PolicyDps.vs(w, 0, -1)).is_equal(0.0)


func test_a_cone_a_missile_rack_and_a_beam_have_a_rate_too() -> void:
	for id: StringName in [&"scattergun", &"hornet_rack", &"cutting_torch", &"rail_lance", &"lmg", &"slag_mortar"]:
		VarietyHKit.carry(w, 1, id)
		assert_float(PolicyDps.vs(w, 1, boss)).override_failure_message("no damage rate for %s" % id).is_greater(0.0)


# --- the weapon in hand ---


func test_the_weapon_that_beats_the_plating_is_taken_out_when_a_boss_stands() -> void:
	assert_int(PolicyLoadout.boss_target(w)).is_equal(1)
	assert_array(_swaps_after_act()).is_equal([1])


func _swaps_after_act() -> Array[int]:
	_act()
	return _swaps()


func test_without_a_boss_the_crowd_rule_decides() -> void:
	w.kill_enemy(boss, DamageSource.Id.WARDEN)
	assert_int(PolicyLoadout.boss_target(w)).is_equal(PolicyLoadout.NO_BOSS_RULE)
	assert_array(_swaps_after_act()).is_empty()


func test_the_better_weapon_stays_in_hand() -> void:
	w.arsenal.active = 1
	assert_int(PolicyLoadout.boss_target(w)).is_equal(1)
	assert_array(_swaps_after_act()).is_empty()


func test_a_spent_weapon_is_given_up_for_the_one_that_can_fire() -> void:
	w.arsenal.active = 1
	w.arsenal.slot_vent_left[1] = 150
	assert_int(PolicyLoadout.boss_target(w)).is_equal(0)
	w.arsenal.slot_vent_left[1] = 0
	w.arsenal.slot_heat[1] = 80  # too hot to take out
	w.arsenal.active = 0
	assert_int(PolicyLoadout.boss_target(w)).is_equal(0)


func test_a_small_edge_is_not_worth_a_swap() -> void:
	VarietyHKit.carry(w, 1, &"smg")  # about the pistol's damage after the plating, no better by 15%
	var gain: float = PolicyDps.vs(w, 1, boss) / PolicyDps.vs(w, 0, boss)
	assert_int(PolicyLoadout.boss_target(w)).is_equal(1 if gain > PolicyLoadout.BOSS_SWAP_GAIN else 0)


# --- abilities against a boss at the cage ---


func test_a_boss_in_an_attack_slot_is_stunned_and_the_core_shielded() -> void:
	_act()
	assert_array(_abilities()).not_contains([Ids.AB_EMP])  # it is still walking
	w.enemies.state[boss] = EnemyStore.ST_ATTACKING
	w.set_core_hp(w.core_max_hp * 0.9)
	_act()
	assert_array(_abilities()).contains([Ids.AB_EMP, Ids.AB_SHIELD])
	w.set_core_hp(w.core_max_hp)
	w.abilities.cooldown_left[Ids.AB_EMP] = 0
	w.abilities.cooldown_left[Ids.AB_SHIELD] = 0
	_act()
	assert_array(_abilities()).contains([Ids.AB_EMP])
	assert_array(_abilities()).not_contains([Ids.AB_SHIELD])  # nothing to soak at a whole core
