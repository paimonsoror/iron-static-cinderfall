extends GdUnitTestSuite
## V5-A: an elite the Warden could never shoot is never planned. SHROUDED hides an enemy from a shooter farther than
## 12 m; a spitter or a reclaimer parks at its standoff point, about 14 m from the Warden, for good. The 15-wave
## integration met such a spitter in wave 14 of seed 3: nothing but a turret in reach, an area weapon or a strike could
## kill it, so a run without those never ended its wave. PlanElites does not roll SHROUDED on a standoff enemy.


func test_no_plan_puts_a_shroud_on_an_enemy_that_parks_at_a_standoff_point() -> void:
	var c: ContentSet = TestContent.variety()
	var shroud: int = 1 << c.affix_index(&"aff_shroud")
	var elites: int = 0
	var shrouded: int = 0
	var standoff_elites: int = 0
	for run_seed: int in range(1, 61):
		var plan: RunPlan = RunPlanSystem.build_for(c, run_seed)
		for wave_number: int in range(1, plan.wave_count() + 1):
			for option: RouteOption in plan.wave(wave_number).options:
				for e: PlannedElite in option.elites:
					var def: EnemyDef = c.enemies[option.groups[e.group].enemy_index]
					elites += 1
					shrouded += 1 if (e.affix_mask & shroud) != 0 else 0
					if def.standoff_m > 0.0:
						standoff_elites += 1
						assert_int(e.affix_mask & shroud).override_failure_message(
							"seed %d wave %d: a shrouded %s" % [run_seed, wave_number, def.id]
						).is_equal(0)
	assert_int(elites).is_greater(500)
	assert_int(shrouded).is_greater(20)  # the affix is still in the game, on the enemies that come to the cage
	assert_int(standoff_elites).is_greater(20)  # and standoff enemies are still elites, with other affixes


func test_the_affix_roll_of_a_standoff_enemy_never_gives_the_shroud() -> void:
	var c: ContentSet = TestContent.variety()
	var shroud: int = 1 << c.affix_index(&"aff_shroud")
	var seen_on_skitter: bool = false
	for n: int in 400:
		var stream: RandomNumberGenerator = PlanRng.stream(n, &"plan.elite:13")
		assert_int(PlanElites.roll_affixes(c, Ids.EN_SPITTER, 3, stream) & shroud).is_equal(0)
		assert_int(PlanElites.roll_affixes(c, Ids.EN_RECLAIMER, 3, stream) & shroud).is_equal(0)
		seen_on_skitter = seen_on_skitter or (PlanElites.roll_affixes(c, Ids.EN_SKITTER, 3, stream) & shroud) != 0
	assert_bool(seen_on_skitter).is_true()
