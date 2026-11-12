extends GdUnitTestSuite
## V2-B: REROLL, BUY_OUT and PATCH_CORE (VARIETY_SPEC 4.4, CONTENT 3.7): linear prices that grow per use over the run,
## free charges first, once per draft, and the no-breather lock.

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()


## A draft world with `scrap` Scrap.
func _rich(scrap: int = 2000) -> SimWorld:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.add_scrap(scrap)
	return w


func test_reroll_prices_are_60_100_140() -> void:
	var w: SimWorld = _rich(1000)
	var want: Array[int] = [60, 100, 140, 180]
	for n: int in want.size():
		assert_int(DraftSystem.reroll_cost(w)).is_equal(want[n])
		var before: int = w.scrap
		assert_int(DraftSystem.reroll(w, n + 1)).is_equal(Reason.Id.OK)
		assert_int(before - w.scrap).is_equal(want[n])
		assert_int(w.draft.rerolls_paid).is_equal(n + 1)
	assert_bool(w.draft.open).is_true()


func test_the_reroll_price_grows_over_the_run_not_per_draft() -> void:
	var w: SimWorld = _rich(1000)
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.OK)
	assert_int(DraftSystem.skip(w, 2)).is_equal(Reason.Id.OK)
	VarietyBKit.open_draft(w)
	assert_int(DraftSystem.reroll_cost(w)).is_equal(100)


func test_reroll_pushes_the_event_with_the_scrap_paid() -> void:
	var w: SimWorld = _rich(1000)
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.OK)
	var events: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.DRAFT_REROLLED)
	assert_int(events.size()).is_equal(1)
	assert_int(events[0].a).is_equal(0)  # the offer ordinal, 0-based
	assert_int(events[0].b).is_equal(60)


func test_free_rerolls_come_first_and_cost_nothing() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.draft.free_rerolls = 2
	assert_int(DraftSystem.reroll_cost(w)).is_equal(0)
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.OK)
	assert_int(DraftSystem.reroll(w, 2)).is_equal(Reason.Id.OK)
	assert_int(w.draft.free_rerolls).is_equal(0)
	assert_int(w.draft.rerolls_paid).is_equal(0)  # the price did not move
	assert_int(DraftSystem.reroll_cost(w)).is_equal(60)
	assert_int(DraftSystem.reroll(w, 3)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)


func test_a_reroll_without_the_scrap_changes_nothing() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.add_scrap(59)
	var before: String = w.state_hash()
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_str(w.state_hash()).is_equal(before)
	w.add_scrap(1)
	assert_int(DraftSystem.reroll(w, 2)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(0)


func test_requisition_line_halves_the_reroll_price() -> void:
	var w: SimWorld = _rich(1000)
	w.mods.reroll_cost_mul = 0.5
	assert_int(DraftSystem.reroll_cost(w)).is_equal(30)
	w.draft.rerolls_paid = 1
	assert_int(DraftSystem.reroll_cost(w)).is_equal(50)


func test_a_reroll_redraws_deterministically_from_the_same_stream() -> void:
	var a: SimWorld = _rich(1000)
	var b: SimWorld = _rich(1000)
	var first: Array = Array(a.draft.offer)
	assert_int(DraftSystem.reroll(a, 1)).is_equal(Reason.Id.OK)
	assert_int(DraftSystem.reroll(b, 1)).is_equal(Reason.Id.OK)
	assert_array(Array(a.draft.offer)).is_equal(Array(b.draft.offer))
	assert_int(a.draft.offer.size()).is_equal(3)
	assert_int(a.draft.offer_ordinal).is_equal(1)  # a reroll is not a new offer
	var changed: int = 0
	for run_seed: int in range(1, 21):
		var w: SimWorld = VarietyBKit.draft_world(c, 3, run_seed)
		w.add_scrap(500)
		var old: Array = Array(w.draft.offer)
		assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.OK)
		if Array(w.draft.offer) != old:
			changed += 1
	assert_int(changed).is_greater(15)
	assert_int(first.size()).is_equal(3)


