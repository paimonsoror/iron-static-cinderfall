extends GdUnitTestSuite
## Seed sweep (TEST_PLAN "varied seed sweep"): 20 seeds, greedy bot, shipped data. No script error (an error would
## abort the suite), every run ends before tick 60,000, no broken invariant in any run.

const SEEDS: int = 20

var reports: Array[HarnessReport] = []


func before() -> void:
	var content: ContentSet = HarnessKit.shipped()
	for k: int in SEEDS:
		reports.append(SimHarness.run(HarnessKit.config(content, 1 + k), PolicyBot.Policy.GREEDY, 60000))


func test_every_run_ends_before_tick_60000() -> void:
	assert_int(reports.size()).is_equal(SEEDS)
	for r: HarnessReport in reports:
		assert_bool(r.timed_out).is_false()
		assert_int(r.ticks).is_less(60000)
		assert_bool(r.result == RunResult.Id.VICTORY or r.result == RunResult.Id.DEFEAT).is_true()


func test_no_run_breaks_an_invariant() -> void:
	for r: HarnessReport in reports:
		assert_str("seed %d: %s" % [r.run_seed, "; ".join(r.violations)]).is_equal("seed %d: " % r.run_seed)


func test_the_greedy_bot_wins_almost_every_seed() -> void:
	var wins: int = 0
	for r: HarnessReport in reports:
		wins += 1 if r.is_victory() else 0
	assert_int(wins).is_greater_equal(floori(float(SEEDS) * 0.9))


func test_every_seed_is_its_own_game() -> void:
	var hashes: Dictionary[String, bool] = {}
	for r: HarnessReport in reports:
		hashes[r.state_hash] = true
	assert_int(hashes.size()).is_greater_equal(SEEDS - 1)
