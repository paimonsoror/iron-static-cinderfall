extends GdUnitTestSuite
## Seed sweep (TEST_PLAN "varied seed sweep"; slice exit of VARIETY_SPEC 15.2): 20 seeds, the balanced bot, the shipped
## data (a generated run). No script error (an error would abort the suite), every run ends before the tick limit with
## every choice answered, no broken invariant in any run, the slice is both winnable and losable, and the seeds are
## visibly different runs (plan, packs, builds, outcome). `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` plays
## the same 20 runs.

const SEEDS: int = 20

var reports: Array[HarnessReport] = []


func before() -> void:
	var content: ContentSet = HarnessKit.shipped()
	for k: int in SEEDS:
		reports.append(SimHarness.run(HarnessKit.config(content, 1 + k), PolicyBot.Policy.BALANCED, 0))


func test_every_run_ends_before_the_tick_limit_with_every_choice_answered() -> void:
	assert_int(reports.size()).is_equal(SEEDS)
	for r: HarnessReport in reports:
		assert_bool(r.timed_out).override_failure_message("seed %d did not finish" % r.run_seed).is_false()
		assert_bool(r.stalled).override_failure_message("seed %d stalled on await %d" % [r.run_seed, r.stalled_on]).is_false()
		assert_int(r.ticks).is_less(SimHarness.VARIETY_MAX_TICKS)
		assert_bool(r.result == RunResult.Id.VICTORY or r.result == RunResult.Id.DEFEAT).is_true()


func test_no_run_breaks_an_invariant() -> void:
	for r: HarnessReport in reports:
		assert_str("seed %d: %s" % [r.run_seed, "; ".join(r.violations)]).is_equal("seed %d: " % r.run_seed)


func test_the_slice_is_winnable_and_losable() -> void:
	var wins: int = 0
	var losses: int = 0
	for r: HarnessReport in reports:
		wins += 1 if r.is_victory() else 0
		losses += 1 if r.result == RunResult.Id.DEFEAT else 0
	assert_int(wins).is_greater_equal(1)
	assert_int(losses).is_greater_equal(1)
	assert_int(wins + losses).is_equal(SEEDS)


func test_every_seed_is_its_own_game() -> void:
	var hashes: Dictionary[String, bool] = {}
	var plans: Dictionary[String, bool] = {}
	var packs: Dictionary[String, bool] = {}
	var builds: Dictionary[String, bool] = {}
	for r: HarnessReport in reports:
		hashes[r.state_hash] = true
		var plan_hash: StateHasher = StateHasher.new()
		r.world.plan.hash_into(plan_hash)
		plans[plan_hash.finish()] = true
		var pack_ids: PackedStringArray = PackedStringArray()
		for wave_number: int in range(1, r.world.plan.wave_count() + 1):
			for option: RouteOption in r.world.plan.wave(wave_number).options:
				pack_ids.append(str(option.pack_index) + ("h" if option.hot else "s"))
		packs["/".join(pack_ids)] = true
		builds[str(r.world.draft.stacks)] = true
	assert_int(hashes.size()).is_equal(SEEDS)
	assert_int(plans.size()).is_equal(SEEDS)  # the spawn lists differ for every seed
	assert_int(packs.size()).is_greater_equal(4)  # and so does the order of packs and hot routes
	assert_int(builds.size()).is_greater_equal(6)  # the drafts led to different builds
