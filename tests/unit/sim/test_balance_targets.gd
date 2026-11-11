extends GdUnitTestSuite
## BalanceTargets (GDD 8.4 as rows) on hand-made HarnessReports: the PASS / WARN / FAIL boundaries.


func _report(policy: int, result: int, wave: int, secs: float, core: float, peaks: Array[int]) -> HarnessReport:
	var r: HarnessReport = HarnessReport.new()
	r.policy = policy
	r.result = result
	r.wave_reached = wave
	r.ticks = roundi(secs * 60.0)
	r.core_hp = core
	r.core_max_hp = 1000.0
	for w: int in 5:
		r.peak_alive[w] = peaks[w]
	return r


func _good_greedy(n: int) -> Array[HarnessReport]:
	var out: Array[HarnessReport] = []
	for k: int in n:
		out.append(_report(PolicyBot.Policy.GREEDY, RunResult.Id.VICTORY, 5, 310.0, 550.0, [10, 18, 28, 40, 50]))
	return out


func _good_none(n: int) -> Array[HarnessReport]:
	var out: Array[HarnessReport] = []
	for k: int in n:
		out.append(_report(PolicyBot.Policy.NONE, RunResult.Id.DEFEAT, 3 + (k % 2), 150.0, 0.0, [10, 20, 30, 0, 0]))
	return out


func _row(rows: Array[Dictionary], id: String) -> Dictionary:
	for r: Dictionary in rows:
		if r["id"] == id:
			return r
	return {}


func _status(rows: Array[Dictionary], id: String) -> int:
	var row: Dictionary = _row(rows, id)
	var s: int = row["status"]
	return s


func test_runs_that_meet_every_target_pass() -> void:
	var rows: Array[Dictionary] = BalanceTargets.evaluate(_good_none(4), _good_greedy(4))
	assert_int(rows.size()).is_equal(10)
	assert_int(BalanceTargets.worst(rows)).is_equal(BalanceTargets.Status.PASS)
	assert_int(BalanceTargets.count(rows, BalanceTargets.Status.PASS)).is_equal(10)


func test_a_no_buy_run_that_wins_fails() -> void:
	var none_runs: Array[HarnessReport] = _good_none(3)
	none_runs[1].result = RunResult.Id.VICTORY
	var rows: Array[Dictionary] = BalanceTargets.evaluate(none_runs, _good_greedy(3))
	assert_int(_status(rows, "none_loses")).is_equal(BalanceTargets.Status.FAIL)
	assert_int(BalanceTargets.worst(rows)).is_equal(BalanceTargets.Status.FAIL)


func test_a_no_buy_run_that_dies_in_wave_two_or_five_only_warns() -> void:
	var none_runs: Array[HarnessReport] = _good_none(4)
	none_runs[0].wave_reached = 2
	none_runs[1].wave_reached = 5
	var rows: Array[Dictionary] = BalanceTargets.evaluate(none_runs, _good_greedy(4))
	assert_int(_status(rows, "none_loses")).is_equal(BalanceTargets.Status.WARN)


func test_greedy_win_rate_bands() -> void:
	var runs: Array[HarnessReport] = _good_greedy(10)
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "greedy_wins")).is_equal(BalanceTargets.Status.PASS)
	runs[0].result = RunResult.Id.DEFEAT  # 90%
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "greedy_wins")).is_equal(BalanceTargets.Status.PASS)
	runs[1].result = RunResult.Id.DEFEAT  # 80%
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "greedy_wins")).is_equal(BalanceTargets.Status.WARN)
	for k: int in 4:
		runs[2 + k].result = RunResult.Id.DEFEAT  # 40%
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "greedy_wins")).is_equal(BalanceTargets.Status.FAIL)


func test_core_and_duration_are_measured_on_victories_and_only_warn() -> void:
	var runs: Array[HarnessReport] = _good_greedy(4)
	for r: HarnessReport in runs:
		r.core_hp = 900.0
		r.ticks = 245 * 60
	var rows: Array[Dictionary] = BalanceTargets.evaluate(_good_none(4), runs)
	assert_int(_status(rows, "greedy_core")).is_equal(BalanceTargets.Status.WARN)
	assert_int(_status(rows, "duration")).is_equal(BalanceTargets.Status.WARN)
	assert_str(_row(rows, "duration")["measured"]).contains("245")
	assert_int(BalanceTargets.worst(rows)).is_equal(BalanceTargets.Status.WARN)


func test_core_and_duration_band_edges_are_inclusive() -> void:
	var runs: Array[HarnessReport] = _good_greedy(2)
	runs[0].ticks = 270 * 60
	runs[1].ticks = 270 * 60
	runs[0].core_hp = 800.0
	runs[1].core_hp = 800.0
	var rows: Array[Dictionary] = BalanceTargets.evaluate(_good_none(2), runs)
	assert_int(_status(rows, "duration")).is_equal(BalanceTargets.Status.PASS)
	assert_int(_status(rows, "greedy_core")).is_equal(BalanceTargets.Status.PASS)
	runs[0].ticks = 361 * 60
	runs[1].ticks = 361 * 60
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "duration")).is_equal(BalanceTargets.Status.WARN)


func test_peaks_use_the_median_and_a_20_percent_band() -> void:
	var runs: Array[HarnessReport] = _good_greedy(5)
	for r: HarnessReport in runs:
		r.peak_alive[0] = 8  # 10 * 0.8, inside
		r.peak_alive[1] = 22  # 18 * 1.2 = 21.6, outside
	runs[0].peak_alive[1] = 18  # one run on target does not move the median
	var rows: Array[Dictionary] = BalanceTargets.evaluate(_good_none(2), runs)
	assert_int(_status(rows, "peak_wave_1")).is_equal(BalanceTargets.Status.PASS)
	assert_int(_status(rows, "peak_wave_2")).is_equal(BalanceTargets.Status.WARN)
	assert_int(_status(rows, "peak_wave_3")).is_equal(BalanceTargets.Status.PASS)


func test_an_unfinished_run_or_a_violation_fails_the_integrity_row() -> void:
	var runs: Array[HarnessReport] = _good_greedy(2)
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "integrity")).is_equal(BalanceTargets.Status.PASS)
	runs[1].violations.append("t5: something broke")
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "integrity")).is_equal(BalanceTargets.Status.FAIL)
	runs[1].violations.clear()
	runs[0].timed_out = true
	assert_int(_status(BalanceTargets.evaluate(_good_none(2), runs), "integrity")).is_equal(BalanceTargets.Status.FAIL)


func test_median_mean_min_max() -> void:
	var v: PackedFloat64Array = PackedFloat64Array([5.0, 1.0, 9.0, 3.0])
	assert_float(BalanceTargets.median(v)).is_equal(4.0)
	assert_float(BalanceTargets.median(PackedFloat64Array([2.0, 7.0, 4.0]))).is_equal(4.0)
	assert_float(BalanceTargets.mean(v)).is_equal(4.5)
	assert_float(BalanceTargets.min_of(v)).is_equal(1.0)
	assert_float(BalanceTargets.max_of(v)).is_equal(9.0)
	assert_float(BalanceTargets.median(PackedFloat64Array())).is_equal(0.0)
	assert_float(BalanceTargets.min_of(PackedFloat64Array())).is_equal(0.0)


func test_status_names() -> void:
	assert_str(BalanceTargets.status_name(BalanceTargets.Status.PASS)).is_equal("PASS")
	assert_str(BalanceTargets.status_name(BalanceTargets.Status.WARN)).is_equal("WARN")
	assert_str(BalanceTargets.status_name(BalanceTargets.Status.FAIL)).is_equal("FAIL")
