extends GdUnitTestSuite
## W3-A: the ids a PolicyBot puts on its commands. On its own it counts 1, 2, 3 ...; with `id_source` (what Game sets)
## it draws from the same counter as the HUD, so a player tapping during an --autoplay run cannot repeat an id (the sim
## answers a repeated id with DUPLICATE_COMMAND and drops the command).


func _ids_of(w: SimWorld) -> Array[int]:
	var ids: Array[int] = []
	for c: SimCommand in w.command_log.entries:
		ids.append(c.command_id)
	return ids


func test_without_an_id_source_the_ids_count_up_from_1() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(5000)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	for t: int in 4:
		bot.act(w)
		w.step()
	assert_array(_ids_of(w)).is_equal([1, 2, 3, 4])
	assert_int(bot.commands_submitted).is_equal(4)


func test_with_an_id_source_the_bot_uses_the_ids_that_source_mints() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(5000)
	var api: RunApi = RunApi.new()
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	bot.id_source = api.next_command_id
	api.next_command_id()  # a human tap took id 1 first
	for t: int in 3:
		bot.act(w)
		w.step()
	assert_array(_ids_of(w)).is_equal([2, 3, 4])
	assert_int(bot.commands_submitted).is_equal(3)  # still counts what it submitted


func test_a_bot_and_a_human_sharing_one_counter_never_repeat_an_id() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(5000)
	var api: RunApi = RunApi.new()
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	bot.id_source = api.next_command_id
	for t: int in 40:
		bot.act(w)
		w.submit(SimCommand.skip(api.next_command_id()))  # a human tap every tick (a skip does nothing outside INTERMISSION)
		w.step()
	var ids: Array[int] = _ids_of(w)
	var seen: Dictionary[int, bool] = {}
	for command_id: int in ids:
		assert_bool(seen.has(command_id)).is_false()
		seen[command_id] = true
	assert_int(ids.size()).is_equal(bot.commands_submitted + 40)
	assert_int(bot.commands_submitted).is_greater(3)


func test_two_private_counters_do_repeat_ids_which_is_why_game_shares_one() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(5000)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	var api: RunApi = RunApi.new()
	bot.act(w)  # the bot's id 1
	w.submit(SimCommand.purchase(api.next_command_id(), Ids.UP_DAMAGE))  # the HUD's id 1 as well
	w.step()
	var answers: Array[int] = []
	for e: SimEvent in w.events.peek():
		if e.kind == SimEventKind.Id.PURCHASE_RESOLVED:
			answers.append(e.b)
	assert_array(answers).contains([Reason.Id.DUPLICATE_COMMAND])
