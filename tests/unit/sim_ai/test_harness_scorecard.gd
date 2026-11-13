extends GdUnitTestSuite
## V4-T: what a whole run hands the scorecard (HarnessCensus and the new HarnessReport fields, ScorecardRecord.of), the
## wave arrays that follow the length of the run, and the redefined targets of balance_run (BalanceTargets.evaluate_variety).


func _report(policy: int, run_seed: int) -> HarnessReport:
	return SimHarness.run(SimConfig.create(VarietyHKit.content(), run_seed), policy)


func test_a_whole_run_fills_the_scorecard_fields_of_the_report() -> void:
	var r: HarnessReport = _report(PolicyBot.Policy.BALANCED, 2)
	var waves: int = PhaseSystem.wave_count(r.world)
	assert_int(r.wave_total).is_equal(waves)
	assert_int(r.peak_alive.size()).is_equal(maxi(5, waves))
	assert_int(r.core_lost.size()).is_equal(maxi(5, waves))
	assert_int(r.peak_bodied.size()).is_equal(waves + 1)
	assert_int(r.peak_minis.size()).is_equal(waves + 1)
	assert_int(r.act_end_core.size()).is_equal(r.act_total)
	assert_int(r.held.size()).is_equal(r.world.content.directives.size())
	assert_bool(r.combat_ticks > 0 and r.combat_ticks <= r.ticks).is_true()
	assert_int(r.primary_weapon).is_between(0, r.world.content.weapons.size() - 1)
	assert_bool(r.weapons_carried.has(0)).is_true()  # the pistol
	assert_bool(r.data >= 0).is_true()
	var most: int = 0
	for n: int in r.peak_bodied:
		most = maxi(most, n)
	assert_bool(most > 0).is_true()  # the census counted the bodied enemies of the run


func test_the_census_saw_every_card_the_bot_picked() -> void:
	var r: HarnessReport = _report(PolicyBot.Policy.BALANCED, 3)
	assert_bool(r.offered.size() > 0).is_true()
	for index: int in r.held.size():
		if r.held[index] > 0:
			assert_bool(r.offered.has(index)).is_true()  # nothing is held that was never on offer (the kit grants none here)


func test_the_act_end_core_is_set_when_the_last_wave_of_an_act_is_cleared() -> void:
	var r: HarnessReport = _report(PolicyBot.Policy.BALANCED, 2)
	if r.is_victory():
		assert_float(r.act_end_core[0]).is_between(0.0, 1.0)
	else:
		assert_float(r.act_end_core[0]).is_equal(-1.0)  # it fell before the boss wave that ends act I was cleared
	var lost: HarnessReport = _report(PolicyBot.Policy.NONE, 2)
	assert_float(lost.act_end_core[0]).is_equal(-1.0)


func test_a_defeat_names_its_act_and_a_win_names_none() -> void:
	var lost: HarnessReport = _report(PolicyBot.Policy.NONE, 1)
	assert_int(lost.death_wave).is_greater(0)
	assert_int(lost.death_act).is_equal(1)
	var rec: Dictionary = ScorecardRecord.of(lost, lost.world.content, "base", "")
	assert_str(ScorecardRecord.text(rec, "result")).is_equal("defeat")
	assert_int(ScorecardRecord.whole(rec, "death_act")).is_equal(1)
	assert_str(ScorecardRecord.text(rec, "policy")).is_equal("none")


func test_a_record_of_a_run_is_complete_and_survives_json() -> void:
	var r: HarnessReport = _report(PolicyBot.Policy.GREEDY, 1)
	var rec: Dictionary = ScorecardRecord.of(r, r.world.content, "full", "hot")
	var back: Dictionary = ScorecardRecord.from_line(ScorecardRecord.to_line(rec))
	for key: String in ["policy", "variant", "pool", "result", "signature", "primary"]:
		assert_str(ScorecardRecord.text(back, key)).is_equal(ScorecardRecord.text(rec, key))
	assert_str(ScorecardRecord.text(back, "variant")).is_equal("hot")
	assert_int(ScorecardRecord.whole(back, "seed")).is_equal(1)
	assert_int(ScorecardRecord.floats(back, "core_loss").size()).is_equal(r.wave_total)
	assert_int(ScorecardRecord.floats(back, "peak_bodied").size()).is_equal(r.wave_total)
	assert_bool(ScorecardRecord.flag(back, "clean")).is_true()
	assert_float(ScorecardRecord.num(back, "combat_s")).is_equal_approx(float(r.combat_ticks) / 60.0, 0.001)


