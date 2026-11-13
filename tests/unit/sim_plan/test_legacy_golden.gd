extends GdUnitTestSuite
## V2-A: the legacy 5-wave fixture runs exactly as before. The event hashes, ticks and wave counts were recorded on main
## (fb7d6de, before the run plan, the awaits and the capped queue existed) and must never change.
## The three STATE hashes were re-recorded by V3-I on the merge of the eight V2 tasks (cce18ae): the other V2 tasks added
## hashed fields and start values to the variety state classes (arsenal, draft, mods, salvage), which every world
## hashes, so the old literals no longer matched although the legacy run itself is the same (the event hashes, the
## ticks and the wave counts below still do). They are identical at cce18ae and with the V3-I changes.
## Re-recorded again on the merge of wave V4 (V4-V added hashed EventState fields): the event hashes, ticks and wave counts
## are unchanged, so the legacy runs themselves still play exactly as before.


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
	assert_str(w.state_hash()).is_equal("a7d1dda26569bcdffbd8d10ddcc887dfc00ccba2bf8a38af00818045e738661d")
	assert_int(w.events.event_hash).is_equal(-7709519793995010461)
	assert_int(w.waves_completed).is_equal(2)


func test_a_greedy_run_of_seed_7_is_unchanged() -> void:
	var w: SimWorld = _greedy(7)
	assert_str(w.state_hash()).is_equal("a1bbc7e8d5071d5083771515a959007eb449fe4514f36a443aba775fbb75a6af")
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
	assert_str(w.state_hash()).is_equal("9626e441a00284acb729198a62b226edd155dcfbfed63ddf13e46dd20cabe908")
	assert_int(w.events.event_hash).is_equal(-704475404466376443)
