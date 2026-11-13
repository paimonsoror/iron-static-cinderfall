extends GdUnitTestSuite
## V4-V (B07, rule 8): "a run can always be lost and never be lost from full: no single wave of act I can remove more than
## 60% of a full core from a player who takes any directive each draft and uses each ability once". The greedy bot plays
## whole slice runs on the frozen fixture with every event of the plan; the largest core loss of waves 1 to 4 is measured.
## The boss wave (the Siege Hulk of the slice, task V4-L and the balance task V5-C) is not an event matter and is left out.

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6]
const LIMIT: float = 0.6


func test_no_single_wave_before_the_boss_costs_a_full_core_more_than_sixty_percent() -> void:
	var worst: float = 0.0
	var events_seen: int = 0
	for s: int in SEEDS:
		var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), s), PolicyBot.Policy.GREEDY)
		for wave: int in 4:
			var lost: float = report.core_lost[wave] / report.core_max_hp
			worst = maxf(worst, lost)
			assert_float(lost).override_failure_message("seed %d wave %d lost %.2f" % [s, wave + 1, lost]).is_less_equal(LIMIT)
		for count: int in report.world.stats.events_seen:
			events_seen += count
		assert_int(report.violations.size()).override_failure_message("seed %d: %s" % [s, "; ".join(report.violations)]).is_equal(0)
	assert_int(events_seen).is_greater(0)  # the runs did meet events
	assert_float(worst).is_greater(-1.0)