func test_the_wave_arrays_of_a_legacy_run_keep_their_five_slots() -> void:
	var r: HarnessReport = SimHarness.run(SimConfig.create(TestContent.baseline(), 1), PolicyBot.Policy.NONE)
	assert_int(r.wave_total).is_equal(5)
	assert_int(r.peak_alive.size()).is_equal(5)
	assert_int(r.core_lost.size()).is_equal(5)
	assert_int(r.act_total).is_equal(1)
	assert_int(r.death_act).is_equal(0)  # no plan, no act


func test_the_checker_follows_the_length_of_the_run() -> void:
	var w: SimWorld = VarietyHKit.world()
	var chk: HarnessChecker = HarnessChecker.new(w)
	assert_int(chk.core_lost_by_wave.size()).is_equal(maxi(6, PhaseSystem.wave_count(w) + 1))
	var legacy: HarnessChecker = HarnessChecker.new(TestContent.world())
	assert_int(legacy.core_lost_by_wave.size()).is_equal(6)


# --- balance_run on variety content ---


func _records(none_wins: int, greedy_wins: int, balanced_wins: int, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(ScorecardTKit.batch("none", none_wins, count - none_wins))
	out.append_array(ScorecardTKit.batch("greedy", greedy_wins, count - greedy_wins))
	out.append_array(ScorecardTKit.batch("balanced", balanced_wins, count - balanced_wins))
	return out


func _status(rows: Array[Dictionary], id: String) -> int:
	for row: Dictionary in rows:
		if row["id"] == id:
			var s: int = row["status"]
			return s
	return -1


func test_balance_rows_on_variety_content_are_the_redefined_targets() -> void:
	var rows: Array[Dictionary] = BalanceTargets.evaluate_variety(_records(0, 2, 5, 10), ScorecardTKit.context())
	var ids: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		ids.append(ScorecardTKit.text(row, "id"))
	assert_array(Array(ids)).is_equal(["integrity", "none_loses", "greedy_wins", "balanced_wins", "balanced_core", "duration", "chaos_budget"])
	assert_int(_status(rows, "none_loses")).is_equal(BalanceTargets.Status.PASS)
	assert_int(_status(rows, "greedy_wins")).is_equal(BalanceTargets.Status.PASS)  # 20%
	assert_int(_status(rows, "balanced_wins")).is_equal(BalanceTargets.Status.PASS)  # 50%
	assert_int(_status(rows, "balanced_core")).is_equal(BalanceTargets.Status.PASS)  # 50% left
	assert_int(_status(rows, "duration")).is_equal(BalanceTargets.Status.PASS)  # 900 s


func test_balance_rows_warn_outside_the_bands_and_fail_on_a_structural_break() -> void:
	var rows: Array[Dictionary] = BalanceTargets.evaluate_variety(_records(0, 9, 9, 10), ScorecardTKit.context())
	assert_int(_status(rows, "greedy_wins")).is_equal(BalanceTargets.Status.WARN)
	assert_int(_status(rows, "balanced_wins")).is_equal(BalanceTargets.Status.WARN)
	assert_int(BalanceTargets.worst(rows)).is_equal(BalanceTargets.Status.WARN)
	var broken: Array[Dictionary] = BalanceTargets.evaluate_variety(_records(1, 2, 5, 10), ScorecardTKit.context())
	assert_int(_status(broken, "none_loses")).is_equal(BalanceTargets.Status.FAIL)
	assert_int(BalanceTargets.worst(broken)).is_equal(BalanceTargets.Status.FAIL)


func test_the_legacy_rows_are_unchanged() -> void:
	var none: Array[HarnessReport] = []
	var greedy: Array[HarnessReport] = []
	assert_int(BalanceTargets.evaluate(none, greedy).size()).is_equal(10)
