extends GdUnitTestSuite
## V4-T: the scorecard maths of S11 to S18, the integrity row and the summary line, on synthetic results.

const PASS: int = Scorecard.Verdict.PASS
const WARN: int = Scorecard.Verdict.WARN
const FAIL: int = Scorecard.Verdict.FAIL


func _rows(runs: Array[Dictionary]) -> Array[Dictionary]:
	return Scorecard.evaluate(runs, ScorecardTKit.context())


func _v(runs: Array[Dictionary], id: String) -> int:
	return ScorecardTKit.verdict(_rows(runs), id)


## `count` wins of `policy`, each with the signature and primary weapon from the lists (cycled).
func _wins_with(signatures: Array[String], weapons: Array[String], count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in count:
		var extra: Dictionary = {"signature": signatures[k % signatures.size()], "primary": weapons[k % weapons.size()]}
		out.append(ScorecardTKit.run("balanced", true, k + 1, extra))
	return out


# --- S11, S12: builds and weapons ---


func test_s11_wants_eight_signatures_with_four_percent_each_and_none_above_a_quarter() -> void:
	var many: Array[String] = []
	for k: int in 10:
		many.append("w%d+a+b" % k)
	assert_int(_v(_wins_with(many, ["pistol"], 100), "S11")).is_equal(PASS)  # ten signatures, 10% each
	var few: Array[String] = ["a", "b", "c", "d"]
	assert_int(_v(_wins_with(few, ["pistol"], 100), "S11")).is_equal(WARN)  # only four, a quarter each
	var lopsided: Array[String] = ["a", "a", "a", "b", "c", "d", "e", "f", "g", "h"]
	assert_int(_v(_wins_with(lopsided, ["pistol"], 100), "S11")).is_equal(WARN)  # "a" has 30%
	assert_int(_v(ScorecardTKit.batch("balanced", 0, 5), "S11")).is_equal(WARN)  # no wins


func test_s11_counts_the_wins_of_every_policy_but_not_the_extra_runs() -> void:
	var runs: Array[Dictionary] = _wins_with(["a", "b"], ["pistol"], 4)
	runs.append(ScorecardTKit.run("balanced", true, 9, {"variant": "hot", "signature": "z"}))
	var r: Dictionary = ScorecardTKit.row(_rows(runs), "S11")
	assert_str(ScorecardTKit.text(r, "measured")).contains("2 signatures in 4 wins")


func test_s12_no_weapon_above_thirty_percent_and_every_weapon_of_the_pool_at_three() -> void:
	var weapons: Array[String] = ["pistol", "smg", "arc_projector", "pistol", "smg", "arc_projector", "pistol", "smg", "arc_projector", "smg"]
	assert_int(_v(_wins_with(["s"], weapons, 100), "S12")).is_equal(WARN)  # smg has 40%
	var even: Array[String] = ["pistol", "smg", "arc_projector"]
	assert_int(_v(_wins_with(["s"], even, 99), "S12")).is_equal(WARN)  # a third each is above 30%
	var spread: Array[String] = ["pistol", "smg", "arc_projector", "rail_lance"]
	var ctx: Dictionary = ScorecardTKit.context()
	var rows: Array[Dictionary] = Scorecard.evaluate(_wins_with(["s"], spread, 100), ctx)
	assert_int(ScorecardTKit.verdict(rows, "S12")).is_equal(PASS)  # 25% each of four, all in the roster


func test_s12_names_the_weapons_below_three_percent() -> void:
	var weapons: Array[String] = ["pistol", "pistol", "pistol", "pistol", "pistol", "smg", "smg", "smg", "smg", "smg"]
	var r: Dictionary = ScorecardTKit.row(_rows(_wins_with(["s"], weapons, 100)), "S12")
	assert_str(ScorecardTKit.text(r, "measured")).contains("arc_projector")


func test_s13_compares_runs_that_held_a_directive_with_runs_that_passed_it_by() -> void:
	var runs: Array[Dictionary] = []
	for k: int in 10:
		runs.append(ScorecardTKit.run("balanced", k < 8, k + 1, {"held": ["hot_loads"]}))  # held: 8 of 10 win
		runs.append(ScorecardTKit.run("random", k < 4, k + 11, {"offered": ["hot_loads"]}))  # passed: 4 of 10
	var r: Dictionary = ScorecardTKit.row(_rows(runs), "S13")
	assert_float(ScorecardTKit.number(r, "value")).is_equal_approx(0.4, 0.0001)
	assert_int(ScorecardTKit.whole(r, "verdict")).is_equal(WARN)  # +40 points
	var even: Array[Dictionary] = []
	for k: int in 10:
		even.append(ScorecardTKit.run("balanced", k < 5, k + 1, {"held": ["hot_loads"]}))
		even.append(ScorecardTKit.run("random", k < 5, k + 11, {"offered": ["hot_loads"]}))
	assert_int(_v(even, "S13")).is_equal(PASS)


func test_s13_leaves_out_a_directive_with_too_few_runs_in_a_group() -> void:
	var runs: Array[Dictionary] = []
	for k: int in 5:
		runs.append(ScorecardTKit.run("balanced", true, k + 1, {"held": ["rare_card"]}))
		runs.append(ScorecardTKit.run("balanced", false, k + 6, {"offered": ["rare_card"]}))
	assert_int(_v(runs, "S13")).is_equal(WARN)
	assert_str(ScorecardTKit.text(ScorecardTKit.row(_rows(runs), "S13"), "measured")).contains("not measured")


# --- S14, S15: routes and pools ---


func test_s14_both_forced_routes_win_a_quarter_to_two_thirds_and_hot_banks_more_data() -> void:
	var runs: Array[Dictionary] = []
	runs.append_array(ScorecardTKit.batch("balanced", 5, 5, {"variant": "standard", "data": 100}))
	runs.append_array(ScorecardTKit.batch("balanced", 4, 6, {"variant": "hot", "data": 130}))
	assert_int(_v(runs, "S14")).is_equal(PASS)
	var poor_hot: Array[Dictionary] = []
	poor_hot.append_array(ScorecardTKit.batch("balanced", 5, 5, {"variant": "standard", "data": 100}))
	poor_hot.append_array(ScorecardTKit.batch("balanced", 4, 6, {"variant": "hot", "data": 90}))
	assert_int(_v(poor_hot, "S14")).is_equal(WARN)  # hot does not pay
	var deadly: Array[Dictionary] = []
	deadly.append_array(ScorecardTKit.batch("balanced", 5, 5, {"variant": "standard", "data": 100}))
	deadly.append_array(ScorecardTKit.batch("balanced", 2, 8, {"variant": "hot", "data": 130}))
	assert_int(_v(deadly, "S14")).is_equal(WARN)  # 20% is below 25%
	assert_int(_v(ScorecardTKit.batch("balanced", 5, 5), "S14")).is_equal(WARN)  # not played


func test_s15_the_two_pools_win_within_five_points_of_each_other() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 5, 5)  # base
	runs.append_array(ScorecardTKit.batch("balanced", 5, 5, {"variant": "other_pool", "pool": "full"}))
	assert_int(_v(runs, "S15")).is_equal(PASS)
	var apart: Array[Dictionary] = ScorecardTKit.batch("balanced", 5, 5)
	apart.append_array(ScorecardTKit.batch("balanced", 7, 3, {"variant": "other_pool", "pool": "full"}))
	assert_int(_v(apart, "S15")).is_equal(WARN)  # 20 points
	assert_int(_v(ScorecardTKit.batch("balanced", 5, 5), "S15")).is_equal(WARN)  # one pool only


