extends GdUnitTestSuite
## V2-A: acts, whole runs and determinism of the generated run (VARIETY_SPEC 2.1, 2.5, 9.6), and that the legacy 5-wave
## fixture is untouched.


func _count(w: SimWorld, kind: int) -> int:
	return VarietyAKit.events_of(w, kind).size()


func test_a_slice_run_ends_in_victory_after_the_fifth_wave_without_an_intermission() -> void:
	var w: SimWorld = VarietyAKit.world(5)
	var answered: int = VarietyAKit.play(w, 0)
	assert_int(answered).is_equal(4)  # three routes and one boss briefing
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(5)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_int(w.result()).is_equal(RunResult.Id.VICTORY)


func test_the_long_run_visits_every_wave_and_every_choice() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var w: SimWorld = VarietyAKit.world(8, c)
	var routes: int = 0
	var briefs: int = 0
	var command_id: int = 1
	for _n: int in 40:
		if w.is_over() or not VarietyAKit.run_to_await(w):
			break
		routes += 1 if w.phase_state.awaiting == PhaseState.Await.ROUTE else 0
		briefs += 1 if w.phase_state.awaiting == PhaseState.Await.BOSS_BRIEF else 0
		VarietyAKit.answer(w, command_id, command_id % 2)
		command_id += 1
	assert_int(routes).is_equal(11)
	assert_int(briefs).is_equal(3)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(15)
	assert_int(w.stats.act_reached).is_equal(3)


func test_acts_start_with_the_wave_that_opens_them() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var w: SimWorld = VarietyAKit.world(6, c)
	var command_id: int = 1
	var seen: Array[int] = []
	for _n: int in 30:
		if w.is_over() or not VarietyAKit.run_to_await(w):
			break
		for e: SimEvent in VarietyAKit.events_of(w, SimEventKind.Id.ACT_STARTED):
			if not seen.has(e.a):
				seen.append(e.a)
				assert_int(w.wave).is_equal(5 * (e.a - 1) + 1)  # announced when its first wave starts, seen at the next await
		VarietyAKit.answer(w, command_id)
		command_id += 1
	assert_array(seen).is_equal([1, 2, 3])
	assert_int(w.phase_state.act).is_equal(3)


func test_the_act_changes_when_the_first_wave_of_the_act_starts_not_before() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var w: SimWorld = VarietyAKit.world(6, c)
	var command_id: int = 1
	for _n: int in 30:
		if not VarietyAKit.run_to_route(w):
			break
		if w.wave == 5:
			assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
			assert_int(w.phase_state.act).is_equal(1)  # the route of wave 6 is still shown in act I
			assert_int(_count(w, SimEventKind.Id.ACT_STARTED)).is_equal(1)
			VarietyAKit.answer(w, command_id)
			for _t: int in w.content.mission.breather_ticks:
				w.step()
			assert_int(w.wave).is_equal(6)
			assert_int(w.phase_state.act).is_equal(2)
			assert_int(_count(w, SimEventKind.Id.ACT_STARTED)).is_equal(2)
			return
		VarietyAKit.answer(w, command_id)
		command_id += 1
	fail("never reached wave 5")


func test_thinking_time_does_not_change_the_hash() -> void:
	var quick: SimWorld = VarietyAKit.world(11)
	var slow: SimWorld = VarietyAKit.world(11)
	assert_int(VarietyAKit.play(quick, 0)).is_equal(4)
	assert_int(VarietyAKit.play(slow, 600)).is_equal(4)
	assert_int(quick.tick).is_equal(slow.tick)
	assert_str(quick.state_hash()).is_equal(slow.state_hash())
	assert_int(quick.events.event_hash).is_equal(slow.events.event_hash)
	assert_bool(quick.is_over()).is_true()


func test_a_bot_that_answers_after_zero_or_six_hundred_calls_logs_the_same_commands() -> void:
	var quick: SimWorld = VarietyAKit.world(12)
	var slow: SimWorld = VarietyAKit.world(12)
	VarietyAKit.play(quick, 0, 1)
	VarietyAKit.play(slow, 600, 1)
	assert_int(quick.command_log.entries.size()).is_equal(slow.command_log.entries.size())
	for k: int in quick.command_log.entries.size():
		assert_int(quick.command_log.entries[k].tick).is_equal(slow.command_log.entries[k].tick)
		assert_int(quick.command_log.entries[k].arg).is_equal(slow.command_log.entries[k].arg)


