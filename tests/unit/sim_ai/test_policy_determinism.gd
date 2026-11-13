extends GdUnitTestSuite
## V2-H: every policy is a pure function of the world: the same seed gives the same run, a bot draws from no stream of
## the world, a bot that answers a choice at once or after 600 idle calls gives the same final hash, and a run replays
## from its command log. The legacy `greedy` and `none` bots still play the legacy fixture to the numbers recorded
## before V2-H (BALANCE_REPORT: `balance_run.ps1 -Runs 5 -Data res://tests/fixtures/data_baseline`).

const PLAYED: Array[int] = [
	PolicyBot.Policy.NONE, PolicyBot.Policy.GREEDY, PolicyBot.Policy.RANDOM, PolicyBot.Policy.HOARDER,
	PolicyBot.Policy.SPAMMER, PolicyBot.Policy.TURRET_RUSH, PolicyBot.Policy.BALANCED, PolicyBot.Policy.RISK,
]


func _play(policy: int, run_seed: int, ticks: int) -> SimWorld:
	var world: SimWorld = VarietyHKit.world(run_seed)
	var bot: PolicyBot = PolicyBot.new(policy)
	while not world.is_over() and world.tick < ticks:
		bot.act(world)
		world.step()
		world.events.drain()
	return world


func _rng_hash(world: SimWorld) -> String:
	var h: StateHasher = StateHasher.new()
	world.rng.hash_into(h)
	return h.finish()


func test_the_same_seed_plays_the_same_run_for_every_policy() -> void:
	for policy: int in PolicyBot.Policy.values():
		var a: SimWorld = _play(policy, 4, 2500)
		var b: SimWorld = _play(policy, 4, 2500)
		assert_str(a.state_hash()).is_equal(b.state_hash())
		assert_int(a.events.event_hash).is_equal(b.events.event_hash)
		assert_int(a.command_log.entries.size()).is_equal(b.command_log.entries.size())


func test_a_bot_never_touches_a_stream_of_the_world() -> void:
	for policy: int in PolicyBot.Policy.values():
		var w: SimWorld = VarietyHKit.world(6)
		var bot: PolicyBot = PolicyBot.new(policy)
		w.set_phase(GameState.Id.SPAWNING)
		VarietyHKit.crowd(w, 14, 3.0, true)
		var before: String = _rng_hash(w)
		for t: int in range(0, 600, 6):
			w.tick = t  # every tick modulus the bots scan on
			bot.act(w)
			w.command_queue.clear()
		w.phase_state.awaiting = PhaseState.Await.DRAFT
		VarietyHKit.offer(w, [&"hot_loads", &"cyclic_tuning", &"reinforced_cage"])
		bot.act(w)
		assert_str(_rng_hash(w)).is_equal(before)


func test_the_idle_decisions_of_a_bot_leave_the_streams_where_a_botless_run_has_them() -> void:
	for policy: int in PLAYED:
		var with_bot: SimWorld = _play(policy, 3, 1800)
		var replayed: SimWorld = Replay.run(SimConfig.create(with_bot.content, 3), with_bot.command_log, 1800)
		assert_str(_rng_hash(replayed)).is_equal(_rng_hash(with_bot))
		assert_str(replayed.state_hash()).is_equal(with_bot.state_hash())  # the log is all the bot ever did


func _answered_after(policy: int, idle_steps: int) -> String:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT, 2, 5)
	VarietyHKit.offer(w, [&"hot_loads", &"incendiary_tips", &"glass_cannon", &"reinforced_cage"])
	var bot: PolicyBot = PolicyBot.new(policy)
	for _n: int in idle_steps:
		w.step()  # the player is thinking: nothing is queued and the tick must not move
	bot.act(w)
	w.step()
	w.phase_state.awaiting = PhaseState.Await.NONE  # the draft the sim systems would close
	for _n: int in 900:
		bot.act(w)
		w.step()
		w.events.drain()
	return w.state_hash()


func test_answering_after_0_or_600_idle_calls_gives_the_same_final_hash() -> void:
	for policy: int in PolicyBot.Policy.values():
		assert_str(_answered_after(policy, 600)).is_equal(_answered_after(policy, 0))


func test_thinking_time_does_not_move_the_tick() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE, 3)
	var frozen: String = w.state_hash()
	var tick: int = w.tick
	for _n: int in 600:
		w.step()
	assert_int(w.tick).is_equal(tick)
	assert_str(w.state_hash()).is_equal(frozen)
	PolicyBot.new(PolicyBot.Policy.BALANCED).act(w)
	w.step()
	assert_int(w.tick).is_equal(tick + 1)  # one tick to apply the answer


func test_the_run_of_a_bot_replays_from_its_command_log() -> void:
	for policy: int in PLAYED:
		var played: SimWorld = _play(policy, 8, 4000)
		var replayed: SimWorld = Replay.run(SimConfig.create(played.content, 8), played.command_log, 4000)
		assert_str(replayed.state_hash()).is_equal(played.state_hash())
		assert_int(replayed.events.event_hash).is_equal(played.events.event_hash)


func test_a_random_bot_plays_the_same_with_the_same_seed_and_not_with_another() -> void:
	var a: SimWorld = _play(PolicyBot.Policy.RANDOM, 11, 5000)
	var b: SimWorld = _play(PolicyBot.Policy.RANDOM, 11, 5000)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	var fired_a: Array[int] = []
	var fired_b: Array[int] = []
	for c: SimCommand in a.command_log.entries:
		fired_a.append(c.tick)
	for c: SimCommand in _play(PolicyBot.Policy.RANDOM, 12, 5000).command_log.entries:
		fired_b.append(c.tick)
	assert_bool(fired_a == fired_b and not fired_a.is_empty()).is_false()


# --- the legacy bots keep their numbers ---


func test_the_legacy_greedy_bot_still_wins_the_legacy_run_with_the_same_numbers() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.baseline(), 1), PolicyBot.Policy.GREEDY)
	assert_str(report.result_name()).is_equal("VICTORY")
	assert_int(floori(report.core_hp)).is_equal(830)
	assert_int(report.purchases).is_equal(14)
	assert_float(report.seconds()).is_between(244.85, 244.95)  # BALANCE: seconds=244.9
	assert_str(report.state_hash.substr(0, 12)).is_equal("78351275ead6")
	assert_int(report.violations.size()).is_equal(0)
	assert_int(report.death_wave).is_equal(0)


func test_the_legacy_none_bot_still_loses_in_wave_three_with_the_same_numbers() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.baseline(), 1), PolicyBot.Policy.NONE)
	assert_str(report.result_name()).is_equal("DEFEAT")
	assert_float(report.seconds()).is_between(135.05, 135.15)  # BALANCE: seconds=135.1
	assert_str(report.state_hash.substr(0, 12)).is_equal("ae885c696820")
	assert_int(report.death_wave).is_equal(3)
	assert_int(report.commands).is_equal(0)


func test_the_legacy_greedy_signature_is_the_smg() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.baseline(), 2), PolicyBot.Policy.GREEDY)
	assert_str(report.signature).is_equal("smg")