# --- S16 to S18 ---


func test_s16_the_median_combat_time_of_wins_is_780_to_1020_seconds() -> void:
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 0, {"combat_s": 900.0}), "S16")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 0, {"combat_s": 779.0}), "S16")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 0, {"combat_s": 1021.0}), "S16")).is_equal(WARN)
	assert_int(_v(ScorecardTKit.batch("balanced", 0, 3), "S16")).is_equal(WARN)  # no win to time


func test_s17_a_cap_exceeded_is_a_break_and_a_peak_off_the_table_is_a_warning() -> void:
	var table: Dictionary = {"peak_bodied": [10, 16, 24, 30, 26], "peak_minis": [0, 8, 12, 16, 16]}
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 0, table), "S17")).is_equal(PASS)
	var high: Dictionary = {"peak_bodied": [10, 16, 24, 30, 26], "peak_minis": [0, 8, 12, 16, 16]}
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 3, 0, high)
	runs.append(ScorecardTKit.run("greedy", true, 1, {"peak_bodied": [51]}))
	assert_int(_v(runs, "S17")).is_equal(FAIL)  # more bodied than the cap of 50
	var blasts: Array[Dictionary] = ScorecardTKit.batch("balanced", 3, 0, {"max_blasts": 9, "peak_bodied": [10], "peak_minis": [0]})
	assert_int(_v(blasts, "S17")).is_equal(FAIL)  # more than 8 blasts in one tick
	var off: Dictionary = {"peak_bodied": [10, 16, 40, 30, 26], "peak_minis": [0, 8, 12, 16, 16]}
	assert_int(_v(ScorecardTKit.batch("balanced", 3, 0, off), "S17")).is_equal(WARN)  # wave 3: 40 against 24


