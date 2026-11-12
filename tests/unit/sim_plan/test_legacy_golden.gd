extends GdUnitTestSuite
## V2-A: the legacy 5-wave fixture runs exactly as before. The values were recorded on main (fb7d6de, before the run plan,
## the awaits and the capped queue existed) and must never change: same state hash and event hash at the same tick.


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
	assert_str(w.state_hash()).is_equal("c298f9a29f2fa5adbc9c00ef4796738ca7969ebeca5529af3d767d9dac8c4525")
	assert_int(w.events.event_hash).is_equal(-7709519793995010461)
	assert_int(w.waves_completed).is_equal(2)


func test_a_greedy_run_of_seed_7_is_unchanged() -> void:
	var w: SimWorld = _greedy(7)
	assert_str(w.state_hash()).is_equal("3ff3702ae7d07e0e4448b31db9556e199ddc9fcf7cfa2ec619ee7d65ff87d778")
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
	assert_str(w.state_hash()).is_equal("03e401387e6a42f368818aa7761600ca1f2a22fa09aa0ced9eadc7315fe0cedf")
	assert_int(w.events.event_hash).is_equal(-704475404466376443)
