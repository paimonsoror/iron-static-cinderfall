extends GdUnitTestSuite
## V4-T: the small statistics of the scorecard, the record of a run and its trip through JSON, the job list and the pools.


func _floats(values: Array[float]) -> PackedFloat64Array:
	return PackedFloat64Array(values)


# --- statistics ---


func test_mean_median_and_population_standard_deviation() -> void:
	var v: PackedFloat64Array = _floats([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])
	assert_float(ScorecardStats.mean(v)).is_equal_approx(5.0, 0.0001)
	assert_float(ScorecardStats.stdev(v)).is_equal_approx(2.0, 0.0001)
	assert_float(ScorecardStats.median(v)).is_equal_approx(4.5, 0.0001)
	assert_float(ScorecardStats.median(_floats([3.0, 1.0, 2.0]))).is_equal_approx(2.0, 0.0001)
	assert_float(ScorecardStats.min_of(v)).is_equal(2.0)
	assert_float(ScorecardStats.max_of(v)).is_equal(9.0)


func test_empty_and_single_lists_give_zero() -> void:
	var none: PackedFloat64Array = PackedFloat64Array()
	assert_float(ScorecardStats.mean(none)).is_equal(0.0)
	assert_float(ScorecardStats.stdev(none)).is_equal(0.0)
	assert_float(ScorecardStats.stdev(_floats([5.0]))).is_equal(0.0)
	assert_float(ScorecardStats.median(none)).is_equal(0.0)
	assert_float(ScorecardStats.min_of(none)).is_equal(0.0)
	assert_float(ScorecardStats.rate(3, 0)).is_equal(0.0)
	assert_float(ScorecardStats.rate(1, 4)).is_equal(0.25)


func test_jaccard_is_the_shared_part_of_the_union() -> void:
	assert_float(ScorecardStats.jaccard(PackedStringArray(["a", "b", "c"]), PackedStringArray(["b", "c", "d"]))).is_equal_approx(0.5, 0.0001)
	assert_float(ScorecardStats.jaccard(PackedStringArray(["a"]), PackedStringArray(["b"]))).is_equal(0.0)
	assert_float(ScorecardStats.jaccard(PackedStringArray(["a", "a"]), PackedStringArray(["a"]))).is_equal(1.0)  # a set, not a bag
	assert_float(ScorecardStats.jaccard(PackedStringArray(), PackedStringArray())).is_equal(1.0)  # two empty builds are alike
	assert_float(ScorecardStats.jaccard(PackedStringArray(), PackedStringArray(["a"]))).is_equal(0.0)


func test_pairwise_jaccard_visits_each_pair_once() -> void:
	var sets: Array[PackedStringArray] = [PackedStringArray(["a"]), PackedStringArray(["a"]), PackedStringArray(["b"])]
	var pairs: PackedFloat64Array = ScorecardStats.pairwise_jaccard(sets)
	assert_array(Array(pairs)).is_equal([1.0, 0.0, 0.0])


func test_tally_counts_in_first_seen_order() -> void:
	var counts: Dictionary[String, int] = ScorecardStats.tally(PackedStringArray(["x", "y", "x", "x"]))
	assert_array(counts.keys()).is_equal(["x", "y"])
	assert_int(counts["x"]).is_equal(3)


# --- records ---


func test_a_record_survives_a_trip_through_json() -> void:
	var rec: Dictionary = ScorecardTKit.run("balanced", true, 7, {"held": ["a", "b"], "act_end_core": [0.5, -1.0], "core": 0.25})
	var back: Dictionary = ScorecardRecord.from_line(ScorecardRecord.to_line(rec))
	assert_str(ScorecardRecord.text(back, "policy")).is_equal("balanced")
	assert_int(ScorecardRecord.whole(back, "seed")).is_equal(7)  # JSON turned it into a float
	assert_bool(ScorecardRecord.is_win(back)).is_true()
	assert_array(Array(ScorecardRecord.strings(back, "held"))).is_equal(["a", "b"])
	assert_array(Array(ScorecardRecord.floats(back, "act_end_core"))).is_equal([0.5, -1.0])
	assert_float(ScorecardRecord.num(back, "core")).is_equal(0.25)
	assert_bool(ScorecardRecord.flag(back, "clean")).is_true()


func test_a_line_that_is_not_a_record_reads_as_empty_and_a_missing_key_as_zero() -> void:
	assert_bool(ScorecardRecord.from_line("not json").is_empty()).is_true()
	assert_bool(ScorecardRecord.from_line("[1, 2]").is_empty()).is_true()
	var empty: Dictionary = {}
	assert_int(ScorecardRecord.whole(empty, "x")).is_equal(0)
	assert_str(ScorecardRecord.text(empty, "x")).is_empty()
	assert_bool(ScorecardRecord.flag(empty, "clean", true)).is_true()
	assert_array(Array(ScorecardRecord.strings(empty, "held"))).is_empty()