func test_s17_only_the_runs_that_reached_a_wave_count_for_it() -> void:
	var early: Dictionary = {"peak_bodied": [10, 16, 0, 0, 0], "peak_minis": [0, 8, 0, 0, 0], "death_wave": 2}
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 0, 3, early)
	assert_int(_v(runs, "S17")).is_equal(PASS)  # waves 3 to 5 were never played: no verdict on them
	var r: Dictionary = ScorecardTKit.row(_rows(runs), "S17")
	var detail: PackedStringArray = r["detail"]
	assert_int(detail.size()).is_equal(2)  # one detail line per wave that was reached


func test_s18_the_greedy_player_loses_at_most_sixty_percent_in_one_act_one_wave() -> void:
	assert_int(_v(ScorecardTKit.batch("greedy", 0, 3, {"core_loss": [0.2, 0.6, 0.1, 0.1, 0.1]}), "S18")).is_equal(PASS)
	assert_int(_v(ScorecardTKit.batch("greedy", 0, 3, {"core_loss": [0.2, 0.61, 0.1, 0.1, 0.1]}), "S18")).is_equal(WARN)
	var late: Dictionary = {"core_loss": [0.1, 0.1, 0.1, 0.1, 0.1, 0.9]}  # wave 6 is act II
	assert_int(_v(ScorecardTKit.batch("greedy", 0, 3, late), "S18")).is_equal(PASS)
	assert_int(_v([], "S18")).is_equal(WARN)


# --- integrity and the summary line ---


func test_an_unfinished_or_unclean_run_is_a_structural_break() -> void:
	var runs: Array[Dictionary] = ScorecardTKit.batch("balanced", 2, 2)
	assert_int(_v(runs, "integrity")).is_equal(PASS)
	runs.append(ScorecardTKit.run("balanced", false, 9, {"result": "unfinished"}))
	assert_int(_v(runs, "integrity")).is_equal(FAIL)
	var stalled: Array[Dictionary] = ScorecardTKit.batch("balanced", 2, 2)
	stalled.append(ScorecardTKit.run("greedy", true, 9, {"clean": false}))
	assert_int(_v(stalled, "integrity")).is_equal(FAIL)


func test_the_card_has_nineteen_rows_and_a_summary_line_in_the_documented_shape() -> void:
	var rows: Array[Dictionary] = _rows(ScorecardTKit.batch("balanced", 5, 5))
	assert_int(rows.size()).is_equal(19)  # integrity and S1 to S18
	assert_str(ScorecardTKit.text(rows[0], "id")).is_equal("integrity")
	assert_str(ScorecardTKit.text(rows[18], "id")).is_equal("S18")
	var line: String = Scorecard.summary_line(rows, 10)
	var shape: RegEx = RegEx.create_from_string("^SCORECARD: (PASS|WARN|FAIL) rows=19 pass=\\d+ warn=\\d+ fail=\\d+ runs=10$")
	assert_object(shape.search(line)).is_not_null()
	assert_int(Scorecard.count(rows, PASS) + Scorecard.count(rows, WARN) + Scorecard.count(rows, FAIL)).is_equal(19)


func test_the_worst_verdict_decides_the_summary() -> void:
	var rows: Array[Dictionary] = [
		Scorecard.row("a", "", 0.0, "", "", PASS), Scorecard.row("b", "", 0.0, "", "", WARN),
	]
	assert_int(Scorecard.worst(rows)).is_equal(WARN)
	assert_str(Scorecard.summary_line(rows, 3)).is_equal("SCORECARD: WARN rows=2 pass=1 warn=1 fail=0 runs=3")
	rows.append(Scorecard.row("c", "", 0.0, "", "", FAIL))
	assert_str(Scorecard.summary_line(rows, 3)).starts_with("SCORECARD: FAIL ")
	assert_int(Scorecard.worst([] as Array[Dictionary])).is_equal(PASS)
