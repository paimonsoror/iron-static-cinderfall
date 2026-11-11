extends GdUnitTestSuite
## Same seed and same commands give the same game, hash for hash (ARCH 6.1; TEST_PLAN "Stress": identical event
## hashes for the same seed and commands; "varied seed sweep"). Runs on the shipped data.

const CHECKPOINTS: Array[int] = [600, 6000]

var content: ContentSet
var reference: HarnessReport
var state_at: Dictionary[int, String] = {}  ## tick -> state_hash of the reference run
var events_at: Dictionary[int, int] = {}  ## tick -> event_hash of the reference run


func before() -> void:
	content = HarnessKit.shipped()
	# the reference run: greedy bot, seed 7, hashes recorded on the way
	var world: SimWorld = SimWorld.new(HarnessKit.config(content, 7))
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	var checker: HarnessChecker = HarnessChecker.new(world)
	while not world.is_over() and world.tick < SimHarness.DEFAULT_MAX_TICKS:
		bot.act(world)
		world.step()
		checker.after_step(world, world.events.drain())
		if CHECKPOINTS.has(world.tick):
			state_at[world.tick] = world.state_hash()
			events_at[world.tick] = world.events.event_hash
	checker.finish(world, bot.commands_submitted)
	reference = SimHarness.report_of(world, PolicyBot.Policy.GREEDY, checker)


func test_the_reference_run_is_clean_and_long_enough_to_cover_the_checkpoints() -> void:
	assert_int(reference.violations.size()).is_equal(0)
	assert_bool(reference.timed_out).is_false()
	assert_int(reference.ticks).is_greater(CHECKPOINTS[CHECKPOINTS.size() - 1])
	assert_int(state_at.size()).is_equal(CHECKPOINTS.size())


func test_a_replay_of_the_log_matches_at_ticks_600_6000_and_the_end() -> void:
	for tick: int in CHECKPOINTS:
		var cut: SimWorld = Replay.run(HarnessKit.config(content, 7), reference.log, tick)
		assert_int(cut.tick).is_equal(tick)
		assert_str(cut.state_hash()).is_equal(state_at[tick])
		assert_int(cut.events.event_hash).is_equal(events_at[tick])
	var full: SimWorld = Replay.run(HarnessKit.config(content, 7), reference.log, SimHarness.DEFAULT_MAX_TICKS)
	assert_int(full.tick).is_equal(reference.ticks)
	assert_str(full.state_hash()).is_equal(reference.state_hash)
	assert_int(full.events.event_hash).is_equal(reference.event_hash)
	assert_int(full.result()).is_equal(reference.result)


func test_playing_the_same_seed_again_gives_the_same_game() -> void:
	var again: HarnessReport = SimHarness.run(HarnessKit.config(content, 7), PolicyBot.Policy.GREEDY)
	assert_str(again.state_hash).is_equal(reference.state_hash)
	assert_int(again.event_hash).is_equal(reference.event_hash)
	assert_int(again.ticks).is_equal(reference.ticks)
	assert_array(again.log.to_dicts()).is_equal(reference.log.to_dicts())


func test_a_separate_load_of_the_data_changes_nothing() -> void:
	var other: ContentSet = HarnessKit.shipped()
	var cut: SimWorld = Replay.run(HarnessKit.config(other, 7), reference.log, 6000)
	assert_str(cut.state_hash()).is_equal(state_at[6000])


func test_a_different_command_log_gives_a_different_game() -> void:
	var cut: CommandLog = CommandLog.from_dicts(reference.log.to_dicts())
	assert_int(cut.entries.size()).is_greater(3)
	cut.entries.remove_at(2)  # one purchase never happens
	var changed: SimWorld = Replay.run(HarnessKit.config(content, 7), cut, 6000)
	assert_str(changed.state_hash()).is_not_equal(state_at[6000])


func test_ten_seeds_give_at_least_nine_distinct_hashes() -> void:
	var states: Dictionary[String, bool] = {}
	var events: Dictionary[int, bool] = {}
	for k: int in 10:
		var world: SimWorld = SimWorld.new(HarnessKit.config(content, 100 + k))
		var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
		while world.tick < 6000 and not world.is_over():
			bot.act(world)
			world.step()
			world.events.drain()
		states[world.state_hash()] = true
		events[world.events.event_hash] = true
	assert_int(states.size()).is_greater_equal(9)
	assert_int(events.size()).is_greater_equal(9)
