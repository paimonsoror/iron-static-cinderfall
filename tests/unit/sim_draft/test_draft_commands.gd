extends GdUnitTestSuite
## V2-B: PICK_DIRECTIVE and SKIP_DRAFT, the draft lifecycle and the refusals (VARIETY_SPEC 4.4). Prices and the
## reroll, buy-out and patch commands are in test_draft_prices.gd.

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()


func _count(w: SimWorld, kind: int) -> int:
	return VarietyBKit.events_of(w, kind).size()


## Every directive but `keep` is maxed, so the offer has that one slot.
func _only(w: SimWorld, keep: StringName) -> void:
	for def: DirectiveDef in w.content.directives:
		if def.id != keep:
			w.draft.stacks[def.index] = def.max_stacks


func test_a_pick_adds_a_stack_and_closes_the_draft() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	var index: int = w.draft.offer[2]
	assert_int(DraftSystem.pick(w, 1, 2)).is_equal(Reason.Id.OK)
	assert_int(w.draft.stacks_of(index)).is_equal(1)
	assert_bool(w.draft.open).is_false()
	assert_bool(w.draft.offer.is_empty()).is_true()
	assert_int(w.draft.picks_left).is_equal(0)
	var picked: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.DIRECTIVE_PICKED)
	assert_int(picked.size()).is_equal(1)
	assert_int(picked[0].a).is_equal(index)
	assert_int(picked[0].b).is_equal(1)


func test_closing_the_draft_releases_the_await() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.OK)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	var changed: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.AWAIT_CHANGED)
	assert_int(changed.size()).is_equal(1)
	assert_int(changed[0].a).is_equal(PhaseState.Await.NONE)
	assert_int(changed[0].b).is_equal(PhaseState.Await.DRAFT)


func test_a_pick_by_command_is_applied_logged_and_the_tick_goes_on() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	var index: int = w.draft.offer[1]
	var cmd: SimCommand = SimCommand.pick_directive(VarietyBKit.next_id(), 1)
	assert_int(VarietyBKit.send(w, cmd)).is_equal(Reason.Id.OK)
	assert_int(w.draft.stacks_of(index)).is_equal(1)
	assert_int(w.tick).is_equal(1)
	assert_int(w.command_log.entries.size()).is_equal(1)
	w.step()
	assert_int(w.tick).is_equal(2)  # the draft is over: the sim runs on


func test_nothing_is_open_nothing_is_answered_but_a_refusal() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	var before: String = w.state_hash()
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(DraftSystem.skip(w, 2)).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(DraftSystem.reroll(w, 3)).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(DraftSystem.buy_out(w, 4, 0)).is_equal(Reason.Id.NOT_AWAITING)
	assert_int(DraftSystem.patch_core(w, 5)).is_equal(Reason.Id.NOT_AWAITING)
	assert_str(w.state_hash()).is_equal(before)
	w.phase_state.awaiting = PhaseState.Await.DRAFT  # awaiting but nothing opened
	assert_int(DraftSystem.pick(w, 6, 0)).is_equal(Reason.Id.NOT_AWAITING)
	w.phase_state.awaiting = PhaseState.Await.ROUTE
	w.draft.open = true  # a draft that is open while another step is awaited
	assert_int(DraftSystem.skip(w, 7)).is_equal(Reason.Id.NOT_AWAITING)


func test_the_command_path_answers_a_refusal_with_command_rejected() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.set_core_hp(500.0)
	var codes: Array[int] = [
		VarietyBKit.send(w, SimCommand.pick_directive(VarietyBKit.next_id(), 7)),
		VarietyBKit.send(w, SimCommand.reroll(VarietyBKit.next_id())),  # no Scrap yet
		VarietyBKit.send(w, SimCommand.buy_out(VarietyBKit.next_id(), 0)),
		VarietyBKit.send(w, SimCommand.patch_core(VarietyBKit.next_id())),
	]
	assert_array(codes).is_equal([
		Reason.Id.INVALID_CHOICE, Reason.Id.INSUFFICIENT_SCRAP, Reason.Id.INSUFFICIENT_SCRAP, Reason.Id.INSUFFICIENT_SCRAP,
	])
	assert_bool(w.draft.open).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)


