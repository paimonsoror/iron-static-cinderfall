extends GdUnitTestSuite
## V2-D: 100 kill-and-resume cycles in memory (WORK_PLAN V2-D). One run is killed a hundred times, by a pause, by the
## app going to the background and by a crash with no notice at all, and resumed from the run file each time. It
## must end exactly as the same run played without a single interruption: same state hash, same event hash, same
## summary, and its Recovered Data granted once.
##
## The player of VarietyDKit decides from the sim state only, so after a crash (which gives back the ticks since the
## last write) it makes the same choices again and the run converges on the uninterrupted one.


func before_test() -> void:
	GameRunKit.fresh_save()


func after_test() -> void:
	GameRunKit.reset_save()


## One kill and one resume. `i` picks the kind of kill: a pause, the app going to the background, or a crash.
func _cycle(rc: RunController, content: ContentSet, shell: MobileShell, i: int, by_kind: Array[int]) -> RunController:
	assert_bool(rc.sim.is_over()).override_failure_message("the run ended before cycle %d" % i).is_false()
	var kind: int = 0
	match i % 6:
		4:
			kind = 2  # a crash: no notice, nothing written
		2:
			kind = 1  # the app goes to the background
			shell.on_app_paused()
		_:
			rc.set_paused(true)
	by_kind[kind] += 1
	var expect_tick: int = RunFile.target_tick(VarietyDKit.doc())
	if kind != 2:
		assert_int(expect_tick).is_equal(rc.sim.tick)  # a noticed kill loses nothing
	VarietyDKit.kill(rc)
	var back: RunController = VarietyDKit.resumed(self, content)
	assert_object(back.sim).override_failure_message("cycle %d: the run did not come back" % i).is_not_null()
	assert_int(back.resume_mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_int(back.sim.tick).is_equal(expect_tick)
	assert_str(back.run_id).is_equal("cycle-run")
	return back


## Half of the kills come in the first seconds of the run (the preparation and the start of wave 1), the other half
## right after the first wave clear (the purchases of the intermission, CONTINUE, the start of wave 2). The kills are
## a few frames apart, so the tails that are replayed stay short and a hundred resumes fit in a unit test.
func _assert_cycles(content_maker: Callable, run_seed: int, cycles: int) -> void:
	var ref_content: ContentSet = content_maker.call()
	var reference: RunController = GameRunKit.controller(self, VarietyDKit.config(ref_content, run_seed, 2), null, "ref-run")
	assert_int(VarietyDKit.play_to_end(reference, 60000)).is_greater(0)
	var want_hash: String = reference.sim.state_hash()
	var want_events: int = reference.sim.events.event_hash
	var want_ticks: int = reference.sim.tick
	var want: RunSummary = reference.summary
	VarietyDKit.kill(reference)
	GameRunKit.fresh_save()

	var content: ContentSet = content_maker.call()
	var rc: RunController = GameRunKit.controller(self, VarietyDKit.config(content, run_seed, 2), null, "cycle-run")
	var shell: MobileShell = MobileShell.new()
	auto_free(shell)
	add_child(shell)
	var by_kind: Array[int] = [0, 0, 0]
	var first_half: int = floori(float(cycles) / 2.0)
	for i: int in first_half:
		VarietyDKit.play(rc, 5 + (i * 7) % 9)
		rc = _cycle(rc, content, shell, i, by_kind)
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 30000)).is_greater(0)
	for i: int in range(first_half, cycles):
		VarietyDKit.play(rc, 3 + (i * 5) % 8)
		rc = _cycle(rc, content, shell, i, by_kind)
	assert_int(by_kind[0] + by_kind[1] + by_kind[2]).is_equal(cycles)
	assert_int(by_kind[1]).is_greater(0)
	assert_int(by_kind[2]).is_greater(0)
	assert_int(rc.sim.wave).is_equal(2)  # the second half went through the intermission into wave 2
	assert_int(Save.profile.runs_played).is_equal(0)  # all those resumes and nothing was paid yet

	assert_int(VarietyDKit.play_to_end(rc, 60000)).is_greater(0)
	assert_str(rc.sim.state_hash()).is_equal(want_hash)
	assert_int(rc.sim.events.event_hash).is_equal(want_events)
	assert_int(rc.sim.tick).is_equal(want_ticks)
	assert_int(rc.summary.result).is_equal(want.result)
	assert_int(rc.summary.data_reward).is_equal(want.data_reward)
	assert_array(Array(rc.summary.kills_by_type)).is_equal(Array(want.kills_by_type))
	assert_array(Array(rc.summary.peak_alive_by_wave)).is_equal(Array(want.peak_alive_by_wave))
	assert_int(rc.summary.scrap_earned).is_equal(want.scrap_earned)
	assert_int(rc.summary.scrap_spent).is_equal(want.scrap_spent)
	assert_int(rc.summary.combat_ticks).is_equal(want.combat_ticks)
	assert_bool(rc.reward_granted).is_true()
	assert_int(Save.profile.data).is_equal(want.data_reward)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(1)
	assert_dict(VarietyDKit.doc()).is_empty()


func test_100_kill_and_resume_cycles_end_like_the_uninterrupted_run() -> void:
	_assert_cycles(TestContent.baseline, 11, 100)


func test_20_kill_and_resume_cycles_on_the_variety_content() -> void:
	_assert_cycles(TestContent.variety, 12, 20)
