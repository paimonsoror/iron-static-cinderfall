extends GdUnitTestSuite
## V2-H: the `random` bot draws only from its own generator (seeded from hash(seed, "bot")), never from a stream of the
## world, and draws only when it answers a choice or rolls the once-per-second ability check.


func _rng_hash(w: SimWorld) -> String:
	var h: StateHasher = StateHasher.new()
	w.rng.hash_into(h)
	return h.finish()


func _picks(run_seed: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for _n: int in count:
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT, 2, run_seed)
		VarietyHKit.offer(w, [&"hot_loads", &"cyclic_tuning", &"reinforced_cage"])
		var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.RANDOM)
		bot.act(w)
		out.append(w.command_queue[0].arg)
	return out


func test_the_generator_is_seeded_outside_the_world_from_the_seed_and_the_word_bot() -> void:
	var w: SimWorld = VarietyHKit.world(77)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.RANDOM)
	var rng: RandomNumberGenerator = bot.bot_rng(w)
	assert_int(rng.seed).is_equal("77|bot".hash())
	assert_object(bot.bot_rng(w)).is_same(rng)  # created once
	var other: RandomNumberGenerator = PolicyBot.new(PolicyBot.Policy.RANDOM).bot_rng(VarietyHKit.world(78))
	assert_bool(other.seed == rng.seed).is_false()


func test_it_draws_from_no_stream_of_the_world() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT)
	VarietyHKit.offer(w, [&"hot_loads", &"cyclic_tuning", &"reinforced_cage"])
	var before: String = _rng_hash(w)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.RANDOM)
	bot.act(w)
	w.command_queue.clear()
	w.phase_state.awaiting = PhaseState.Await.NONE
	for _n: int in 200:
		bot.act(w)
		w.command_queue.clear()
	assert_str(_rng_hash(w)).is_equal(before)  # no stream was created or advanced by the bot


func test_a_draft_pick_is_one_of_the_open_slots_and_every_slot_gets_picked() -> void:
	var seen: Dictionary[int, bool] = {}
	for slot: int in _picks(1, 1):
		seen[slot] = true
	for run_seed: int in range(1, 40):
		for slot: int in _picks(run_seed, 1):
			assert_bool(slot >= 0 and slot < 3).is_true()
			seen[slot] = true
	assert_int(seen.size()).is_equal(3)


func test_the_same_seed_picks_the_same_and_another_seed_may_not() -> void:
	assert_array(_picks(5, 3)).is_equal(_picks(5, 3))
	var all_same: bool = true
	for run_seed: int in range(1, 30):
		if _picks(run_seed, 1) != _picks(1, 1):
			all_same = false
	assert_bool(all_same).is_false()


func test_a_taken_slot_is_never_picked() -> void:
	for run_seed: int in range(1, 25):
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT, 2, run_seed)
		VarietyHKit.offer(w, [&"hot_loads", &"", &"reinforced_cage"])
		PolicyBot.new(PolicyBot.Policy.RANDOM).act(w)
		assert_int(w.command_queue[0].arg).is_not_equal(1)


func test_the_route_pick_is_a_planned_option() -> void:
	for run_seed: int in range(1, 25):
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE, 2, run_seed)
		var options: Array[RouteOption] = [
			VarietyHKit.option(w, &"pack_tide", &"rw_scrap", false), VarietyHKit.option(w, &"pack_powder", &"rw_crate", true)
		]
		VarietyHKit.route(w, 3, options)
		PolicyBot.new(PolicyBot.Policy.RANDOM).act(w)
		assert_int(w.command_queue[0].arg).is_between(0, 1)


func test_the_crate_pick_is_a_legal_answer() -> void:
	for run_seed: int in range(1, 25):
		var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE, 2, run_seed)
		VarietyHKit.carry(w, 1, &"smg")
		VarietyHKit.crate(w, [&"smg", &"rail_lance"])
		var legal: Array[int] = PolicyLoadout.legal_args(w)
		PolicyBot.new(PolicyBot.Policy.RANDOM).act(w)
		assert_bool(legal.has(w.command_queue[0].arg)).is_true()


func test_legal_crate_answers_list_slots_level_up_and_scrap() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	VarietyHKit.carry(w, 1, &"smg")
	VarietyHKit.crate(w, [&"smg"])
	assert_array(PolicyLoadout.legal_args(w)).is_equal([0, 1, SalvageSystem.ACTION_LEVEL_UP, SalvageSystem.ACTION_SCRAP])
	VarietyHKit.crate(w, [&"scattergun", &"rail_lance"])
	assert_array(PolicyLoadout.legal_args(w)).is_equal([0, 1, 16, 17, SalvageSystem.ACTION_SCRAP])


func test_the_ability_roll_happens_once_per_second_and_once_per_tick() -> void:
	var w: SimWorld = VarietyHKit.world(3)
	w.set_phase(GameState.Id.SPAWNING)
	w.tick = 120
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.RANDOM)
	bot.act(w)
	var state_after_first: int = bot.bot_rng(w).state
	for _n: int in 50:
		bot.act(w)  # the same tick: no second roll
	assert_int(bot.bot_rng(w).state).is_equal(state_after_first)
	w.tick = 121
	bot.act(w)  # not a whole second
	assert_int(bot.bot_rng(w).state).is_equal(state_after_first)
	w.tick = 180
	bot.act(w)
	assert_int(bot.last_roll_tick).is_equal(180)


func test_over_many_seconds_it_fires_abilities_rarely() -> void:
	var w: SimWorld = VarietyHKit.world(9)
	w.set_phase(GameState.Id.SPAWNING)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.RANDOM)
	var fired: int = 0
	for second: int in 400:
		w.tick = 60 * (second + 1)
		bot.act(w)
		fired += w.command_queue.size()
		w.command_queue.clear()
		w.abilities.cooldown_left.fill(0)
		w.abilities.active_left.fill(0)
	# 400 s x 3 abilities x 2 % = 24 on average
	assert_int(fired).is_between(8, 48)