func test_a_reroll_never_repeats_a_directive_inside_the_offer() -> void:
	var w: SimWorld = _rich(100000)
	for n: int in 40:
		assert_int(DraftSystem.reroll(w, n + 1)).is_equal(Reason.Id.OK)
		var seen: Dictionary[int, bool] = {}
		for index: int in w.draft.offer:
			assert_bool(seen.has(index)).is_false()
			seen[index] = true


func test_no_breather_from_the_flag_locks_the_reroll_and_the_patch() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	w.mods.set_flag(&"no_breather", true)
	VarietyBKit.open_draft(w)
	w.add_scrap(1000)
	w.set_core_hp(500.0)
	assert_bool(w.draft.reroll_locked).is_true()
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(DraftSystem.patch_core(w, 2)).is_equal(Reason.Id.LOCKED_BY_EVENT)
	assert_int(w.scrap).is_equal(1000)
	assert_int(DraftSystem.skip(w, 3)).is_equal(Reason.Id.OK)  # skip and pick still work
	assert_bool(w.draft.reroll_locked).is_false()


func test_no_breather_from_the_modifier_of_the_cleared_wave() -> void:
	var run: RunDef = c.run
	var mod: ModifierDef = ModifierDef.new()
	mod.id = &"mod_test_no_breather"
	mod.index = run.modifiers.size()
	mod.ops = VarietyBKit.ops_of(VarietyBKit.op_flag(&"no_breather"))
	run.modifiers.append(mod)
	var w: SimWorld = VarietyBKit.intermission_world(c, 3)
	w.plan.option(3).modifier_index = mod.index  # the modifier is already cleared from the mods: the plan remembers it
	VarietyBKit.open_draft(w)
	assert_bool(w.draft.reroll_locked).is_true()
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.LOCKED_BY_EVENT)


func test_buyout_prices_are_250_350_450() -> void:
	var w: SimWorld = _rich(3000)
	var want: Array[int] = [250, 350, 450]
	for n: int in want.size():
		assert_int(DraftSystem.buyout_cost(w)).is_equal(want[n])
		var before: int = w.scrap
		assert_int(DraftSystem.buy_out(w, n + 1, 1)).is_equal(Reason.Id.OK)
		assert_int(before - w.scrap).is_equal(want[n])
		assert_int(DraftSystem.pick(w, n + 100, 0)).is_equal(Reason.Id.OK)  # closes this draft
		VarietyBKit.open_draft(w)
	assert_int(w.draft.buyouts).is_equal(3)


func test_buyout_takes_the_slot_at_once_and_the_draft_stays_open() -> void:
	var w: SimWorld = _rich(500)
	var bought: int = w.draft.offer[1]
	assert_int(DraftSystem.buy_out(w, 1, 1)).is_equal(Reason.Id.OK)
	assert_int(w.draft.stacks_of(bought)).is_equal(1)
	assert_int(w.draft.offer[1]).is_equal(-1)
	assert_bool(w.draft.open).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_int(w.scrap).is_equal(250)
	var picked: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.DIRECTIVE_PICKED)
	assert_int(picked[0].a).is_equal(bought)
	var kept: int = w.draft.offer[2]
	assert_int(DraftSystem.pick(w, 2, 2)).is_equal(Reason.Id.OK)
	assert_int(w.draft.stacks_of(kept)).is_equal(1)
	assert_bool(w.draft.open).is_false()