func test_a_bad_slot_changes_nothing() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	var before: String = w.state_hash()
	for slot: int in [-1, 3, 99]:
		assert_int(DraftSystem.pick(w, 1, slot)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_str(w.state_hash()).is_equal(before)


func test_a_repeated_command_id_is_answered_once() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.draft.free_rerolls = 2
	var id: int = VarietyBKit.next_id()
	assert_int(VarietyBKit.send(w, SimCommand.reroll(id))).is_equal(Reason.Id.OK)
	assert_int(w.draft.free_rerolls).is_equal(1)
	assert_int(VarietyBKit.send(w, SimCommand.reroll(id))).is_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_int(w.draft.free_rerolls).is_equal(1)


func test_rw_double_pick_keeps_the_draft_open_for_a_second_pick() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	DraftSystem.arm_next_double(w)
	VarietyBKit.open_draft(w)
	assert_int(w.draft.picks_left).is_equal(2)
	assert_bool(w.draft.next_double).is_false()
	var a: int = w.draft.offer[0]
	var b: int = w.draft.offer[1]
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.OK)
	assert_bool(w.draft.open).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_int(w.draft.offer[0]).is_equal(-1)
	assert_int(DraftSystem.pick(w, 2, 0)).is_equal(Reason.Id.INVALID_CHOICE)  # that slot is taken
	assert_int(DraftSystem.pick(w, 3, 1)).is_equal(Reason.Id.OK)
	assert_bool(w.draft.open).is_false()
	assert_int(w.draft.stacks_of(a)).is_equal(1)
	assert_int(w.draft.stacks_of(b)).is_equal(1)
	VarietyBKit.open_draft(w)
	assert_int(w.draft.picks_left).is_equal(1)  # the reward was spent


func test_a_draft_with_nothing_left_to_pick_closes_after_the_pick() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	_only(w, &"hot_loads")
	DraftSystem.arm_next_double(w)
	VarietyBKit.open_draft(w)
	assert_int(w.draft.offer.size()).is_equal(1)
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.OK)
	assert_bool(w.draft.open).is_false()


func test_an_empty_pool_opens_an_empty_draft_that_can_be_skipped() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	_only(w, &"no_such_directive")
	VarietyBKit.open_draft(w)
	assert_bool(w.draft.open).is_true()
	assert_int(w.draft.offer.size()).is_equal(0)
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(DraftSystem.skip(w, 2)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(60)


func test_skip_pays_sixty_scrap() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	assert_int(w.scrap).is_equal(0)
	assert_int(DraftSystem.skip(w, 1)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(60)
	assert_bool(w.draft.open).is_false()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	var paid: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.SCRAP_CHANGED)
	assert_int(paid[paid.size() - 1].b).is_equal(60)
	assert_int(w.stats.scrap_earned).is_equal(60)


func test_skip_after_a_first_pick_of_a_double_draft_pays_nothing() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	DraftSystem.arm_next_double(w)
	VarietyBKit.open_draft(w)
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.OK)
	assert_int(DraftSystem.skip(w, 2)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(0)
	assert_bool(w.draft.open).is_false()


func test_skip_by_command_closes_the_draft_and_the_sim_runs_on() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	assert_int(VarietyBKit.send(w, SimCommand.skip_draft(VarietyBKit.next_id()))).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(60)
	assert_int(w.tick).is_equal(1)
	w.step()
	assert_int(w.tick).is_equal(2)


func test_every_directive_pick_recomputes_the_mods() -> void:
	var w: SimWorld = VarietyBKit.intermission_world(c)
	_only(w, &"hot_loads")
	VarietyBKit.open_draft(w)
	assert_int(DraftSystem.pick(w, 1, 0)).is_equal(Reason.Id.OK)
	assert_float(w.mods.lvl_damage).is_equal(1.0)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)


func test_the_draft_state_survives_a_json_round_trip() -> void:
	var w: SimWorld = VarietyBKit.draft_world(c)
	w.draft.free_rerolls = 2
	assert_int(DraftSystem.reroll(w, 1)).is_equal(Reason.Id.OK)
	var copy: DraftState = DraftState.new(c.directives.size())
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(w.draft.to_dict()))
	copy.from_dict(parsed)
	var a: StateHasher = StateHasher.new()
	var b: StateHasher = StateHasher.new()
	w.draft.hash_into(a)
	copy.hash_into(b)
	assert_str(b.finish()).is_equal(a.finish())
	assert_int(copy.slots_left()).is_equal(3)