func test_replaying_the_command_log_reproduces_a_run_that_waited_for_choices() -> void:
	var cfg: SimConfig = SimConfig.create(VarietyAKit.content(), 14)
	var w: SimWorld = SimWorld.new(cfg)
	VarietyAKit.play_natural(w, 3, 1)
	assert_int(w.command_log.entries.size()).is_greater_equal(1)
	var replayed: SimWorld = Replay.run(cfg, w.command_log, w.tick)
	assert_int(replayed.tick).is_equal(w.tick)
	assert_str(replayed.state_hash()).is_equal(w.state_hash())
	assert_int(replayed.events.event_hash).is_equal(w.events.event_hash)
	assert_int(replayed.plan.chosen[1]).is_equal(1)


func test_the_same_seed_and_choices_give_the_same_run_and_other_choices_another() -> void:
	var a: SimWorld = VarietyAKit.world(15)
	var b: SimWorld = VarietyAKit.world(15)
	var other: SimWorld = VarietyAKit.world(15)
	VarietyAKit.play(a, 0, 0)
	VarietyAKit.play(b, 0, 0)
	VarietyAKit.play(other, 0, 1)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_str(a.state_hash()).is_not_equal(other.state_hash())


func test_the_wave_count_comes_from_the_plan() -> void:
	assert_int(PhaseSystem.wave_count(VarietyAKit.world())).is_equal(5)
	assert_int(PhaseSystem.wave_count(VarietyAKit.world(1, VarietyAKit.long_content()))).is_equal(15)
	assert_int(PhaseSystem.wave_count(TestContent.world())).is_equal(5)


# --- the legacy 5-wave fixture ---


func test_the_legacy_fixture_has_no_plan_and_never_awaits() -> void:
	var w: SimWorld = TestContent.world(3)
	assert_object(w.plan).is_null()
	var seen_intermission: int = 0
	for _n: int in 6000:
		if w.is_over():
			break
		if GameState.is_combat(w.phase):
			w.phase_state.force_wave_spawned = true
			VarietyAKit.kill_all(w)
		w.step()
		assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
		seen_intermission += 1 if w.phase == GameState.Id.INTERMISSION else 0
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(5)
	assert_int(seen_intermission).is_greater(4 * 400)  # four countdowns of intermission_ticks
	assert_int(_count(w, SimEventKind.Id.ACT_STARTED)).is_equal(0)
	assert_int(_count(w, SimEventKind.Id.AWAIT_CHANGED)).is_equal(0)
	assert_int(_count(w, SimEventKind.Id.ROUTE_OFFERED)).is_equal(0)


func test_the_legacy_intermission_still_counts_down_and_can_be_skipped() -> void:
	var w: SimWorld = TestContent.world(3)
	for _n: int in 180:
		w.step()
	assert_int(w.wave).is_equal(1)
	w.phase_state.force_wave_spawned = true
	VarietyAKit.kill_all(w)
	for _n: int in 3:
		w.step()
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.phase_ticks_left).is_equal(w.content.mission.intermission_ticks - 1)
	w.phase_state.force_wave_spawned = false
	w.submit(SimCommand.skip(1))
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(2)
	w.submit(SimCommand.pick_route(2, 0))
	w.step()
	var pick: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	assert_int(pick[pick.size() - 1].b).is_equal(Reason.Id.NOT_AWAITING)


func test_a_legacy_run_is_reproducible_and_matches_a_bot_replay() -> void:
	var cfg: SimConfig = SimConfig.create(TestContent.baseline(), 9)
	var a: SimWorld = SimWorld.new(cfg)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	for _n: int in 4000:
		bot.act(a)
		a.step()
		a.events.drain()
	var replayed: SimWorld = Replay.run(cfg, a.command_log, 4000)
	assert_str(replayed.state_hash()).is_equal(a.state_hash())
	assert_int(replayed.events.event_hash).is_equal(a.events.event_hash)
