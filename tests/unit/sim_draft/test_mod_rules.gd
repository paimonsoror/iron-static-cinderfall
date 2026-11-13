extends GdUnitTestSuite
## V4-C: ModRules and HookMemory (CONTENT 3): the dynamic multipliers of scrap_rounds, the_tally, static_pact and
## last_stand_protocol, the stack clamp, the memory packed into a hook directive's stack count, and that all of it survives
## a snapshot.

var w: SimWorld


func before_test() -> void:
	w = DirectiveKit.world()


func test_scrap_rounds_adds_one_percent_per_40_scrap_up_to_60_percent() -> void:
	assert_float(ModRules.damage_mul(w)).is_equal(1.0)  # not held: the flag is off
	w.add_scrap(400)
	assert_float(ModRules.damage_mul(w)).is_equal(1.0)
	DirectiveKit.give(w, &"scrap_rounds")
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.10, 0.00001)
	w.scrap = 39
	assert_float(ModRules.damage_mul(w)).is_equal(1.0)
	w.scrap = 40
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.01, 0.00001)
	w.scrap = 2399
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.59, 0.00001)
	w.scrap = 2400
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.60, 0.00001)  # 60 steps: the cap
	w.scrap = 4000
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.60, 0.00001)
	w.scrap = 100000
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.60, 0.00001)  # capped


func test_scrap_rounds_and_the_tally_multiply() -> void:
	DirectiveKit.give(w, &"scrap_rounds")
	DirectiveKit.give(w, &"the_tally")
	w.scrap = 400
	HookMemory.set_tally(w, 20, 0)
	assert_float(ModRules.damage_mul(w)).is_equal_approx(1.10 * 1.20, 0.00001)


func test_static_pact_doubles_the_rate_only_during_a_static_front() -> void:
	assert_float(ModRules.rate_mul(w)).is_equal(1.0)
	w.events_state.ability_lock_ticks = 300
	assert_float(ModRules.rate_mul(w)).is_equal(1.0)  # not held
	DirectiveKit.give(w, &"static_pact")
	assert_float(ModRules.rate_mul(w)).is_equal(2.0)
	w.events_state.ability_lock_ticks = 0
	assert_float(ModRules.rate_mul(w)).is_equal(1.0)


func test_last_stand_protocol_applies_below_35_percent_of_the_core() -> void:
	w.set_core_hp(100.0)
	assert_bool(ModRules.last_stand_active(w)).is_false()  # not held
	DirectiveKit.give(w, &"last_stand_protocol")
	assert_bool(ModRules.last_stand_active(w)).is_true()
	assert_float(ModRules.last_stand_turret_rate(w)).is_equal(1.8)
	assert_float(ModRules.last_stand_reload_mul(w)).is_equal(0.5)
	w.set_core_hp(350.0)
	assert_bool(ModRules.last_stand_active(w)).is_false()  # strictly below
	assert_float(ModRules.last_stand_turret_rate(w)).is_equal(1.0)
	assert_float(ModRules.last_stand_reload_mul(w)).is_equal(1.0)
	w.set_core_hp(349.0)
	assert_bool(ModRules.last_stand_active(w)).is_true()


func test_a_count_above_the_maximum_never_adds_op_stacks() -> void:
	var index: int = w.content.directive_index(&"hot_loads")  # max 5
	w.draft.stacks[index] = 9
	ModSystem.recompute(w)
	assert_float(w.mods.lvl_damage).is_equal(5.0)
	assert_int(ModRules.held(w, &"hot_loads")).is_equal(5)
	assert_int(ModRules.held(w, &"no_such_directive")).is_equal(0)


func test_hook_memory_packs_and_clamps() -> void:
	DirectiveKit.give(w, &"the_tally")
	HookMemory.set_tally(w, 100, HookMemory.TALLY_MAX_TICK)
	assert_int(HookMemory.tally_pct(w)).is_equal(100)
	assert_int(HookMemory.tally_last_tick(w)).is_equal(HookMemory.TALLY_MAX_TICK)
	assert_int(DirectiveKit.held(w, &"the_tally")).is_less(2147483647)
	HookMemory.set_tally(w, 250, 99000000)
	assert_int(HookMemory.tally_pct(w)).is_equal(100)
	assert_int(HookMemory.tally_last_tick(w)).is_equal(HookMemory.TALLY_MAX_TICK)
	HookMemory.set_tally(w, 0, 0)
	assert_int(HookMemory.tally_pct(w)).is_equal(0)
	assert_int(DirectiveKit.held(w, &"the_tally")).is_equal(1)
	assert_int(HookMemory.tally_pct(w)).is_equal(0)
	assert_int(HookMemory.borrowed_waves(w)).is_equal(0)
	assert_bool(HookMemory.switch_armed(w)).is_false()  # not held


func test_hook_memory_survives_a_snapshot_and_changes_the_state_hash() -> void:
	DirectiveKit.give(w, &"dead_mans_switch")
	DirectiveKit.give(w, &"borrowed_time")
	DirectiveKit.give(w, &"the_tally")
	var before: String = w.state_hash()
	HookMemory.spend_switch(w)
	HookMemory.add_borrowed_wave(w)
	HookMemory.add_borrowed_wave(w)
	HookMemory.set_tally(w, 13, 777)
	ModSystem.recompute(w)  # two waves paid: the core maximum follows
	assert_str(w.state_hash()).is_not_equal(before)
	var doc: Dictionary = WorldSnapshot.capture(w)
	var twin: SimWorld = SimWorld.new(w.config)
	assert_bool(WorldSnapshot.restore(twin, doc)).is_true()
	assert_str(twin.state_hash()).is_equal(w.state_hash())
	assert_bool(HookMemory.switch_armed(twin)).is_false()
	assert_int(HookMemory.borrowed_waves(twin)).is_equal(2)
	assert_int(HookMemory.tally_pct(twin)).is_equal(13)
	assert_int(HookMemory.tally_last_tick(twin)).is_equal(777)
	assert_float(twin.mods.core_max_mul).is_equal_approx(0.9, 0.00001)


func test_hook_memory_of_a_directive_is_zero_in_a_world_that_does_not_hold_it() -> void:
	assert_int(HookMemory.raw(w, &"the_tally")).is_equal(0)
	assert_int(HookMemory.tally_pct(w)).is_equal(0)
	assert_int(HookMemory.tally_last_tick(w)).is_equal(0)
	assert_int(HookMemory.borrowed_waves(w)).is_equal(0)
	assert_int(HookMemory.raw(w, &"no_such_directive")).is_equal(0)
	HookMemory.set_raw(w, &"no_such_directive", 5)  # harmless
