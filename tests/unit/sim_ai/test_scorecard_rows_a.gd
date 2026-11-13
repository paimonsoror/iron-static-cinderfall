extends GdUnitTestSuite
## V4-T: the scorecard maths of S1 to S10 on synthetic results (hand-made records, no run is played): every row on both
## sides of its boundary, and the cases that are a structural break (FAIL).

const PASS: int = Scorecard.Verdict.PASS
const WARN: int = Scorecard.Verdict.WARN
const FAIL: int = Scorecard.Verdict.FAIL


func _rows(runs: Array[Dictionary]) -> Array[Dictionary]:
	return Scorecard.evaluate(runs, ScorecardTKit.context())


func _v(runs: Array[Dictionary], id: String) -> int:
	return ScorecardTKit.verdict(_rows(runs), id)


func _with_cores(cores: Array[float]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in cores.size():
		out.append(ScorecardTKit.run("balanced", true, k + 1, {"act_end_core": [cores[k], 0.5, 0.4]}))
	return out


# --- S1 to S3: do seeds matter? ---


func test_s1_wants_a_spread_of_the_core_after_act_one() -> void:
	assert_int(_v(_with_cores([0.9, 0.3, 0.6, 0.1]), "S1")).is_equal(PASS)  # stdev 0.30
	assert_int(_v(_with_cores([0.5, 0.5, 0.5, 0.5]), "S1")).is_equal(WARN)  # the same core every time
	assert_int(_v(_with_cores([0.5, 0.62]), "S1")).is_equal(WARN)  # stdev 0.06


func test_s1_value_is_the_population_standard_deviation() -> void:
	var r: Dictionary = ScorecardTKit.row(_rows(_with_cores([0.2, 0.4])), "S1")
	assert_float(ScorecardTKit.number(r, "value")).is_equal_approx(0.1, 0.0001)
	assert_int(ScorecardTKit.whole(r, "verdict")).is_equal(WARN)  # 0.1 is under 0.12


func test_s1_counts_a_run_that_fell_in_act_one_as_an_empty_core() -> void:
	var runs: Array[Dictionary] = [
		ScorecardTKit.run("balanced", false, 1, {"act_end_core": [-1.0, -1.0, -1.0]}),
		ScorecardTKit.run("balanced", true, 2, {"act_end_core": [0.8, 0.5, 0.4]}),
	]
	var r: Dictionary = ScorecardTKit.row(_rows(runs), "S1")
	assert_float(ScorecardTKit.number(r, "value")).is_equal_approx(0.4, 0.0001)  # 0.0 and 0.8
	assert_int(ScorecardTKit.whole(r, "verdict")).is_equal(PASS)


func test_a_row_without_enough_runs_warns_and_says_so() -> void:
	var rows: Array[Dictionary] = _rows([ScorecardTKit.run("balanced", true)])
	assert_int(ScorecardTKit.verdict(rows, "S1")).is_equal(WARN)
	assert_str(ScorecardTKit.text(ScorecardTKit.row(rows, "S1"), "measured")).contains("not measured")
	assert_int(ScorecardTKit.verdict(_rows([]), "S4")).is_equal(WARN)


func test_s2_wants_a_spread_of_the_duration_of_wins() -> void:
	var spread: Array[Dictionary] = []
	for k: int in 4:
		spread.append(ScorecardTKit.run("balanced", true, k + 1, {"combat_s": 800.0 + 70.0 * float(k)}))
	assert_int(_v(spread, "S2")).is_equal(PASS)  # stdev 78
	var flat: Array[Dictionary] = ScorecardTKit.batch("balanced", 4, 0)
	assert_int(_v(flat, "S2")).is_equal(WARN)  # every win lasts 900 s
	assert_int(_v(ScorecardTKit.batch("balanced", 1, 3), "S2")).is_equal(WARN)  # one win has no spread


func test_s3_is_the_median_overlap_of_the_final_directive_sets() -> void:
	var same: Array[Dictionary] = []
	var apart: Array[Dictionary] = []
	for k: int in 4:
		same.append(ScorecardTKit.run("balanced", true, k + 1, {"held": ["a", "b", "c"]}))
		apart.append(ScorecardTKit.run("balanced", true, k + 1, {"held": ["d%d" % k, "e%d" % k]}))
	assert_int(_v(same, "S3")).is_equal(WARN)  # all alike: similarity 1.0
	assert_int(_v(apart, "S3")).is_equal(PASS)  # nothing in common: 0.0
	assert_float(ScorecardTKit.number(ScorecardTKit.row(_rows(same), "S3"), "value")).is_equal_approx(1.0, 0.0001)


# --- S4 to S7: win rates ---


func test_s4_balanced_wins_between_40_and_70_percent() -> void:
	assert_int(_v(ScorecardTKit.batch("balanced", 4, 6), "S4")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("balanced", 7, 3), "S4")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 7), "S4")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("balanced", 8, 2), "S4")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("balanced", 10, 0), "S4")).is_equal(WARN)  # too easy is a number, not a break


func test_s4_balanced_never_winning_is_a_structural_break_only_with_enough_runs() -> void:
	assert_int(_v(ScorecardTKit.batch("balanced", 0, 10), "S4")).is_equal(FAIL)
	assert_int(_v(ScorecardTKit.batch("balanced", 0, 9), "S4")).is_equal(WARN)


