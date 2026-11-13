extends GdUnitTestSuite
## V4-V (B07, rule 8): "a run can always be lost and never be lost from full: no single wave of act I can remove more than
## 60% of a full core from a player who takes any directive each draft and uses each ability once". The balanced bot plays
## whole slice runs on the frozen fixture with every event of the plan (the greedy bot loses 81% of the core in wave 3 of
## seed 6 on the merged content with or without events: that is the balance question of scorecard S18, V5-C). What this suite can say is what the events add: the
## waves that hold an event (waves 3 and 4 of the slice) must not cost more than 60% of the core maximum, and the runs must
## really meet events. The whole-run property of the rule (every wave, a full core at its start) belongs to the scorecard
## row S18 (V4-T, V5-C): the waves without events (1, 2) and the boss wave (the Siege Hulk of the slice, V4-L) are balance,
## not events, and are left out here.

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6]
const LIMIT: float = 0.6


func test_no_wave_with_an_event_costs_more_than_sixty_percent_of_the_core() -> void:
	var events_seen: int = 0
	var waves_checked: int = 0
	for s: int in SEEDS:
		var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), s), PolicyBot.Policy.BALANCED)
		for wave: int in range(1, 5):
			if report.world.plan.wave(wave).events.is_empty() or wave > report.wave_reached:
				continue
			waves_checked += 1
			var lost: float = report.core_lost[wave - 1] / report.core_max_hp
			assert_float(lost).override_failure_message("seed %d wave %d lost %.2f" % [s, wave, lost]).is_less_equal(LIMIT)
		for count: int in report.world.stats.events_seen:
			events_seen += count
		assert_int(report.violations.size()).override_failure_message("seed %d: %s" % [s, "; ".join(report.violations)]).is_equal(0)
	assert_int(waves_checked).is_greater(0)
	assert_int(events_seen).is_greater(0)  # the runs did meet events