func test_a_buyout_is_allowed_once_per_draft() -> void:
	var w: SimWorld = _rich(3000)
	assert_int(DraftSystem.buy_out(w, 1, 1)).is_equal(Reason.Id.OK)
	assert_bool(w.draft.bought_out).is_true()
	assert_int(DraftSystem.buy_out(w, 2, 2)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(w.scrap).is_equal(2750)
	assert_int(DraftSystem.pick(w, 3, 0)).is_equal(Reason.Id.OK)
	VarietyBKit.open_draft(w)
	assert_bool(w.draft.bought_out).is_false()  # a new draft, a new right
	assert_int(DraftSystem.buy_out(w, 4, 1)).is_equal(Reason.Id.OK)


func test_a_buyout_needs_the_scrap_a_live_slot_and_another_pick_to_make() -> void:
	var w: SimWorld = _rich(249)
	var before: String = w.state_hash()
	assert_int(DraftSystem.buy_out(w, 1, 1)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_int(DraftSystem.buy_out(w, 2, 5)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(DraftSystem.buy_out(w, 3, -1)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_str(w.state_hash()).is_equal(before)
	var single: SimWorld = VarietyBKit.intermission_world(c)
	for def: DirectiveDef in c.directives:
		if def.id != &"hot_loads":
			single.draft.stacks[def.index] = def.max_stacks
	VarietyBKit.open_draft(single)
	single.add_scrap(1000)
	assert_int(single.draft.offer.size()).is_equal(1)
	assert_int(DraftSystem.buy_out(single, 1, 0)).is_equal(Reason.Id.INVALID_CHOICE)  # just pick it
	assert_int(single.scrap).is_equal(1000)


func test_a_reroll_is_refused_once_a_slot_was_taken() -> void:
	var w: SimWorld = _rich(1000)
	assert_int(DraftSystem.buy_out(w, 1, 1)).is_equal(Reason.Id.OK)
	assert_int(DraftSystem.reroll(w, 2)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(w.scrap).is_equal(750)


func test_patch_prices_are_180_270_360_and_repair_a_tenth() -> void:
	var w: SimWorld = _rich(3000)
	w.set_core_hp(400.0)
	var want: Array[int] = [180, 270, 360]
	for n: int in want.size():
		assert_int(DraftSystem.patch_cost(w)).is_equal(want[n])
		var before: int = w.scrap
		var hp: float = w.core_hp
		assert_int(DraftSystem.patch_core(w, n + 1)).is_equal(Reason.Id.OK)
		assert_int(before - w.scrap).is_equal(want[n])
		assert_float(w.core_hp - hp).is_equal_approx(100.0, 0.001)  # 10% of 1000
	assert_bool(w.draft.open).is_true()  # a patch does not close the draft
	assert_int(w.draft.patches).is_equal(3)


func test_a_patch_is_capped_at_the_core_maximum_but_costs_full_price() -> void:
	var w: SimWorld = _rich(1000)
	w.set_core_hp(950.0)
	assert_int(DraftSystem.patch_core(w, 1)).is_equal(Reason.Id.OK)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(w.scrap).is_equal(820)
	var healed: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.CORE_HEALED)
	assert_float(healed[0].f).is_equal_approx(50.0, 0.001)
	assert_float(healed[0].g).is_equal(1000.0)


func test_a_patch_at_a_full_core_is_refused() -> void:
	var w: SimWorld = _rich(1000)
	var before: String = w.state_hash()
	assert_int(DraftSystem.patch_core(w, 1)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_str(w.state_hash()).is_equal(before)


func test_a_patch_needs_the_scrap() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.add_scrap(179)
	w.set_core_hp(100.0)
	assert_int(DraftSystem.patch_core(w, 1)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_float(w.core_hp).is_equal(100.0)
	assert_int(w.scrap).is_equal(179)


func test_the_patch_follows_the_core_maximum_of_the_build() -> void:
	var w: SimWorld = _rich(1000)
	w.draft.stacks[c.directive_index(&"reinforced_cage")] = 2
	ModSystem.recompute(w)
	assert_float(w.core_max_hp).is_equal(1300.0)
	w.set_core_hp(1000.0)
	assert_int(DraftSystem.patch_core(w, 1)).is_equal(Reason.Id.OK)
	assert_float(w.core_hp).is_equal_approx(1130.0, 0.001)  # 10% of 1300