func test_select_and_win_rate() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 1, 3)
	runs.append_array(ScorecardTKit.batch("greedy", 2, 0))
	runs.append(ScorecardTKit.run("balanced", true, 9, {"variant": "hot"}))
	assert_int(ScorecardRecord.select(runs, "balanced").size()).is_equal(4)
	assert_int(ScorecardRecord.select(runs, "balanced", "hot").size()).is_equal(1)
	assert_int(ScorecardRecord.main_runs(runs).size()).is_equal(6)
	assert_float(ScorecardRecord.win_rate(ScorecardRecord.select(runs, "balanced"))).is_equal(0.25)
	assert_float(ScorecardRecord.win_rate([] as Array[Dictionary])).is_equal(0.0)


# --- the job list and the pools ---


func test_the_job_list_is_eleven_runs_per_seed_in_seed_order() -> void:
	var jobs: Array[Dictionary] = ScorecardPlan.jobs(3, 10, "base")
	assert_int(jobs.size()).is_equal(33)
	for k: int in 11:
		assert_int(ScorecardTKit.whole(jobs[k], "seed")).is_equal(10)
		assert_int(ScorecardTKit.whole(jobs[22 + k], "seed")).is_equal(12)
	var main: int = 0
	for j: Dictionary in jobs:
		main += 1 if j["variant"] == "" else 0
	assert_int(main).is_equal(24)  # eight policies x three seeds
	assert_str(ScorecardTKit.text(jobs[8], "variant")).is_equal("standard")
	assert_str(ScorecardTKit.text(jobs[9], "variant")).is_equal("hot")
	assert_str(ScorecardTKit.text(jobs[10], "variant")).is_equal("other_pool")
	assert_str(ScorecardTKit.text(jobs[10], "pool")).is_equal("full")
	assert_int(ScorecardTKit.whole(jobs[10], "policy")).is_equal(PolicyBot.Policy.BALANCED)
	assert_str(ScorecardTKit.text(ScorecardPlan.jobs(1, 1, "full")[10], "pool")).is_equal("base")


func test_shards_split_the_list_without_overlap_or_gap() -> void:
	var jobs: Array[Dictionary] = ScorecardPlan.jobs(5, 1, "base")
	var seen: int = 0
	for i: int in 3:
		var part: Array[Dictionary] = ScorecardPlan.shard(jobs, i, 3)
		seen += part.size()
		assert_bool(part.size() >= floori(float(jobs.size()) / 3.0)).is_true()
	assert_int(seen).is_equal(jobs.size())
	assert_int(ScorecardPlan.shard(jobs, 0, 1).size()).is_equal(jobs.size())
	assert_dict(ScorecardPlan.shard(jobs, 1, 3)[0]).is_equal(jobs[1])


func test_the_full_pool_holds_every_unlock_and_the_base_pool_none() -> void:
	var content: ContentSet = VarietyHKit.content()
	assert_array(Array(ScorecardPlan.unlocks_of(content, "base"))).is_empty()
	assert_int(ScorecardPlan.unlocks_of(content, "full").size()).is_equal(content.unlocks.size())
	var roster_base: Array[String] = ScorecardPlan.roster(content, "base")
	assert_bool(roster_base.has("pistol")).is_true()


func test_the_context_carries_the_wave_table_and_the_caps() -> void:
	var content: ContentSet = VarietyHKit.content()
	var ctx: Dictionary = ScorecardPlan.context(content, "base")
	assert_int(ScorecardRecord.floats(ctx, "wave_bodied").size()).is_equal(content.run.waves.size())
	assert_int(ScorecardRecord.whole(ctx, "cap_bodied")).is_equal(content.mission.enemy_cap)
	assert_int(ScorecardRecord.whole(ctx, "cap_minis")).is_equal(content.mission.swarm_cap)
	assert_int(ScorecardRecord.whole(ctx, "cap_blasts")).is_equal(content.run.max_blasts_per_tick)
	assert_int(ScorecardRecord.whole(ctx, "act1_waves")).is_greater(0)


func test_the_arguments_of_the_tool() -> void:
	var a: ScorecardArgs = ScorecardArgs.parse(PackedStringArray(["--runs", "5", "--pool", "full", "--shard", "1", "--shards", "4", "--out", "x.jsonl"]))
	assert_str(a.error).is_empty()
	assert_int(a.runs).is_equal(5)
	assert_str(a.pool).is_equal("full")
	assert_int(a.shard).is_equal(1)
	assert_int(a.shards).is_equal(4)
	assert_str(a.out_file).is_equal("x.jsonl")
	assert_int(ScorecardArgs.parse(PackedStringArray()).runs).is_equal(30)  # the gate version
	assert_str(ScorecardArgs.parse(PackedStringArray(["--pool", "half"])).error).is_not_empty()
	assert_str(ScorecardArgs.parse(PackedStringArray(["--shard", "2", "--shards", "2"])).error).is_not_empty()
	assert_str(ScorecardArgs.parse(PackedStringArray(["--bogus", "1"])).error).contains("--bogus")
	assert_array(Array(ScorecardArgs.parse(PackedStringArray(["--report", "a,b"])).report_files)).is_equal(["a", "b"])
