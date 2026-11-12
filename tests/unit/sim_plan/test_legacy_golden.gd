extends GdUnitTestSuite
## V2-A: the legacy 5-wave fixture runs exactly as before. The event hashes, ticks and wave counts were recorded on main
## (fb7d6de, before the run plan, the awaits and the capped queue existed) and must never change.
## The three STATE hashes were re-recorded by V3-I on the merge of the eight V2 tasks (cce18ae): the other V2 tasks added
## hashed fields and start values to the variety state classes (arsenal, draft, mods, salvage), which every world
## hashes, so the old literals no longer matched although the legacy run itself is the same (the event hashes, the
## ticks and the wave counts below still do). They are identical at cce18ae and with the V3-I changes.


func _greedy(run_seed: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.baseline(), run_seed))
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	for _n: int in 6000:
		bot.act(w)
		w.step()
		w.events.drain()
	return w


func test_a_greedy_run_of_seed_1_is_unchanged() -> void:
	var w: SimWorld = _greedy(1)
	assert_str(w.state_hash()).is_equal("1590a185b5ffdddeea21eeec379badee6da1569d6d0903557ebf4e3c254d5042")
	assert_int(w.events.event_hash).is_equal(-7709519793995010461)
	assert_int(w.waves_completed).is_equal(2)


func test_a_greedy_run_of_seed_7_is_unchanged() -> void:
	var w: SimWorld = _greedy(7)
	assert_str(w.state_hash()).is_equal("e60a3204525c7967449ec6258a58a864374737d0655e5ef4341c425c48e17fed")
	assert_int(w.events.event_hash).is_equal(7106969127358763225)


func test_a_full_legacy_run_is_unchanged() -> void:
	var w: SimWorld = TestContent.world(3)
	for _n: int in 6000:
		if w.is_over():
			break
		if GameState.is_combat(w.phase):
			w.phase_state.force_wave_spawned = true
			VarietyAKit.kill_all(w)
		w.step()
	assert_int(w.tick).is_equal(2106)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_str(w.state_hash()).is_equal("3bde301527cef88e6d388e2766a57358c650de57fe598b9856c439625f4e2581")
	assert_int(w.events.event_hash).is_equal(-704475404466376443)