func test_s5_random_wins_at_most_ten_percent() -> void:
	assert_int(_v(ScorecardTKit.batch("random", 1, 9), "S5")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("random", 2, 8), "S5")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("random", 0, 10), "S5")).is_equal(PASS)


func test_s6_none_is_always_defeated_in_act_one() -> void:
	assert_int(_v(ScorecardTKit.batch("none", 0, 4), "S6")).is_equal(PASS)
	var late: Array[Dictionary] = ScorecardTKit.batch("none", 0, 3)
	late.append(ScorecardTKit.run("none", false, 9, {"death_act": 2, "death_wave": 8}))
	assert_int(_v(late, "S6")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("none", 1, 3), "S6")).is_equal(FAIL)  # a bot that buys nothing won


func test_s7_greedy_wins_between_10_and_40_percent() -> void:
	assert_int(_v(ScorecardTKit.batch("greedy", 1, 9), "S7")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("greedy", 4, 6), "S7")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("greedy", 0, 10), "S7")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("greedy", 5, 5), "S7")).is_equal(WARN)


# --- S8 to S10 ---


func test_s8_the_reference_player_defeated_before_wave_three_is_a_break_and_the_others_are_counted() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 0, 49)
	runs.append(ScorecardTKit.run("none", false, 1, {"death_wave": 1}))  # `none` is not judged here
	assert_int(_v(runs, "S8")).is_equal(PASS)
	runs.append(ScorecardTKit.run("greedy", false, 2, {"death_wave": 2}))
	assert_int(_v(runs, "S8")).is_equal(WARN)  # a number to fix in the waves, not a structural break
	var detail: PackedStringArray = ScorecardTKit.row(_rows(runs), "S8")["detail"]
	assert_str(detail[0]).contains("greedy: 1 before wave 3")
	runs.append(ScorecardTKit.run("balanced", false, 3, {"death_wave": 2}))
	assert_int(_v(runs, "S8")).is_equal(FAIL)


func test_s8_allows_two_percent_of_defeats_in_wave_three() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 0, 49)  # death_wave 5
	runs.append(ScorecardTKit.run("balanced", false, 60, {"death_wave": 3}))  # 1 of 50
	assert_int(_v(runs, "S8")).is_equal(PASS)
	runs.append(ScorecardTKit.run("balanced", false, 61, {"death_wave": 3}))  # 2 of 51 is above 2%
	assert_int(_v(runs, "S8")).is_equal(WARN)


func test_s9_wants_losses_in_every_act_and_a_quarter_to_a_half_at_the_bosses() -> void:
	var runs: Array[Dictionary] = []
	for k: int in 6:
		runs.append(ScorecardTKit.run("balanced", false, k + 1, {"death_act": 1 + (k % 3), "boss_death": k < 2}))
	assert_int(_v(runs, "S9")).is_equal(PASS)  # a third of the losses in each act, a third at a boss
	var one_act: Array[Dictionary] = []
	for k: int in 4:
		one_act.append(ScorecardTKit.run("balanced", false, k + 1, {"death_act": 1, "boss_death": k == 0}))
	assert_int(_v(one_act, "S9")).is_equal(WARN)  # acts II and III hold none of the losses
	assert_int(_v(ScorecardTKit.batch("balanced", 5, 0), "S9")).is_equal(WARN)  # no loss at all is not measured


func test_s9_boss_waves_above_half_of_the_losses_warn() -> void:
	var runs: Array[Dictionary] = []
	for k: int in 6:
		runs.append(ScorecardTKit.run("balanced", false, k + 1, {"death_act": 1 + (k % 3), "boss_death": k < 4}))
	assert_int(_v(runs, "S9")).is_equal(WARN)  # 4 of 6 at a boss


func test_s10_each_specialist_between_15_and_65_and_not_far_above_balanced() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 5, 5)
	for policy: String in ScorecardRateRows.SPECIALISTS:
		runs.append_array(ScorecardTKit.batch(policy, 4, 6))
	assert_int(_v(runs, "S10")).is_equal(PASS)
	var strong: Array[Dictionary] = []
	strong.append_array(runs)
	strong.append_array(ScorecardTKit.batch("hoarder", 7, 3))  # 11/20 pooled: still inside the band
	assert_int(_v(strong, "S10")).is_equal(PASS)
	var dominant: Array[Dictionary] = ScorecardTKit.batch("balanced", 4, 6)
	for policy: String in ScorecardRateRows.SPECIALISTS:
		dominant.append_array(ScorecardTKit.batch(policy, 6 if policy == "risk" else 4, 4 if policy == "risk" else 6))
	assert_int(_v(dominant, "S10")).is_equal(WARN)  # risk 60% against balanced 40%: 20 points above


func test_s10_a_specialist_that_was_not_played_warns() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 5, 5)
	runs.append_array(ScorecardTKit.batch("hoarder", 4, 6))
	assert_int(_v(runs, "S10")).is_equal(WARN)
	assert_str(ScorecardTKit.text(ScorecardTKit.row(_rows(runs), "S10"), "measured")).contains("spammer not played")
