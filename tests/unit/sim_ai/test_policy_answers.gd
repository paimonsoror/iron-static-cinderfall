extends GdUnitTestSuite
## V2-H: every policy answers every choice of the intermission (draft, route, salvage, boss briefing) with the
## SimCommand the choice calls for, on the next call. The states are written by hand (VarietyHKit), so the suite does
## not depend on which sim systems have landed. Content: TestContent.variety().


func _bot(policy: int) -> PolicyBot:
	return PolicyBot.new(policy)


func _only(w: SimWorld) -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


func _open_draft(w: SimWorld) -> void:
	VarietyHKit.offer(w, [&"incendiary_tips", &"hot_loads", &"glass_cannon", &"reinforced_cage"])


# --- none ---


func test_none_skips_the_draft() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
	_open_draft(w)
	_bot(PolicyBot.Policy.NONE).act(w)
	assert_int(_only(w).kind).is_equal(SimCommand.Kind.SKIP_DRAFT)


func test_none_takes_route_a() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE)
	_bot(PolicyBot.Policy.NONE).act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_ROUTE)
	assert_int(cmd.arg).is_equal(0)


func test_none_scraps_every_crate() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	VarietyHKit.crate(w, [&"scattergun"])
	_bot(PolicyBot.Policy.NONE).act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.SALVAGE)
	assert_int(cmd.arg).is_equal(0 * 16 + SalvageSystem.ACTION_SCRAP)


func test_every_policy_continues_past_a_boss_briefing() -> void:
	for policy: int in PolicyBot.Policy.values():
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.BOSS_BRIEF, 4)
		_bot(policy).act(w)
		assert_int(_only(w).kind).is_equal(SimCommand.Kind.SKIP_INTERMISSION)


func test_none_does_nothing_while_nothing_waits() -> void:
	var w: SimWorld = VarietyHKit.world()
	var bot: PolicyBot = _bot(PolicyBot.Policy.NONE)
	for _n: int in 300:
		bot.act(w)
		w.step()
	assert_int(bot.commands_submitted).is_equal(0)


# --- greedy ---


func test_greedy_takes_the_lowest_rarity_and_the_leftmost_of_a_tie() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
	_open_draft(w)  # rare, common, corrupted, common
	_bot(PolicyBot.Policy.GREEDY).act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	assert_int(cmd.arg).is_equal(1)  # hot_loads: the first common card


func test_greedy_never_rerolls_and_skips_an_empty_offer() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
	VarietyHKit.offer(w, [&"", &""])
	w.draft.free_rerolls = 3
	w.scrap = 900
	_bot(PolicyBot.Policy.GREEDY).act(w)
	assert_int(_only(w).kind).is_equal(SimCommand.Kind.SKIP_DRAFT)


func test_greedy_takes_a_crate_into_the_empty_slot() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	VarietyHKit.crate(w, [&"scattergun"])
	_bot(PolicyBot.Policy.GREEDY).act(w)
	assert_int(_only(w).arg).is_equal(1)  # slot 0 holds the pistol, slot 1 is empty


func test_greedy_replaces_the_lowest_tier_when_both_slots_are_full() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	VarietyHKit.carry(w, 1, &"lmg")
	VarietyHKit.crate(w, [&"scattergun"])
	_bot(PolicyBot.Policy.GREEDY).act(w)
	assert_int(_only(w).arg).is_equal(0)  # the pistol (T1) goes


func test_greedy_levels_up_a_duplicate() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	VarietyHKit.carry(w, 1, &"smg", 2)
	VarietyHKit.crate(w, [&"smg"])
	_bot(PolicyBot.Policy.GREEDY).act(w)
	assert_int(_only(w).arg).is_equal(SalvageSystem.ACTION_LEVEL_UP)


func test_greedy_takes_route_a() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE)
	_bot(PolicyBot.Policy.GREEDY).act(w)
	assert_int(_only(w).arg).is_equal(0)


# --- the net and the guards ---


func test_a_policy_that_decides_nothing_still_answers_every_choice() -> void:
	var unknown_policy: int = 99  # PolicyBot.act finds no rule for it: the net answers like `none`
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
	_open_draft(w)
	_bot(unknown_policy).act(w)
	assert_int(_only(w).kind).is_equal(SimCommand.Kind.SKIP_DRAFT)
	var r: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE)
	_bot(unknown_policy).act(r)
	assert_int(_only(r).kind).is_equal(SimCommand.Kind.PICK_ROUTE)


func test_an_answer_already_queued_is_not_answered_twice() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE)
	var bot: PolicyBot = _bot(PolicyBot.Policy.BALANCED)
	bot.act(w)
	bot.act(w)
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(1)
	assert_int(bot.commands_submitted).is_equal(1)


func test_nothing_is_submitted_once_the_run_is_over() -> void:
	for policy: int in PolicyBot.Policy.values():
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
		w.phase = GameState.Id.DEFEAT  # a debug write: INTERMISSION has no legal move to DEFEAT
		_bot(policy).act(w)
		assert_int(w.command_queue.size()).is_equal(0)


func test_commands_use_the_ids_of_the_shared_counter() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE)
	var api: RunApi = RunApi.new()
	var bot: PolicyBot = _bot(PolicyBot.Policy.GREEDY)
	bot.id_source = api.next_command_id
	api.next_command_id()  # a human tap took id 1
	bot.act(w)
	assert_int(_only(w).command_id).is_equal(2)
