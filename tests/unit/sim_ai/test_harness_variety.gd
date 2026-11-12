extends GdUnitTestSuite
## V2-H: the harness around the bots: the policy names sim_run accepts, the death wave and build signature of a
## report, the stall guard for a choice nobody answers, and the checker on a generated plan (where the core is
## repaired, Scrap is spent on drafts and minis spawn outside the schedule).


## Opens a draft at tick 5 and never answers it.
class SilentBot extends PolicyBot:
	func _init() -> void:
		super(PolicyBot.Policy.NONE)

	func act(world: SimWorld) -> void:
		if world.tick >= 5:
			world.phase_state.awaiting = PhaseState.Await.DRAFT


## Keeps a draft open and keeps sending a command that does not close it.
class RefusedBot extends PolicyBot:
	func _init() -> void:
		super(PolicyBot.Policy.NONE)

	func act(world: SimWorld) -> void:
		if world.tick >= 5:
			world.phase_state.awaiting = PhaseState.Await.DRAFT
			send(world, SimCommand.Kind.PATCH_CORE, 0)


func _has(chk: HarnessChecker, text: String) -> bool:
	for v: String in chk.violations:
		if v.contains(text):
			return true
	return false


# --- the policy names ---


func test_sim_run_takes_every_policy_by_name() -> void:
	for policy: int in PolicyBot.Policy.values():
		var name_of_policy: String = PolicyBot.name_of(policy)
		var a: HarnessArgs = HarnessArgs.parse(PackedStringArray(["--policy", name_of_policy]), "greedy", true)
		assert_str(a.error).is_empty()
		assert_array(a.policies()).is_equal([policy])
		assert_str(HarnessArgs.policy_name(policy)).is_equal(name_of_policy)


func test_balance_run_still_takes_only_none_greedy_and_both() -> void:
	for word: String in ["random", "balanced", "hoarder", "risk"]:
		assert_str(HarnessArgs.parse(PackedStringArray(["--policy", word])).error).is_not_empty()
	assert_str(HarnessArgs.parse(PackedStringArray(["--policy", "both"])).error).is_empty()


func test_an_unknown_policy_is_an_error_that_lists_the_names() -> void:
	var a: HarnessArgs = HarnessArgs.parse(PackedStringArray(["--policy", "genius"]), "greedy", true)
	assert_str(a.error).contains("balanced")
	assert_str(a.error).contains("genius")
	assert_array(HarnessArgs.parse(PackedStringArray(["--policy", "both"]), "greedy", true).policies()).is_equal(
		[PolicyBot.Policy.NONE, PolicyBot.Policy.GREEDY]
	)


func test_policy_names_round_trip() -> void:
	assert_int(PolicyBot.NAMES.size()).is_equal(PolicyBot.Policy.size())
	for policy: int in PolicyBot.Policy.values():
		assert_int(PolicyBot.policy_from_name(PolicyBot.name_of(policy))).is_equal(policy)
	assert_int(PolicyBot.policy_from_name("nobody")).is_equal(-1)
	assert_str(PolicyBot.name_of(99)).is_equal("unknown")


# --- the report ---


func test_a_balanced_run_on_variety_content_ends_cleanly_with_a_signature() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 2), PolicyBot.Policy.BALANCED)
	assert_bool(report.stalled).is_false()
	assert_bool(report.timed_out).is_false()
	assert_array(report.violations).is_empty()
	assert_bool(Ids.WEAPONS.has(StringName(report.signature.split("+")[0]))).is_true()  # a weapon id leads
	assert_int(report.damage_by_weapon.size()).is_equal(Ids.WEAPONS.size())
	if report.result == RunResult.Id.DEFEAT:
		assert_int(report.death_wave).is_greater(0)
	else:
		assert_int(report.death_wave).is_equal(0)


func test_the_death_wave_is_the_wave_of_the_defeat() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 1), PolicyBot.Policy.NONE)
	assert_str(report.result_name()).is_equal("DEFEAT")
	assert_int(report.death_wave).is_equal(report.wave_reached)


# --- the stall guard ---


func test_a_choice_nobody_answers_ends_the_run_as_stalled_instead_of_hanging() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 1), PolicyBot.Policy.NONE, 60000, SilentBot.new())
	assert_bool(report.stalled).is_true()
	assert_int(report.stalled_on).is_equal(PhaseState.Await.DRAFT)
	assert_bool(report.timed_out).is_true()
	assert_int(report.ticks).is_less(60)


func test_a_choice_that_stays_open_after_400_answers_is_a_stall_too() -> void:
	var report: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 1), PolicyBot.Policy.NONE, 60000, RefusedBot.new())
	assert_bool(report.stalled).is_true()
	assert_int(report.ticks).is_less(SimHarness.MAX_AWAIT_CALLS + 60)


# --- the checker on a generated plan ---


func test_a_generated_plan_may_repair_the_core_and_spend_scrap_on_drafts() -> void:
	var w: SimWorld = VarietyHKit.world()
	w.plan.boss_ids = PackedInt32Array([Ids.EN_HULK, Ids.EN_HULK, Ids.EN_HULK])  # a plan with bosses is not the stub
	var chk: HarnessChecker = HarnessChecker.new(w)
	w.set_core_hp(w.core_max_hp - 100.0)
	chk.after_step(w, [])
	w.set_core_hp(w.core_max_hp)
	chk.after_step(w, [])
	w.add_scrap(500)
	w.add_scrap(-260)
	chk.finish(w, 0)
	assert_array(chk.violations).is_empty()


func test_the_scripted_waves_keep_every_invariant() -> void:
	var w: SimWorld = VarietyHKit.world()  # the V1-S stub plan has no bosses: scripted
	var chk: HarnessChecker = HarnessChecker.new(w)
	w.set_core_hp(w.core_max_hp - 100.0)
	chk.after_step(w, [])
	w.set_core_hp(w.core_max_hp)
	chk.after_step(w, [])
	w.add_scrap(500)
	chk.finish(w, 0)
	assert_bool(_has(chk, "core healed")).is_true()
	assert_bool(_has(chk, "Scrap earned 500 != sum of kill rewards 0")).is_true()


func test_a_generated_victory_needs_every_planned_wave_cleared_and_nothing_alive() -> void:
	var w: SimWorld = VarietyHKit.world()
	w.plan.boss_ids = PackedInt32Array([Ids.EN_HULK])
	w.phase = GameState.Id.VICTORY
	var finish: SimEvent = SimEvent.new()
	finish.kind = SimEventKind.Id.RUN_FINISHED
	var chk: HarnessChecker = HarnessChecker.new(w)
	chk.after_step(w, [finish])
	w.waves_completed = w.plan.wave_count() - 1
	chk.finish(w, 0)
	assert_bool(_has(chk, "VICTORY with")).is_true()
	var ok: HarnessChecker = HarnessChecker.new(w)
	w.waves_completed = w.plan.wave_count()
	ok.after_step(w, [finish])
	ok.finish(w, 0)
	assert_array(ok.violations).is_empty()


func test_minis_beyond_the_bodied_cap_fit_under_the_variety_cap() -> void:
	var w: SimWorld = VarietyHKit.world()
	for k: int in w.content.mission.enemy_cap + 10:
		w.spawn_enemy(Ids.EN_SKITTER if k < w.content.mission.enemy_cap else Ids.EN_MOTE, 5.0, 0.0)
	var chk: HarnessChecker = HarnessChecker.new(w)
	chk.after_step(w, [])
	assert_bool(_has(chk, "enemies alive")).is_false()
